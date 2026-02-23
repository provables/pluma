import Lean
import Std.Internal.UV.TCP
import SQLite
import OEISLt.Cli.Config
import OEISLtProto

open Lean Std

namespace Server

instance : Repr Json where
  reprPrec j _ := Json.render j

inductive ServerError where
  | FromOEISM (error : OEISError)
  | FromIOError (error : String)
  | MissingPlugin (name : String)
  | JsonDecodeError (val : Json)
  | ClientError (val : Json)
  | MessageError (error : String)
  | ImportError (error : String)
  | SocketError (error : String)
  | UTF8Error
  deriving Repr

structure ServerContext where
  env : Environment
  ctx : Core.Context
  state : Core.State
  config : Config
  commands : Std.HashMap String Name
  version : String

structure ClientContext where
  server : ServerContext
  db : SQLite

abbrev BaseServerM := ReaderT ServerContext BaseIO
abbrev BaseClientM := ReaderT ClientContext BaseIO
abbrev ServerM := ReaderT ServerContext (EIO ServerError)
abbrev ClientM := ReaderT ClientContext (EIO ServerError)

def ClientM.toBase {α : Type} (act : ClientM α) : BaseClientM (Except ServerError α) := do
  EIO.toBaseIO <| ReaderT.run act (← read)

-- def ClientM.toBase {α : Type} (act : ClientM α) : BaseServerM (Except ServerError α) := do
--   EIO.toBaseIO <| ReaderT.run act (← read)

def runOEISM {α : Type} (a : OEISM α) (env : Environment) (ctx : Core.Context) (state : Core.State)
    : EIO OEISError α :=
  ReaderT.run a ⟨env, ctx, state⟩

instance : MonadLift OEISM ServerM where
  monadLift o := do
    let x ← read
    runOEISM o x.env x.ctx x.state |>.adapt (fun e => ServerError.FromOEISM e)

instance : MonadLift OEISM ClientM where
  monadLift o := do
    let x ← read
    runOEISM o x.server.env x.server.ctx x.server.state |>.adapt (fun e => ServerError.FromOEISM e)

instance : MonadLift IO ServerM where
  monadLift o := IO.toEIO (fun e => ServerError.FromIOError s!"{e}") o

instance : MonadLift IO ClientM where
  monadLift o := IO.toEIO (fun e => ServerError.FromIOError s!"{e}") o

-- instance : MonadLift BaseServerM ServerM where
--   monadLift o := o

-- instance : MonadLift BaseServerM ClientM where
--   monadLift o := o.adapt fun x => x.server

def runServerM₀ {α : Type} (act : ServerM α) (ctx : ServerContext) : IO α :=
  EIO.toIO (fun e => s!"Server error: {repr e}") <| ReaderT.run act ctx

def runServerM {α : Type} (act : ServerM α) (env : Environment) (ctx : Core.Context)
    (state : Core.State) (config : Config) (commands : Std.HashMap String Name)
    (version : String)
    : IO α :=
  runServerM₀ act ⟨env, ctx, state, config, commands, version⟩

def toIO {α : Type} (act : ServerM α) : ServerM (IO α) := Functor.map pure act

def ClientM.toServerM {α : Type} (act : ClientM α) : ServerM α := do
  let server ← read
  let db ← SQLite.openWith server.config.dbPath { mode := .readWrite }
  act.adapt ({ server := ·, db := db})

end Server
