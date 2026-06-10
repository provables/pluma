import PlumaProto

open Lean

namespace Eval

@[plumaData]
structure Code where
  src : String

structure Response where
  compiled : Bool
  deriving ToJson

def doEval (req : Code) : PlumaM Response := do
  IO.println s!"requested: {req.src}"
  return ⟨true⟩

def eval : Plugin := mkPlugin "eval" doEval

end Eval
