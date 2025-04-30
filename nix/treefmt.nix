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
          yamlfmt = {
            enable = true;
            settings.formatter = {
              type = "basic";
              retain_line_breaks_single = true;
              max_line_length = 80;
              scan_folded_as_literal = true;
              trim_trailing_whitespace = true;
              eof_newline = true;
            };
          };
          dprint = {
            enable = true;
            includes = [ "*.md" ];
            settings.plugins = pkgs.dprint-plugins.getPluginList (
              plugins: with plugins; [ dprint-plugin-markdown ]
            );
          };
          typos.enable = true;
        };
        settings.global.excludes = [ "LICENSE" ];
      };
    };
}
