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
          lib,
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
              targets.x86_64-unknown-linux-gnu.stable.rust-std
              targets.x86_64-unknown-linux-musl.stable.rust-std
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
          inherit (lib.importTOML ./Cargo.toml) package;
        in

        {
          packages = {
            dynamic = craneLib.buildPackage (
              commonArgs'
              // {
                depsBuildBuild = [ pkgs.pkgsBuildBuild.qemu ];
                nativeBuildInputs = [ pkgs.pkgsCross.gnu64.stdenv.cc ];
                CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
                CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
                CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-system-x86_64";
                # For building cc-rs crate which ring crate depends on
                # https://docs.rs/cc/latest/cc/#external-configuration-via-environment-variables
                HOST_CC = "${pkgs.pkgsCross.gnu64.stdenv.cc.nativePrefix}cc";
                TARGET_CC = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
                CFLAGS = "-I$C_INCLUDE_PATH";
                doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
              }
            );
            dynamic-zig = craneLib.buildPackage (
              commonArgs'
              // {
                depsBuildBuild = [ pkgs.cargo-zigbuild ];
                nativeBuildInputs = [ pkgs.pkgsCross.gnu64.stdenv.cc ];
                preBuild = ''
                  # Cache directory for C compiler
                  export XDG_CACHE_HOME=$TMPDIR/xdg_cache
                  mkdir -p $XDG_CACHE_HOME
                  # Cache directory for cargo-zigbuild
                  export CARGO_ZIGBUILD_CACHE_DIR=$TMPDIR/cargo-zigbuild-cache
                  mkdir -p $CARGO_ZIGBUILD_CACHE_DIR
                '';
                # https://crane.dev/API.html#optional-attributes-1
                cargoBuildCommand = "cargo zigbuild --release";
                CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
                CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
                # For building cc-rs crate which ring crate depends on
                # https://docs.rs/cc/latest/cc/#external-configuration-via-environment-variables
                CFLAGS = "-I$C_INCLUDE_PATH";
                doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
              }
            );
            static = craneLib.buildPackage (
              commonArgs'
              // {
                nativeBuildInputs = [ pkgs.pkgsCross.musl64.stdenv.cc ];
                CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
                CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static -C link-self-contained=yes";
                CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgs.pkgsCross.musl64.stdenv.cc.targetPrefix}cc";
                CFLAGS = "-I${pkgs.pkgsCross.musl64.musl.dev}/include";
                doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
              }
            );
            btw = craneLib.buildPackage commonArgs';
            container = pkgs.dockerTools.buildImage {
              inherit (package) name;
              tag = package.version;
              copyToRoot = [ self'.packages.btw ];
              config.Cmd = [ "/bin/${package.name}" ];
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
