import Std.Internal.UV.TCP
import OEISLt.Server.Control

open Lean Std.Internal.UV.TCP Std Net

instance : ToString SocketAddress where
  toString
  | .v4 ⟨a, p⟩ => s!"{a}:{p}"
  | .v6 ⟨a, p⟩ => s!"{a}:{p}"

namespace Server

def MAX_BUFFER := 8192

def readAndProcess (socket : Socket) (f : ByteArray → BaseServerM ByteArray)
    : ServerM UInt32 := do
  let mut data : ByteArray := default
  while true do
    let (e, remaining) ← (← socket.recv? MAX_BUFFER).result?.map (fun t => do
      match t with
      | some (.ok none) =>
        IO.println s!"client disconnected: {← socket.getPeerName}"
        return (some 0, default)
      | some (.ok (some u)) =>
        if let some i := u.findIdx? (· == 10) then
          let data_received := data.append <| u.extract 0 (i + 1)
          let remaining := u.extract (i + 1) u.size
          let output ← f data_received
          match (← socket.send output).result?.get with
          | some (.ok _) => return (none, remaining)
          | some (.error e) =>
            IO.println s!"got error while writing: {e}"
            return (some 1, default)
          | none =>
            IO.println s!"internal error: promise dropped while writing"
            return (some 1, default)
        else
          -- more data to read, keep looping
          return (none, data.append u)
      | some (.error v) =>
        IO.println s!"got error while reading: {v}"
        return (some 1, default)
      | none =>
        IO.println s!"internal error: promise dropped while reading"
        return (some 1, default)
    ) |>.get
    data := remaining
    if let some x := e then
      return x
  return 0

end Server
