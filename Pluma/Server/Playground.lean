import Pluma.Server.Basic
import Pluma.Server.Control
import Pluma.Plugins.Compile

/-
Interactive module for testing plugins.
Do not import this module in places that are compiled, so it doesn't taint the
executables.
-/

open Lean Server

unsafe
def playground {α : Type} (act : ClientM α) (config : System.FilePath := "./pluma.toml")
    : MetaM α := do
  let cfg ← EIO.toIO (fun e => s!"{e}") <| loadConfig config
  let env ← getEnv
  ReaderT.run (exec env <| ClientM.toServerM act) cfg

#eval do
  playground do
    let x ← Dummy.plugin 5
    IO.println s!"x is {x}"
    let y ← Compile.compile (⟨"def fdfsjk : Nat := 5"⟩ : Compile.Code)
    dbg_trace y
