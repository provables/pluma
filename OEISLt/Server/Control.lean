import Lean
import Std.Internal.UV.TCP
import OEISLt.Cli.Config
import OEISLtProto

open Lean Std

namespace Server

instance : Repr Json where
  reprPrec j _ := Json.render j

inductive ServerError where
  | FromOEISM (error : String)
  | MissingPlugin (name : String)
  | JsonDecodeError (val : Json)
  | ClientError (val : Json)
  | MessageError (error : String)
  | ImportError (error : String)
  | SocketError (error : String)
  deriving Repr

structure ServerContext where
  env : Environment
  ctx : Core.Context
  state : Core.State
  config : Config
  commands : Std.HashMap String Name
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
    (state : Core.State) (config : Config) (commands : Std.HashMap String Name) (version : String)
    : IO α :=
  runServerM₀ act ⟨env, ctx, state, config, commands, version⟩

def toIO {α : Type} (act : ServerM α) : ServerM (IO α) := Functor.map pure act

end Server
