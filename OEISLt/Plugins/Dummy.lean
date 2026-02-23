import OEISLtProto
import SQLite

#check SQLite.AccessMode
namespace Dummy
def plugin : Plugin := mkPlugin "dummy" (fun (n : Nat) => pure n)

def f (s : String) : OEISM String := do
  return s!"---> {s}"

def plugin2 : Plugin := mkPlugin "sql" f

end Dummy

--#print Dummy.plugin
