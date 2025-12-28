import OEISLt.Cli.Config
import OEISLtProto
import OEISLt.Plugins.Dummy

namespace Server

open Lean Std

def C : Std.HashMap String (Σ α : Type, Σ _ : Lean.FromJson α, α → Nat) := default

-- abbrev OEISM := IO
-- abbrev Plugin := (Σ input : Type, Σ _ : FromJson input, Σ output : Type, Σ _ : ToJson output, input → OEISM output)
-- def Plugins : Std.HashMap String Plugin := default

def foo1 : String → Nat := fun _ => 0
def foo2 : Nat → Nat := fun n => n
def foo3 : Config → Nat := fun c => c.port

-- run_meta do
--   let u := C.insert "bar" ⟨_, inferInstance, foo1⟩
--   let v := u.insert "baz" ⟨_, inferInstance, foo2⟩
--   --let z := v.insert "spa" ⟨Config, inferInstance, foo3⟩
--   let ⟨t, h, w⟩  := v.getD "bar" ⟨_, inferInstance, fun (_ : Nat) => 1⟩
--   let y : Except String t := Lean.FromJson.fromJson? "3"
--   dbg_trace "foo"

def runOEISM {α : Type} (a : OEISM α) (env : Environment) (ctx : Core.Context) (state: Core.State) : IO α :=
  ReaderT.run a ⟨env, ctx, state⟩

def runM : MetaM Unit :=
  let x := Dummy.plugin.cmd
  dbg_trace "cmd = {x}"
  let ⟨inp, _, out, _, f ⟩ := Dummy.plugin.function
  let u : Except String inp := FromJson.fromJson? 3
  match u with
  | .ok v => do
    let w := f v
    let env ← getEnv
    let ctx : Core.Context := {fileName := "", fileMap := default}
    let state : Core.State := {env}
    let z ← runOEISM w env ctx state
    let z2 : Json := ToJson.toJson z
    dbg_trace "output = {z2}"
  | .error s => dbg_trace "bad: {s}"
  return ()

run_meta
  runM

#check Dummy.plugin
#check evalConst
#check Plugin

unsafe def run : ConfigM UInt32 := do
  -- Here load modules from `plugins`
  -- and ServerM.run the main function
  let cfg ← read
  let modules := cfg.plugins
  dbg_trace "modules: {modules}"
  enableInitializersExecution
  initSearchPath (← findSysroot)
  let env ← importModules (modules.map ({module := ·})) {} (trustLevel := 1024) (loadExts := true)
  let myModule := "OEISLt.Plugins.Dummy"
  let myFun := s!"Dummy.plugin"
  let myFunName := String.toName myFun
  --let u ← runOEISM (d)
  let z := env.evalConst Plugin default myFunName
  match z with
  | .ok v =>
    dbg_trace v.cmd
    let f := v.function
  | .error e => dbg_trace "error: {e}"
  return 0

run_cmd do
  let e ← runConfigM run
  dbg_trace "e: {e}"
  dbg_trace "foo"

end Server
