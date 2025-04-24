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
        image-glibc = pkgs.dockerTools.buildImage {
          inherit (package) name;
          tag = "${package.version}-glibc";
          fromImage = pkgs.dockerTools.pullImage extraArgs.images.base-nossl;
          copyToRoot = [ self'.packages.dynamic ];
          config.Cmd = [ "/bin/${package.name}" ];
          architecture = "amd64";
        };

        image-musl = pkgs.dockerTools.buildImage {
          inherit (package) name;
          tag = "${package.version}-musl";
          fromImage = pkgs.dockerTools.pullImage extraArgs.images.static;
          copyToRoot = [ self'.packages.static ];
          config.Cmd = [ "/bin/${package.name}" ];
          architecture = "amd64";
        };
      };

      checks = {
        inherit (self'.packages) image-glibc image-musl;
      };
    };
}
