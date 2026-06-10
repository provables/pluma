import PlumaProto
import SQLite

namespace Dummy
def plugin : Plugin := mkPlugin "dummy" (fun (n : Nat) => pure n)

def f (s : String) : PlumaM String := do
  return s!"---> {s}"

def plugin2 : Plugin := mkPlugin "sql" f

end Dummy

--#print Dummy.plugin
