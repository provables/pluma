import Lake.Toml
import Lake.Load.Toml
import OEISLt.Cli.Error

open Lean Lake.Toml Lean.Parser

structure PluginData where
  mod : Name
  name : Name
  deriving Repr, Inhabited

structure Config where
  port : Nat
  supervised : Bool
  wait : Bool
  foreground : Bool
  plugins : Std.HashMap Name PluginData
  deriving Repr

instance : Inhabited Config := ⟨ 7000, false, false, false, default ⟩

abbrev ConfigM := ReaderT Config IO

def loadConfigToml (config : System.FilePath) : EIO OEISLtError Table := do
  let input ← IO.toEIO .IOError (IO.FS.readFile config)
  let ictx := mkInputContext input config.toString
  match (← loadToml ictx |>.toBaseIO) with
    | .ok table => return table
    | .error log =>
      throw <| .TomlError <| "\n".intercalate <| ← log.toList.mapM (fun msg => msg.toString)

def decodePlugin (t : Table) : Except String PluginData := do
  let .ok (r : Except String (Name × Name)) e :=  EStateM.run (s := #[]) (do
    let some (mod : Name) := (← t.tryDecode? `module) | return .error "error in field `module`"
    let some (name : Name) := (← t.tryDecode? `name) | return .error "error in field `name`"
    return .ok (mod, name)
  )
  if e.isEmpty then
    match r with
    | .ok (mod, name) => return ⟨mod, name⟩
    | .error s => throw s
  else
    throw <| String.intercalate "\n" <| e.map (fun y => y.msg) |>.toList

def mkConfigFromTable (t : Table) : Except String Config :=
  t.foldM (fun d k v =>
    match k with
      | `port =>
        match v with
        | .integer _ n =>
          if n ≥ 0 then
            return {d with port := n.toNat}
          else
            throw s!"`port` cannot be negative, got {n}"
        | _ => throw s!"`port` has to be a natural number, got {v}"
      | `supervised =>
        match v with
        | .boolean _ b => return {d with supervised := b}
        | _ => throw s!"`supervised` has to be a boolean, got {v}"
      | `wait =>
        match v with
        | .boolean _ b => return {d with wait := b}
        | _ => throw s!"`wait` has to be a boolean, got {v}"
      | `foreground =>
        match v with
        | .boolean _ b => return {d with foreground := b}
        | _ => throw s!"`foreground` has to be a boolean, got {v}"
      | `plugins =>
        match v with
        | .array _ as => do
          let y ← as.foldlM (fun prev v => do
            match v with
            | .table _ w => do
              let ps ← decodePlugin w
              let name := ps.name
              let (contained, new) := prev.containsThenInsertIfNew name ps
              if contained then
                throw s!"plugin `{name}` already registered"
              else
                return new
            | _ => throw "plugin should be a table"
          ) d.plugins
          return {d with plugins := y}
        | _ => throw s!"`plugins` needs to be an array of tables, got {v}"
      | s => throw s!"Unrecognized option `{s}`"
    ) default

def loadConfig (config : System.FilePath) : EIO OEISLtError Config := do
  let table ← loadConfigToml config
  let cfg := mkConfigFromTable table
  match cfg with
  | .ok c => return c
  | .error e => throw <| .ConfigError e

def loadConfigFromEnv (var : String) (default_file : System.FilePath := "./oeis-lt.toml") :
    EIO OEISLtError Config := do
  let file := ((← IO.getEnv var) |>.map System.FilePath.mk) |>.getD default_file
  loadConfig file

def runConfigM {α : Type} (act : ConfigM α) : IO α := do
  let cfg ← EIO.toIO (fun e => IO.Error.userError s!"{e}") <| loadConfigFromEnv "OEISLT_CONFIG_FILE"
  ReaderT.run act cfg

run_meta do
  -- let t ← EIO.toIO (fun e => IO.Error.userError s!"{e}") <| loadConfigToml "./oeis-lt.toml"
  -- let x := decodePlugin t
  -- dbg_trace (repr x)
  let x := loadConfig "./oeis-lt.toml"
  let y ← EIO.toIO (fun e => IO.Error.userError s!"Error: {e}") x
  dbg_trace "Config: {repr y}"
