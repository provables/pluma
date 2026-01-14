import Cli.Basic
import OEISLt.Version
import OEISLt.Cli.Error
import OEISLt.Server.Basic

open Cli

unsafe def run (_ : Parsed) : IO UInt32 := runConfigM Server.run

unsafe
def cmd : Cmd := `[Cli|
  "oeis-lt" VIA run; [VERSION]
  "A pluggable server for OEIS tooling.
  "
]

unsafe
def main (args : List String) : IO UInt32 := do
  cmd.validate args
