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

    let
      toolchainFor = inputs.nixpkgs.lib.genAttrs (import inputs.systems) (
        system:
        with inputs.fenix.packages.${system};
        combine [
          (fromToolchainFile {
            file = ./rust-toolchain.toml;
            sha256 = "sha256-X/4ZBHO3iW0fOenQ3foEvscgAPJYl2abspaBThDOukI=";
          })
          default.rustfmt # rustfmt nightly
          targets.x86_64-unknown-linux-gnu.stable.rust-std
          targets.x86_64-unknown-linux-musl.stable.rust-std
        ]
      );
      extraArgs = {
        __functor = with inputs.nixpkgs.lib; flip modules.importApply;
        src = ./.;
        images = {
          # nix run nixpkgs#nix-prefetch-docker -- gcr.io/distroless/base-nossl-debian12 nonroot-amd64
          base-nossl = {
            imageName = "gcr.io/distroless/base-nossl-debian12";
            imageDigest = "sha256:60437440fc565b42782cd72ff766a287d05b819182763d5d08a090010de407c3";
            hash = "sha256-Nhxw7t1MisF/PyUdGAouRsMEqyOHO+pLNtoKZuu6yCM=";
            finalImageName = "gcr.io/distroless/base-nossl-debian12";
            finalImageTag = "nonroot-amd64";
          };
          # nix run nixpkgs#nix-prefetch-docker -- gcr.io/distroless/static-debian12 nonroot-amd64
          static = {
            imageName = "gcr.io/distroless/static-debian12";
            imageDigest = "sha256:668a3f0546348876f7f7f6a3a5531b1150553fbf73d5f18e4c2768b3b4346052";
            hash = "sha256-Q5Yq2K8WtRnIBSHqCw715qp2qAMDB9W7AnKYWKp3jKc=";
            finalImageName = "gcr.io/distroless/static-debian12";
            finalImageTag = "nonroot-amd64";
          };
        };
        inherit toolchainFor;
      };
    in

    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = map extraArgs [
        ./nix/images.nix
        ./nix/packages.nix
      ];

      systems = import inputs.systems;

      perSystem =
        { pkgs, system, ... }:
        {
          devShells.default = pkgs.mkShell {
            packages = [
              toolchainFor.${system}
              pkgs.cargo-nextest
              # https://github.com/ziglang/zig/issues/23273
              (pkgs.cargo-zigbuild.override { zig = pkgs.zig_0_13; })
              pkgs.flyctl
            ];
            RUST_BACKTRACE = 1;
          };
        };

      flake.metadata = with inputs.nixpkgs.lib; {
        cargo = importTOML ./Cargo.toml;
        neovimFeatures = concat [
          "rust"
          "yaml"
        ];
      };
    };
}
