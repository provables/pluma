import Std.Internal.UV.TCP
import OEISLt.Server.Control

open Lean Std.Internal.UV.TCP Std Net

instance : ToString SocketAddress where
  toString
  | .v4 ⟨a, p⟩ => s!"{a}:{p}"
  | .v6 ⟨a, p⟩ => s!"{a}:{p}"

namespace Server

def MAX_BUFFER := 8192

def readAndProcess (socket : Socket) (f : String → BaseServerM String)
    : ServerM UInt32 := do
  let mut data : ByteArray := default
  while true do
    -- TODO: change result! to result?
    let r := (← socket.recv? MAX_BUFFER).result?.map (fun t => t)
    let reader_task := (← socket.recv? MAX_BUFFER).result!
    let (e, remaining) ← reader_task.map (fun t => do
      match t with
      | .ok none =>
        IO.println s!"client disconnected: {← socket.getPeerName}"
        return (some 0, default)
      | .ok (some u) =>
        if let some i := u.findIdx? (· == 10) then
          let data_received := data.append <| u.extract 0 (i + 1)
          let remaining := u.extract (i + 1) u.size
          match String.fromUTF8? data_received with
          | some text =>
            IO.println s!"got data: {text.trimRight}"
              let output ← f text
              -- TODO: return JSON ok
              match (← socket.send <| String.toUTF8 output).result?.get with
              | some (.ok _) => return (none, remaining)
              | some (.error e) =>
                IO.println s!"got error while writing: {e}"
                return (some 1, default)
              | none =>
                IO.println s!""
                return (some 1, default)
          | none =>
            IO.println "got data but not utf8"
            -- TODO return error to client
            return (none, remaining)
        else
          -- more data to read, keep looping
          return (none, data.append u)
      | .error v =>
        IO.println s!"got error while reading: {v}"
        return (some 1, default)
    ) |>.get
    data := remaining
    if let some x := e then
      return x
  return 0

end Server
