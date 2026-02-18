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
def runPluginJson (command : String) (inp : Json) : ServerM Json := do
  let data := (← read).config.plugins
  dbg_trace "starting runPlugin"
  let some cmd := (← read).commands.get? command | throw <| .MissingPlugin command
  dbg_trace "got command {cmd}"
  let some pluginData := data.get? cmd | throw <| .MissingPlugin command
  dbg_trace "got plugin {pluginData.name}"
  match (← read).env.evalConst Plugin default pluginData.name with
  | .ok v =>
    let ⟨_, _, _, _, f⟩ := v.function
    let .ok u := FromJson.fromJson? inp | throw <| .JsonDecodeError inp
    return ToJson.toJson (← f u)
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
def runPluginOnString (inp : String) : ServerM Json := do
  let .ok obj := Json.parse inp | throw <| .JsonDecodeError inp
  let command ← obj.getObjValAs? String "cmd" |>.mapError (ServerError.MessageError ·)
  let args ← obj.getObjValAs? Json "args" |>.mapError (ServerError.MessageError ·)
  runPluginJson command args

unsafe
def runMessage (inp : String) : BaseServerM String :=
  return ToString.toString <| match (← toBase <| runPluginOnString inp) with
  | .ok r => onSuccess r
  | .error e => onError e

unsafe
def processClient (socket : Socket) : ServerM UInt32 := do
  IO.println s!"processing client with socket {← socket.getPeerName}"
  let s ← read
  let t := s.config.plugins.keys
  dbg_trace "plugins available: {t}"
  let x : Json := 3
  let y ← runPluginJson "dummy" x
  IO.println s!"output of dummy: {y}"
  return 0

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
        let _u ← IO.asTask <| ← toIO <| readAndProcess s runMessage
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
def run : ConfigM UInt32 := do
  -- Here load modules from `plugins`
  -- and ServerM.run the main function
  let cfg ← read
  let modules := cfg.plugins.values.toArray.map (·.mod)
  dbg_trace "Loading modules: {modules}"
  enableInitializersExecution
  initSearchPath (← findSysroot)
  let env ← importModules (modules.map ({module := ·})) {} (trustLevel := 1024) (loadExts := true)
  let ctx : Core.Context := {fileName := "", fileMap := default}
  let state : Core.State := {env}
  let commands ← mkCommandTable env
  runServerM server env ctx state cfg commands VERSION

end Server
