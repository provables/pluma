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
        "aarch64-darwin" = "sha256-YWIj0dUYrfqoUbwakCPAv5Vcjsu/JU+CHPL5zhAZAGw=";
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
        lake build OEISLt
        lake build oeis-lt
      '';
    };
in
{
  oeisLt = buildLean.package {
    inherit leanVersion;
    name = "oeis-lt";
    inherit deps;
    src = lib.cleanSource ./..;
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ rsync findutils ];
    phases = [ "unpackPhase" "buildPhase" "distPhase" ];
    buildPhase = ''
      mkdir -p $out/{bin,lib}
      lake build oeis-lt
      rsync -a .lake/build/lib/ $out/lib/
      rsync -a .lake/packages $out/lib/
      rsync -a .lake/build/bin/ $out/bin/
      LEAN_PATH=$(
        echo -n "$out/lib/lean"
        find $out/lib/packages -mindepth 1 -maxdepth 1 -type d \
          -exec echo -n ":{}/.lake/build/lib/lean" ';'
      )
      wrapProgram $out/bin/oeis-lt \
        --set LEAN_PATH "$LEAN_PATH" \
        --set PATH "$PATH" 
    '';
  };
}
