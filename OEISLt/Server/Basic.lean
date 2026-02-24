import Std.Internal.UV.TCP
import OEISLt.Version
import OEISLt.Cli.Config
import OEISLtProto
import OEISLt.Server.Control
import OEISLt.Server.Socket
-- this is here just for testing. Remove when the server loads from config
import OEISLt.Plugins.Dummy

open Lean Std Net Std.Internal.UV.TCP

namespace Server

unsafe
def runPluginJson (command : String) (inp : Json) : ClientM Json := do
  let data := (← read).server.config.plugins
  dbg_trace "starting runPlugin"
  let some cmd := (← read).server.commands.get? command | throw <| .MissingPlugin command
  dbg_trace "got command {cmd}"
  let some pluginData := data.get? cmd | throw <| .MissingPlugin command
  dbg_trace "got plugin {pluginData.name}"
  match (← read).server.env.evalConst Plugin default pluginData.name with
  | .ok v =>
    v.function inp
  | .error e =>
    throw <| ServerError.ImportError e

def onSuccess (obj : Json) : Json :=
  Json.mkObj [
    ("status", true),
    ("result", obj)
  ]

def onError (err : ServerError) : Json :=
  Json.mkObj [
    ("status", false),
    ("error", Json.str s!"{repr err}")
  ]

unsafe
def runPluginOnString (inp : ByteArray) : ClientM Json := do
  let some s := String.fromUTF8? inp | throw ServerError.UTF8Error
  let .ok obj := Json.parse s | throw <| .JsonDecodeError s
  let command ← obj.getObjValAs? String "cmd" |>.mapError
    (ServerError.MessageError s!"missing or invalid 'cmd' key: {·}")
  let args ← obj.getObjValAs? Json "args" |>.mapError
    (ServerError.MessageError s!"missing or invalid 'args' key': {·}")
  runPluginJson command args

unsafe
def runMessage (inp : ByteArray) : BaseClientM ByteArray := do
  let outMsg := ToString.toString <| match (← ClientM.toBase <| runPluginOnString inp) with
  | .ok r => onSuccess r
  | .error e => onError e
  return String.toUTF8 s!"{outMsg}\n"

unsafe
def server : ServerM UInt32 := do
  -- here we can run OEISM
  -- get json from socket
  -- run plugin
  -- send json to socket
  let serverCtx ← read
  let config := serverCtx.config
  let socket ← Internal.UV.TCP.Socket.new
  let addr := IPv4Addr.ofString "0.0.0.0" |>.getD default
  let endpoint := SocketAddress.v4 {addr := addr, port := config.port}
  socket.bind endpoint
  socket.listen 1
  IO.println s!"[OEIS-Lt v{serverCtx.version}] Ready on port {config.port}"
  IO.println s!"Database: {serverCtx.config.dbPath}"
  let commands := serverCtx.commands
  IO.println s!"Plugins loaded: {commands.keys}"
  while true do
    let conn ← socket.accept
    let result := conn.result!
    let _ ← Task.get <| result.map (fun t => do
      match t with
      | .ok s =>
        let client ← s.getPeerName
        IO.println s!"client connected: {client}"
        let _u ← IO.asTask <| ← toIO <| ClientM.toServerM <| readAndProcess s runMessage
      | .error e =>
        IO.println s!"client connection error: {e}"
    )
  return 0

unsafe
def mkCommandTable (env : Environment) : ConfigM (Std.HashMap String Name) := do
  let u ← (← read).plugins.keys.mapM (fun k => do
    let v ← env.evalConst Plugin default k |>.map (·.cmd) |>.mapError (IO.Error.userError ·)
    return (v, k)
  )
  return Std.HashMap.ofList u

unsafe
def exec {α : Type} (act : ServerM α) : ConfigM α := do
  let cfg ← read
  let modules := cfg.plugins.values.toArray.map (·.mod)
  dbg_trace "Loading modules: {modules}"
  enableInitializersExecution
  initSearchPath (← findSysroot)
  let env ← importModules (modules.map ({module := ·})) {} (trustLevel := 1024) (loadExts := true)
  let ctx : Core.Context := {fileName := "", fileMap := default}
  let state : Core.State := {env}
  let commands ← mkCommandTable env
  runServerM act env ctx state cfg commands VERSION

unsafe
def playground {α : Type} (act : ClientM α) (config : System.FilePath := "./oeis-lt.toml")
    : IO α := do
  let cfg ← EIO.toIO (fun e => s!"{e}") <| loadConfig config
  ReaderT.run (exec <| ClientM.toServerM act) cfg

unsafe
def run : ConfigM UInt32 := exec server

-- #eval do
--   IO.println "foo"
--   playground do
--     IO.println "bar"
--     let x ← Dummy.plugin.function 2
--     IO.println s!"x is {x}"

end Server
