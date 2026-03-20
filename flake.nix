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
