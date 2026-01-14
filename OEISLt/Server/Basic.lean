import Std.Internal.UV.TCP
import OEISLt.Version
import OEISLt.Cli.Config
import OEISLtProto
-- this is here just for testing. Remove when the server loads from config
import OEISLt.Plugins.Dummy

open Lean Std Net Std.Internal.UV.TCP

instance : ToString SocketAddress where
  toString
  | .v4 ⟨a, p⟩ => s!"{a}:{p}"
  | .v6 ⟨a, p⟩ => s!"{a}:{p}"

namespace Server

instance : Repr Json where
  reprPrec j _ := Json.render j

inductive ServerError where
  | FromOEISM (error : String)
  | MissingPlugin (name : Name)
  | JsonDecodeError (val : Json)
  | ImportError (error : String)
  | SocketError (error : String)
  deriving Repr

structure ServerContext where
  env : Environment
  ctx : Core.Context
  state : Core.State
  config : Config
  version : String

abbrev ServerM := ReaderT ServerContext (EIO ServerError)

def runOEISM {α : Type} (a : OEISM α) (env : Environment) (ctx : Core.Context) (state : Core.State) : IO α :=
  ReaderT.run a ⟨env, ctx, state⟩

instance : MonadLift OEISM ServerM where
  monadLift o := do
    let x ← read
    IO.toEIO (fun e => ServerError.FromOEISM s!"{e}") <| runOEISM o x.env x.ctx x.state

def runServerM₀ {α : Type} (act : ServerM α) (ctx : ServerContext) : IO α :=
  EIO.toIO (fun e => s!"Server error: {repr e}") <| ReaderT.run act ctx

def runServerM {α : Type} (act : ServerM α) (env : Environment) (ctx : Core.Context)
    (state : Core.State) (config : Config) (version : String) : IO α :=
  runServerM₀ act ⟨env, ctx, state, config, version⟩

def toIO {α : Type} (act : ServerM α) : ServerM (IO α) := Functor.map pure act

unsafe
def runPlugin (name : Name) (inp : Json) : ServerM Json := do
  let data := (← read).config.plugins
  let some pluginData := data.get? name | throw <| .MissingPlugin name
  let plugin := s!"{pluginData.name}.plugin".toName
  match (← read).env.evalConst Plugin default plugin with
  | .ok v =>
    let ⟨_, _, _, _, f⟩ := v.function
    let .ok u := FromJson.fromJson? inp | throw <| .JsonDecodeError inp
    return ToJson.toJson (← f u)
  | .error e =>
    throw <| ServerError.ImportError e

def processClient (socket : Socket) : ServerM UInt32 := do
  IO.println s!"processing client with socket {← socket.getPeerName}"
  return 0

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
  while true do
    let conn ← socket.accept
    let result := conn.result!
    let _ ← Task.get <| result.map (fun t => do
      match t with
      | .ok s =>
        let client ← s.getPeerName
        IO.println s!"client connected: {client}"
        let _u ← IO.asTask <| ← toIO <| processClient s
      | .error e =>
        IO.println s!"client connection error: {e}"
    )
  return default

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
  let out ← runServerM server env ctx state cfg VERSION
  return out

end Server
