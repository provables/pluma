import Pluma.Server.Basic
import Pluma.Server.Control
import Pluma.Plugins.Eval

/-
Interactive module for testing plugins.
Do not import this module in places that are compiled, so it doesn't taint the
executables.
-/

open Server

unsafe
def playground {α : Type} (act : ClientM α) (config : System.FilePath := "./pluma.toml")
    : IO α := do
  let cfg ← EIO.toIO (fun e => s!"{e}") <| loadConfig config
  ReaderT.run (exec <| ClientM.toServerM act) cfg

#eval do
  playground do
    let x ← Dummy.plugin.function 2
    IO.println s!"x is {x}"
    let z : Eval.Code := ⟨ "foo" ⟩
    let y ← Eval.eval z
    dbg_trace y

--instance CoeFun
