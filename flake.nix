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
      src = ./.;
      mkToolchain =
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
        ];
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
      withExtraArgs = {
        __functor = self: map (path: inputs.nixpkgs.lib.modules.importApply path self);
        inherit src mkToolchain images;
      };
    in

    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = withExtraArgs [
        ./nix/containers.nix
        ./nix/packages.nix
      ];

      systems = import inputs.systems;

      perSystem =
        { pkgs, system, ... }:
        {
          devShells.default = pkgs.mkShell {
            packages = [
              (mkToolchain system)
              pkgs.cargo-nextest
              pkgs.cargo-watch
              pkgs.flyctl
            ];
            shellHook = ''
              export RUST_BACKTRACE=1
            '';
          };
        };

      flake.meta.cargo = inputs.nixpkgs.lib.importTOML ./Cargo.toml;
    };
}
