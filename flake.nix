{
  description = "Conditional agenix secrets that skip gracefully when .age files don't exist";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
    in
    {
      nixosModules = {
        default = self.nixosModules.agenix-maybe;
        agenix-maybe = import ./modules/nixos.nix;
      };

      # Evaluates the module against a stub of agenix's age.secrets option and
      # asserts unset options are not passed through (so agenix defaults win).
      checks = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          eval = lib.evalModules {
            modules = [
              self.nixosModules.default
              {
                options.age.secrets = lib.mkOption {
                  type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
                  default = { };
                };
                options.warnings = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                };
                config.age.maybeSecrets = {
                  present = { file = ./tests/present.age; owner = "alice"; };
                  custom = { file = ./tests/present.age; path = "/etc/x"; group = "wheel"; mode = "0440"; };
                  missing = { file = ./tests/missing.age; };
                };
              }
            ];
          };
          s = eval.config.age.secrets;
          expect = name: cond: if cond then true else throw "agenix-maybe check failed: ${name}";
        in
        assert expect "present passed through" (s ? present);
        assert expect "missing skipped" (!(s ? missing));
        assert expect "unset options dropped" (s.present == { file = ./tests/present.age; owner = "alice"; });
        assert expect "set options kept" (s.custom.path == "/etc/x" && s.custom.group == "wheel" && s.custom.mode == "0440");
        assert expect "warning for missing" (builtins.length eval.config.warnings == 1);
        {
          module-eval = pkgs.runCommand "agenix-maybe-module-eval" { } "touch $out";
        });

      # Standalone library functions for use without the module
      lib = {
        # Check if an age file exists and return secret config or empty attrset
        mkMaybeSecret = { file, ... }@args:
          if builtins.pathExists file
          then { ${args.name or (builtins.baseNameOf (lib.removeSuffix ".age" (toString file)))} = args; }
          else { };

        # Check if age file exists
        ageFileExists = file: builtins.pathExists file;
      };
    };
}
