inductive PlumaServerError where
  | MissingEnvVar (var : String)
  | IOError (err : IO.Error)
  | TomlError (err : String)
  | ConfigError (err : String)

def toString : PlumaServerError → String
  | .MissingEnvVar var => s!"Missing environment variable `{var}`"
  | .IOError err => s!"IO Error: {err}"
  | .TomlError err => s!"Error loading Toml file: {err}"
  | .ConfigError err => s!"Configuration error: {err}"

instance : ToString PlumaServerError := ⟨ toString ⟩
instance : Repr PlumaServerError := ⟨ fun x => reprPrec (_root_.toString x) ⟩
