{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    let
      systems = with flake-utils.lib; [
        system.x86_64-linux
        system.aarch64-linux
        system.x86_64-darwin
        system.aarch64-darwin
      ];

      rustChannel = "nightly";
      rustVersion = "2022-09-27";

    in flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];

          # XXX FIXME: Mark all builds as content-addressed (CA) by default.
          config.contentAddressedByDefault = false;
        };

        rust-bin = pkgs.rust-bin."${rustChannel}"."${rustVersion}".default;

        rustPlatform = pkgs.makeRustPlatform {
          rustc = rust-bin;
          cargo = rust-bin;
        };

        jobs = rec {
          packages = flake-utils.lib.flattenTree rec {
            # These are all tools from upstream
            inherit (pkgs.gitAndTools) gh;
            inherit (pkgs)
              tagref sapling jq
              ;

            buck2 = pkgs.callPackage ./buck2 { inherit rustPlatform; };
          };

          toolchains = import ./toolchains { inherit pkgs; };

          # The default Nix shell. This is populated by direnv and used for the
          # interactive console that a developer uses when they use buck2, sl,
          # et cetera.
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with packages; [
              buck2 tagref sapling gh jq
            ];
          };
        };
      in {
        inherit (jobs) devShells;
        packages = flake-utils.lib.flattenTree rec {
          default = world;
          world = pkgs.writeText "world.json" (builtins.toJSON {
            shellPackages = jobs.packages;
            toolchainPackages = jobs.toolchains;
          });

          packages = jobs.packages // { recurseForDerivations = true; };
          toolchains = jobs.toolchains // { recurseForDerivations = true; };
        };
      });
}
