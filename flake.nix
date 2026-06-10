{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    simple-flake.url = "github:waltermoreira/simple-flake";
    shell-utils.url = "github:waltermoreira/shell-utils";
    lean-toolchain.url = "github:provables/lean-toolchain-nix";
  };

  outputs = inputs@{ self, simple-flake, ... }:
    simple-flake.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { pkgs, inputs', ... }:
        let
          leanVersion = "4.30.0";
          toolchain = inputs'.lean-toolchain.lib.toolchain leanVersion;

          inherit (inputs'.lean-toolchain.lib) buildLean;

          shell = pkgs.callPackage ./nix/shell.nix {
            inherit (inputs'.shell-utils.lib) shell;
            inherit toolchain;
          };

          build = pkgs.callPackage ./nix/build.nix {
            inherit buildLean leanVersion;
          };
        in
        {
          packages = {
            default = build.pluma;
          };
          devShells = {
            default = shell;
          };
        };
    };
}
