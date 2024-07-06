{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
    neovim-builder.url = "github:s3igo/dotfiles?dir=neovim";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      fenix,
      crane,
      neovim-builder,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        name = "btw";
        pkgs = import nixpkgs { inherit system; };
        toolchain =
          with fenix.packages.${system};
          combine [
            (fromToolchainFile {
              file = ./rust-toolchain.toml;
              sha256 = "sha256-Ngiz76YP4HTY75GGdH2P+APE/DEIx2R/Dn+BwwOyzZU=";
            })
            default.rustfmt # rustfmt nightly
          ];
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
        src = craneLib.cleanCargoSource ./.;
        buildInputs =
          with pkgs;
          lib.optional stdenv.isDarwin [
            libiconv
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];
        commonArgs = {
          inherit src buildInputs;
          strictDeps = true;
          # CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS = "-Clink-arg=-fuse-ld=${pkgs.lld}/bin/ld64.lld";
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      in
      {
        packages = rec {
          neovim = neovim-builder.withModules {
            inherit system pkgs;
            modules = with neovim-builder.modules; [
              im-select
              nix
              rust
            ];
          };
          default = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
          container = pkgs.dockerTools.buildImage {
            inherit name;
            tag = "latest";
            copyToRoot = default;
            config.Cmd = [ "${default}/bin/${name}" ];
          };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = buildInputs;
          buildInputs =
            [
              toolchain
              self.packages.${system}.neovim
            ]
            ++ (with pkgs; [
              flyctl
              cargo-watch
            ]);
        };
      }
    );
}
