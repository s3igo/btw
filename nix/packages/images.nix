extraArgs:

{ config, ... }:

let
  inherit (config.flake.metadata.cargo) package;
in

{
  perSystem =
    { pkgs, self', ... }:

    {
      packages = {
        btw-glibc-image = pkgs.dockerTools.buildImage {
          inherit (package) name;
          tag = "${package.version}-glibc";
          fromImage = pkgs.dockerTools.pullImage extraArgs.images.base-nossl;
          copyToRoot = [ self'.packages.btw-glibc ];
          config.Cmd = [ "/bin/${package.name}" ];
          architecture = "amd64";
        };

        btw-musl-image = pkgs.dockerTools.buildImage {
          inherit (package) name;
          tag = "${package.version}-musl";
          fromImage = pkgs.dockerTools.pullImage extraArgs.images.static;
          copyToRoot = [ self'.packages.btw-musl ];
          config.Cmd = [ "/bin/${package.name}" ];
          architecture = "amd64";
        };
      };
    };
}
