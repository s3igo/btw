extraArgs:

{ inputs, ... }:

{
  perSystem =
    {
      pkgs,
      self',
      system,
      ...
    }:

    let
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (extraArgs.mkToolchain system);
      src = craneLib.cleanCargoSource extraArgs.src;
      commonArgs = {
        inherit src;
        strictDeps = true;
      };
      commonArgs' = commonArgs // {
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      };
    in

    {
      packages = {
        _deps = commonArgs'.cargoArtifacts;

        btw = craneLib.buildPackage commonArgs'; # Native compilation

        # Cross-compile a dynamically linked glibc binary targeting x86_64-linux
        dynamic = craneLib.buildPackage (
          commonArgs'
          // {
            nativeBuildInputs = [ pkgs.pkgsCross.gnu64.stdenv.cc ];
            CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
            CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
            # For building cc-rs crate which ring crate depends on
            # https://docs.rs/cc/latest/cc/#external-configuration-via-environment-variables
            HOST_CC = "${pkgs.pkgsCross.gnu64.stdenv.cc.nativePrefix}cc";
            TARGET_CC = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
            CFLAGS = "-I$C_INCLUDE_PATH";
            doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
          }
        );

        # Cross-compile a dynamically linked glibc binary targeting x86_64-linux
        # using cargo-zigbuild to match the base image's glibc version
        dynamic-zig = craneLib.buildPackage (
          commonArgs'
          // {
            # Explicitly use the latest Zig version (v0.13.0) which works fine
            # as a cargo-zigbuild dependency on non-Windows platforms
            # https://github.com/rust-cross/cargo-zigbuild/pull/256
            # https://github.com/rust-cross/cargo-zigbuild/pull/274
            depsBuildBuild = [ (pkgs.cargo-zigbuild.override { inherit (pkgs) zig; }) ];
            nativeBuildInputs = [ pkgs.pkgsCross.gnu64.stdenv.cc ];
            preBuild = ''
              # Cache directory for C compiler
              export XDG_CACHE_HOME=$TMPDIR/xdg-cache
              mkdir -p $XDG_CACHE_HOME
              # Cache directory for cargo-zigbuild
              export CARGO_ZIGBUILD_CACHE_DIR=$TMPDIR/cargo-zigbuild-cache
              mkdir -p $CARGO_ZIGBUILD_CACHE_DIR
            '';
            # Specify the same glibc version as the distroless image
            # https://crane.dev/API.html#optional-attributes-1
            # https://github.com/rust-cross/cargo-zigbuild?tab=readme-ov-file#specify-glibc-version
            cargoBuildCommand = "cargo zigbuild --profile release --target x86_64-unknown-linux-gnu.2.36";
            CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.pkgsCross.gnu64.stdenv.cc.targetPrefix}cc";
            # For building cc-rs crate which ring crate depends on
            # https://docs.rs/cc/latest/cc/#external-configuration-via-environment-variables
            CFLAGS = "-I$C_INCLUDE_PATH";
            doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
          }
        );

        # Cross-compile a statically linked musl binary targeting x86_64-linux
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
        inherit (self'.packages)
          btw
          dynamic
          dynamic-zig
          static
          ;
      };
    };
}
