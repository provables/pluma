{ lib
, stdenv
, system
, rsync
, findutils
, makeWrapper
, buildLean
, leanVersion
, ...
}:
let
  deps =
    let
      hashes = {
        "aarch64-darwin" = "";
        "aarch64-linux" = "";
        "x86_64-darwin" = "";
        "x86_64-linux" = "";
      };
    in
    buildLean.deps {
      inherit leanVersion;
      name = "plumaDeps";
      src = with lib; with builtins; cleanSourceWith {
        src = cleanSource ./..;
        filter = p: t: (baseNameOf p != ".lake");
      };
      outputHash = hashes.${system};
      buildPhase = ''
        lake exe cache get
        lake build Pluma
        lake build pluma
      '';
    };
in
{
  pluma = buildLean.package {
    inherit leanVersion;
    name = "pluma";
    inherit deps;
    src = lib.cleanSource ./..;
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ rsync findutils ];
    phases = [ "unpackPhase" "buildPhase" "distPhase" ];
    buildPhase = ''
      mkdir -p $out/{bin,lib}
      lake build pluma
      rsync -a .lake/build/lib/ $out/lib/
      rsync -a .lake/packages $out/lib/
      rsync -a .lake/build/bin/ $out/bin/
      LEAN_PATH=$(
        echo -n "$out/lib/lean"
        find $out/lib/packages -mindepth 1 -maxdepth 1 -type d \
          -exec echo -n ":{}/.lake/build/lib/lean" ';'
      )
      wrapProgram $out/bin/pluma \
        --set LEAN_PATH "$LEAN_PATH" \
        --set PATH "$PATH" 
    '';
  };
}
