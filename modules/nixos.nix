# agenix-maybe NixOS module
# Provides conditional agenix secrets that skip gracefully when .age files don't exist
{ config, lib, ... }:

with lib;

let
  cfg = config.age;

  # Filter maybeSecrets to only include those whose files exist
  existingSecrets = filterAttrs
    (name: secret: builtins.pathExists secret.file)
    cfg.maybeSecrets;

  # Get list of skipped secrets for warnings
  skippedSecrets = filterAttrs
    (name: secret: !builtins.pathExists secret.file)
    cfg.maybeSecrets;

  # Secret options (mirrors agenix's secretType)
  secretOptions = { name, ... }: {
    options = {
      file = mkOption {
        type = types.path;
        description = "Path to the age-encrypted file.";
      };

      path = mkOption {
        type = types.str;
        default = "/run/agenix/${name}";
        description = "Path where the decrypted secret will be placed.";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "File mode for the decrypted secret.";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = "Owner of the decrypted secret.";
      };

      group = mkOption {
        type = types.str;
        default = "root";
        description = "Group of the decrypted secret.";
      };

      name = mkOption {
        type = types.str;
        default = name;
        description = "Name of the secret.";
      };

      symlink = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a symlink to the secret.";
      };
    };
  };
in
{
  options.age = {
    maybeSecrets = mkOption {
      type = types.attrsOf (types.submodule secretOptions);
      default = { };
      description = ''
        Conditional secrets that are only defined if their .age file exists.
        This allows flake evaluation to succeed even when secrets haven't
        been created yet.
      '';
      example = literalExpression ''
        {
          my-secret = {
            file = ./secrets/my-secret.age;
            owner = "myuser";
          };
        }
      '';
    };

    warnOnSkippedSecrets = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to emit warnings for skipped maybeSecrets.";
    };
  };

  config = mkIf (cfg.maybeSecrets != { }) {
    # Pass existing secrets through to agenix's age.secrets
    age.secrets = existingSecrets;

    # Emit warnings for skipped secrets
    warnings = optionals cfg.warnOnSkippedSecrets (
      mapAttrsToList
        (name: secret: "agenix-maybe: Skipping secret '${name}' - file does not exist: ${toString secret.file}")
        skippedSecrets
    );
  };
}
