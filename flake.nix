{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    shell-utils.url = "github:waltermoreira/shell-utils";
    lean-toolchain-nix.url = "github:provables/lean-toolchain-nix";
  };
  outputs = { self, nixpkgs, flake-utils, shell-utils, lean-toolchain-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        shell = shell-utils.myShell.${system};
        lean-toolchain = lean-toolchain-nix.packages.${system}.lean-toolchain-4_20;
        oeis-lt = pkgs.writeShellApplication {
          name = "oeis-lt";
          text = ''
            echo "Running oeis-lt"
          '';
        };
      in
      {
        packages = {
          default = oeis-lt;
        };

        devShell = shell {
          name = "gen-seq";
          buildInputs = with pkgs; [
            lean-toolchain
            elan
            go-task
            python3
            uv
            findutils
            lsof
          ] ++ lib.optional stdenv.isDarwin apple-sdk_14;
        };
      }
    );
}
