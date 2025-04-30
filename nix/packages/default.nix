extraArgs:

{ inputs, ... }:

{
  imports = map extraArgs [ ./images.nix ];

  perSystem =
    {
      pkgs,
      lib,
      self',
      system,
      ...
    }:

    let
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain extraArgs.toolchainFor.${system};
      src = craneLib.cleanCargoSource extraArgs.src;
      commonArgs = {
        inherit src;
        strictDeps = true;
      };
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      commonArgs' = commonArgs // {
        inherit cargoArtifacts;
      };
      crossArgs =
        args@{
          target ? "x86_64-unknown-linux-gnu",
          libcVersion ? null,
          ...
        }:
        let
          cleanedArgs = builtins.removeAttrs args [
            "target"
            "libcVersion"
          ];
          # https://github.com/rust-cross/cargo-zigbuild?tab=readme-ov-file#specify-glibc-version
          targetStr = target + lib.optionalString (builtins.isString libcVersion) ".${libcVersion}";
        in
        commonArgs'
        // cleanedArgs
        // {
          depsBuildBuild = [ pkgs.cargo-zigbuild ];
          nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
          # https://crane.dev/API.html#optional-attributes-1
          cargoBuildCommand = "cargo zigbuild --profile release --target ${targetStr}";
          # Workaround for https://github.com/rust-lang/rust/issues/78210
          cargoTestCommand = "cargo test --profile release --target ${target}";
        };
    in

    {
      packages = {
        _deps = cargoArtifacts;

        btw = craneLib.buildPackage commonArgs';

        # Cross-compile a dynamically linked glibc binary targeting x86_64-linux
        # using cargo-zigbuild to match the base image's glibc version
        dynamic = craneLib.buildPackage (crossArgs {
          # Specify the same glibc version as the distroless image
          libcVersion = "2.36";
          doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
        });

        # Cross-compile a statically linked musl binary targeting x86_64-linux
        static = craneLib.buildPackage (crossArgs {
          target = "x86_64-unknown-linux-musl";
          CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static -C link-self-contained=yes";
          doCheck = pkgs.stdenv.buildPlatform.system == "x86_64-linux";
        });

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
        inherit (self'.packages) dynamic static;
      };

      devShells.default = craneLib.devShell {
        inherit (self') checks;
        packages = with pkgs; [
          # https://github.com/ziglang/zig/issues/23273
          (cargo-zigbuild.override { zig = zig_0_13; })
          flyctl
        ];
        RUST_BACKTRACE = 1;
      };
    };
}
