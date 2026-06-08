import Cli.Basic
import Pluma.Version
import Pluma.Cli.Error
import Pluma.Server.Basic

open Cli

unsafe def run (_ : Parsed) : IO UInt32 := runConfigM Server.run

unsafe
def cmd : Cmd := `[Cli|
  "pluma" VIA run; [VERSION]
  "A (P)luggable (l)ightweight (u)tility (ma)nager.
  "
]

unsafe
def main (args : List String) : IO UInt32 := do
  cmd.validate args
