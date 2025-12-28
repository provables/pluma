import OEISLtProto

namespace Dummy
def plugin : Plugin := mkPlugin "dummy" (fun (n : Nat) => pure n)

end Dummy

--#print Dummy.plugin
