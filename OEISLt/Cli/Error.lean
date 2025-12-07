inductive OEISLtError where
  | MissingEnvVar (var : String)
  | IOError (err : IO.Error)
