import Cli.Basic
import Lake.Toml
import OEISLt.Cli.Error
--import Lake.Toml.Load

open Cli Lake.Toml Lean.Parser

def VERSION := "0.1.0"
def CONFIG_FILE := "oeis-lt.toml"

def loadConfig : EIO OEISLtError Table := do
  let some fileName ← IO.getEnv CONFIG_FILE | throw (.MissingEnvVar CONFIG_FILE)
  let input ← IO.toEIO .IOError (IO.FS.readFile fileName)
  let ictx := mkInputContext input fileName
  -- match (← loadToml ictx |>.toBaseIO) with
  -- | .ok table =>
  sorry

def run (_p : Parsed) : IO UInt32 := do
  IO.println "Running"
  return 0

unsafe
def cmd : Cmd := `[Cli|
  "genseq" VIA run; [VERSION]
  "Generate a Lean definition from the synthetic DSL.

  Requests: {\"cmd\": String, \"args\": { ... }}
  Responses:
    - {\"status\": true, \"result\": { ... }}
    - {\"status\": false, \"error\": String}
  "

  FLAGS:
    p, port : Nat;        "Listen at port <port> (default: 8000)"
    s, supervise;         "Start genseq under supervisord"
    w, wait;              "Wait for the server to be ready before going to the background"
    n, foreground;        "Keep the process in the foreground"
    k, kill;              "Stop a supervised genseq"
]

unsafe
def main (args : List String) : IO UInt32 := do
  cmd.validate args
