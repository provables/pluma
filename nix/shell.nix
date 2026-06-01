{ pkgs
, stdenv
, lib
, shell
, toolchain
, ...
}:
let
  packages = (with pkgs; [
    go-task
    python3
    uv
    findutils
  ]) ++ lib.optional stdenv.isDarwin pkgs.apple-sdk_14
  ++ [ toolchain ];
in
shell {
  name = "pluma-dev";
  inherit packages;
}


