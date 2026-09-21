{
  pkgs,
  ...
}:
{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    prettier.enable = true;
    shellcheck.enable = true;
    gofmt.enable = true;
    ruff.enable = true;
    yamlfmt.enable = true;
    toml-sort.enable = true;
    dos2unix.enable = true;
    keep-sorted.enable = true;
    kdlfmt.enable = true;
    # buggy as of right now
    # nufmt.enable = true;
    mdformat = {
      enable = true;
      # github-style markdown formatting support
      plugins = ps: [
        ps.mdformat-gfm
        ps.mdformat-frontmatter
        ps.mdformat-footnote # footnotes break otherwise
        (ps.mdformat-toc.overrideAttrs {
          meta.broken = false;
          doCheck = false;
          doInstallCheck = false;
          pytestCheckPhase = "";
        })
      ];
    };
  };

  settings = {
    # files to exlude from all formatting
    excludes = [
      "themes/*"
      "*.html"
      "public/*"
      ".direnv/*"
    ];
    formatter = {
      # formatter-specific settings
    };
  };
}
