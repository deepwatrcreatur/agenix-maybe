# agenix-maybe

Conditional agenix secrets that skip gracefully when `.age` files don't exist.

## Problem

When using [agenix](https://github.com/ryantm/agenix), referencing a `.age` file that doesn't exist causes Nix evaluation to fail:

```nix
age.secrets.my-secret.file = ./secrets/my-secret.age;  # Fails if file missing
```

This creates a chicken-and-egg problem: you can't evaluate your flake until the secret exists, but you might want to deploy first and create the secret later.

## Solution

`agenix-maybe` provides `age.maybeSecrets` - secrets that are only defined when their `.age` file exists:

```nix
age.maybeSecrets.my-secret = {
  file = ./secrets/my-secret.age;
  owner = "myuser";
};
```

If the file exists, it's passed to `age.secrets`. If not, it's silently skipped (with an optional warning).

## Usage

### Flake Input

```nix
{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    agenix-maybe.url = "github:deepwatrcreatur/agenix-maybe";
  };

  outputs = { self, nixpkgs, agenix, agenix-maybe, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        agenix.nixosModules.default
        agenix-maybe.nixosModules.default
        {
          age.maybeSecrets.my-api-key = {
            file = ./secrets/my-api-key.age;
            owner = "myservice";
          };
        }
      ];
    };
  };
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `age.maybeSecrets.<name>.file` | path | required | Path to the `.age` file |
| `age.maybeSecrets.<name>.path` | string or null | agenix default (`<age.secretsDir>/<name>`) | Decrypted secret location |
| `age.maybeSecrets.<name>.owner` | string or null | agenix default (root) | File owner |
| `age.maybeSecrets.<name>.group` | string or null | agenix default (owner's primary group) | File group |
| `age.maybeSecrets.<name>.mode` | string or null | agenix default (`"0400"`) | File permissions |
| `age.maybeSecrets.<name>.symlink` | bool or null | agenix default (`true`) | Symlink from `path` into the generation directory |
| `age.warnOnSkippedSecrets` | bool | `true` | Emit warnings for missing secrets |

Options left unset are not passed to `age.secrets`, so they behave exactly as in
plain agenix. Before this, `path` was hard-coded to `/run/agenix/<name>` and
`group` to `root`; if you relied on `group = "root"` with an `owner` whose
primary group is different, set `group = "root"` explicitly.

### Library Functions

For use outside the module system:

```nix
let
  agenix-maybe = inputs.agenix-maybe;
in
{
  # Check if a secret file exists
  nix.settings.netrc-file = lib.mkIf
    (agenix-maybe.lib.ageFileExists ./secrets/netrc.age)
    "/run/agenix/netrc";
}
```

## License

MIT
