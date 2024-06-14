# System bauen

```console
# (optional) Building to see if everything works
$ nix build .\#nixosConfigurations.kuschelhaufen.config.system.build.toplevel -Lv
```
# Remote deploy

```console
$ nixos-rebuild dry-activate --flake .#kuschelhaufen --use-remote-sudo --use-substitutes --target-host kuschelhaufen.cuties.social
```

# Local deployment

```console
$ nixos-rebuild dry-activate --flake .#kuschelhaufen
```
# Updating emojis

The following will only update the `custom-emojis` flake input.

```console
$ nix flake lock --update-input custom-emojis
```
