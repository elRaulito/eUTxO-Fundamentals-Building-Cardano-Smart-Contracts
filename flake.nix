{
  description = "A very basic flake";

  inputs = {
    # latex indent is broken on the latest nixpkgs : /
    nixpkgs.url = "github:nixos/nixpkgs?rev=ef7226d68ba45b2de3e428e5d4bb4532caffec7b";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs@{ flake-parts, nixpkgs, pre-commit-hooks, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      perSystem = { system, config, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          # Ideally we figure out what exact package is used, but too much work
          tex = pkgs.texlive.combine { inherit (pkgs.texlive) scheme-full; };
        in
        {
          packages.default = pkgs.stdenvNoCC.mkDerivation rec {
            name = "eUTxO-fundamentals-pdf";
            src = ./eBook;
            buildInputs = [ pkgs.coreutils tex pkgs.texlive.bin.pygmentex ];
            phases = [ "unpackPhase" "buildPhase" "installPhase" ];
            buildPhase = ''
              mkdir -p .cache/texmf-var
              env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
                latexmk --shell-escape -interaction=nonstopmode -pdf -lualatex \
                light.tex dark.tex
            '';
            installPhase = ''
              mkdir -p $out
              cp *.pdf $out/
            '';
          };
          devShells.default = pkgs.mkShell {
            buildInputs = [ tex ];
            shellHook = ''
              export LC_CTYPE=C.UTF-8;
              export LC_ALL=C.UTF-8;
              export LANG=C.UTF-8;
              ${config.pre-commit.installationScript}
            '';
          };
          pre-commit = {
            settings = {
              src = ./.;

              hooks = {
                nixpkgs-fmt.enable = true;
                statix.enable = true;
                deadnix.enable = true;
                latexindent = {
                  enable = true;
                  settings.flags = "-l -wd -s";
                };
                typos = {
                  enable = true;
                  excludes = [ "eBook/template" ];
                };
              };
            };
          };
        };
    };
}
