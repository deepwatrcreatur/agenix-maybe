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

  # INVARIANT: options left unset are null and are dropped before reaching
  # age.secrets, so agenix's own defaults apply (path under age.secretsDir,
  # group = owner's primary group). Hard-coding defaults here diverged from them.
  optional = type: description: mkOption {
    type = types.nullOr type;
    default = null;
    description = "${description} Unset (null) uses agenix's default.";
  };

  secretOptions = { ... }: {
    options = {
      file = mkOption {
        type = types.path;
        description = "Path to the age-encrypted file.";
      };
      path = optional types.str "Path where the decrypted secret will be placed.";
      mode = optional types.str "File mode for the decrypted secret.";
      owner = optional types.str "Owner of the decrypted secret.";
      group = optional types.str "Group of the decrypted secret.";
      name = optional types.str "Name of the secret.";
      symlink = optional types.bool "Whether to create a symlink to the secret.";
    };
  };

  toAgenix = secret: filterAttrs (_: v: v != null) secret;
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
    age.secrets = mapAttrs (_: toAgenix) existingSecrets;

    # Emit warnings for skipped secrets
    warnings = optionals cfg.warnOnSkippedSecrets (
      mapAttrsToList
        (name: secret: "agenix-maybe: Skipping secret '${name}' - file does not exist: ${toString secret.file}")
        skippedSecrets
    );
  };
}
