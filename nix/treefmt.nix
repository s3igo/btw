extraArgs:

{ inputs, ... }:

{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, system, ... }:

    {
      treefmt = {
        programs = {
          deadnix.enable = true;
          nixfmt.enable = true;
          statix.enable = true;
          rustfmt = {
            enable = true;
            package = extraArgs.toolchainFor.${system};
          };
          taplo = {
            enable = true;
            settings.formatting.array_auto_expand = false;
          };
          actionlint.enable = true;
          dprint = {
            enable = true;
            includes = [
              "*.md"
              "*.yml"
            ];
            settings.plugins = pkgs.dprint-plugins.getPluginList (
              plugins: with plugins; [
                dprint-plugin-markdown
                g-plane-pretty_yaml
              ]
            );
          };
          typos.enable = true;
        };
        settings.global.excludes = [ "LICENSE" ];
      };
    };
}
