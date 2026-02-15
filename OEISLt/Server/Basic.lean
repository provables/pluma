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
def runPlugin (name : Name) (inp : Json) : ServerM Json := do
  let data := (← read).config.plugins
  let some pluginData := data.get? name | throw <| .MissingPlugin name
  match (← read).env.evalConst Plugin default pluginData.name with
  | .ok v =>
    let ⟨_, _, _, _, f⟩ := v.function
    let .ok u := FromJson.fromJson? inp | throw <| .JsonDecodeError inp
    return ToJson.toJson (← f u)
  | .error e =>
    throw <| ServerError.ImportError e

unsafe
def runMessage (inp : String) : ServerM String := do
  let .ok obj := Json.parse inp | throw <| .JsonDecodeError inp
  let x := obj.getObjValAs? String "cmd"
  match x with
  | .ok command =>
    let y := obj.getObjValAs? Json "args"
    match y with
    | .ok argsJson =>
      let outJson ← runPlugin command.toName argsJson
      return ToString.toString outJson
    | .error _ =>
      throw <| .ClientError obj
  | .error _ => throw <| .ClientError obj

unsafe
def processClient (socket : Socket) : ServerM UInt32 := do
  IO.println s!"processing client with socket {← socket.getPeerName}"
  let s ← read
  let t := s.config.plugins.keys
  dbg_trace "plugins available: {t}"
  let x : Json := 3
  let y ← runPlugin `Dummy.plugin x
  IO.println s!"output of dummy: {y}"
  return 0

unsafe
def server : ServerM Unit := do
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

  while true do
    let conn ← socket.accept
    let result := conn.result!
    let _ ← Task.get <| result.map (fun t => do
      match t with
      | .ok s =>
        let client ← s.getPeerName
        IO.println s!"client connected: {client}"
        let _u ← IO.asTask <| ← toIO <| readAndProcess socket runMessage
      | .error e =>
        IO.println s!"client connection error: {e}"
    )

unsafe
def run : ConfigM Unit := do
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
  runServerM server env ctx state cfg VERSION

end Server
