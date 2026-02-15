import Std.Internal.UV.TCP
import OEISLt.Server.Control

open Lean Std.Internal.UV.TCP Std Net

instance : ToString SocketAddress where
  toString
  | .v4 ⟨a, p⟩ => s!"{a}:{p}"
  | .v6 ⟨a, p⟩ => s!"{a}:{p}"

namespace Server

def MAX_BUFFER := 8192

#check Task

-- sender : ByteArray -> ServerM Unit
-- processor := ByteArray -> ServerM (Option Nat × ByteArray)
-- producer : processor -> ServerM (Option Nat × ByteArray)
--                ^-- we provide the processor

def F := ByteArray → ServerM ByteArray
abbrev DataStream := ByteArray → ServerM (Option Nat × ByteArray)
abbrev Processor := F → DataStream
def Producer := DataStream → ServerM (Option Nat × ByteArray)
def Sender := ByteArray → ServerM Unit

def processor : Processor :=
  fun f bs => do
    return ⟨some 0, bs⟩

-- Apply `f` to segments split by `\n`
def byLines (emit : ByteArray → ServerM Unit) (i : ByteArray) : ServerM ByteArray := do
  let mut data := i.toList
  while true do
    let (x, y) := data.span (· != 10)
    if y.isEmpty then
      return x.toByteArray
    emit x.toByteArray
    data := y.drop 1
  unreachable!

def p (bs : ByteArray) : ServerM Unit := do
  IO.println s!">>>{String.fromUTF8! bs}<<<"

def loop (proc : ByteArray → ServerM ByteArray) : ServerM Unit := do
  let mut data : ByteArray := default
  while true do
    data ← proc data

#synth Monad Task

def loopByLines
    (read : (ByteArray → ServerM ByteArray) → ServerM ByteArray)
    (emit : ByteArray → ServerM Unit)
    : ServerM Unit :=
  loop (fun prev =>
    read (fun t => byLines emit (prev ++ t))
  )

run_meta do
  let env ← getEnv
  let x : ByteArray := "foobar\nbaz\nspam".toUTF8
  let y ← runServerM₀ (byLines p x) ⟨env, {fileName := "", fileMap := default}, {env}, default, default, default⟩
  dbg_trace String.fromUTF8! y
  -- let readArg : ByteArray → ServerM ByteArray := fun bs => do
  --   IO.println s!"readArg function"
  --   return bs
  let read : (ByteArray → ServerM ByteArray) → ServerM ByteArray := fun rArg => do
    let new := "foo\ngoo\neggs\nscoop".toUTF8
    IO.println s!"read function, producing {String.fromUTF8! new}"
    rArg new
  let emit : ByteArray → ServerM Unit := fun bs => do
    IO.println s!"Emiting {String.fromUTF8! bs}"
    throw <| ServerError.FromOEISM "out"
  let u := read (fun t => byLines emit ("baz".toUTF8 ++ t))
  --let z ← runServerM₀ u ⟨env, {fileName := "", fileMap := default}, {env}, default, default⟩
  --dbg_trace "returned `{String.fromUTF8! z}`"
  --let l ← runServerM₀ (loopByLines read emit) ⟨env, {fileName := "", fileMap := default}, {env}, default, default⟩

def f (socket : Socket) (f : String → ServerM String) : ServerM UInt32 := do
  loopByLines (fun ret => do
      let reader_task := (← socket.recv? MAX_BUFFER).result!
      reader_task.map (fun t => ret (default : ByteArray)) |>.get -- TODO: do error handing insisde of the ret
    )
     sorry -- TODO: emitter will apply `f`
  return 0
def readAndProcess (socket : Socket) (f : String → ServerM String) : ServerM UInt32 := do
  let mut data : ByteArray := default
  while true do
    -- TODO: change result! to result?
    let reader_task := (← socket.recv? MAX_BUFFER).result!
    let (e, remaining) ← reader_task.map (fun t => do
      match t with
      | .ok none =>
        IO.println s!"client disconnected: {← socket.getPeerName}"
        return (some 0, default)
      | .ok (some u) =>
        if let some i := u.findFinIdx? (· == 10) then
          -- TODO: see if there is a split string method
          -- TODO: also, we need to check if there are more than one message in u
          --       Iterate over an split by (· == 10)
          let data_received := data.append <| u.extract 0 (i + 1)
          let remaining := u.extract (i + 1) u.size
          match String.fromUTF8? data_received with
          | some text =>
            IO.println s!"got data: {text.trimRight}"
            let output ← f text
            -- TODO: change result! to result?
            match (← socket.send <| String.toUTF8 output).result!.get with
            | .ok _ => return (none, remaining)
            | .error e =>
              IO.println s!"got error while writing: {e}"
              return (some 1, default)
          | none =>
            IO.println "got data but not utf8"
            return (some 1, default)
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
