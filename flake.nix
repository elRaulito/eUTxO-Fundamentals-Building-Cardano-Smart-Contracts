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
        in
        {
          packages.default = pkgs.hello;
          devShells.default = pkgs.mkShell {
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
