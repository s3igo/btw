{
  description = "A Discord bot that notices Rust projects in chat";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.flake-parts.flakeModules.easyOverlay ];

      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          inputs',
          self',
          ...
        }:

        let
          toolchain =
            with inputs'.fenix.packages;
            combine [
              (fromToolchainFile {
                file = ./rust-toolchain.toml;
                sha256 = "sha256-s1RPtyvDGJaX/BisLT+ifVfuhDT1nZkZ1NcK8sbwELM=";
              })
              default.rustfmt # rustfmt nightly
            ];
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
          src = craneLib.cleanCargoSource ./.;
          buildInputs =
            with pkgs;
            lib.optionals stdenv.isDarwin [
              libiconv
              darwin.apple_sdk.frameworks.SystemConfiguration
            ];
          commonArgs = {
            inherit src buildInputs;
            strictDeps = true;
          };
          commonArgs' = commonArgs // {
            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          };
        in

        {
          packages = {
            btw = craneLib.buildPackage commonArgs';
            container = pkgs.dockerTools.buildImage rec {
              name = "btw";
              tag = "latest";
              copyToRoot = [ self'.packages.btw ];
              config.Cmd = [ "/bin/${name}" ];
            };
            default = self'.packages.btw;
          };

          checks = {
            btw-build = craneLib.buildPackage (commonArgs' // { doCheck = false; });
            btw-clippy = craneLib.cargoClippy (
              commonArgs' // { cargoClippyExtraArgs = "--all-targets -- -D warnings"; }
            );
            btw-fmt = craneLib.cargoFmt { inherit src; };
            btw-nextest = craneLib.cargoNextest commonArgs';
            btw-audit = craneLib.cargoAudit {
              inherit src;
              inherit (inputs) advisory-db;
            };
          };

          devShells.default = pkgs.mkShell {
            inherit buildInputs;
            packages = [
              toolchain
              pkgs.cargo-nextest
              pkgs.cargo-watch
              pkgs.flyctl
            ];
            shellHook = ''
              export RUST_BACKTRACE=1
            '';
          };

          overlayAttrs = {
            inherit (self'.packages) btw;
          };
        };
    };
}
