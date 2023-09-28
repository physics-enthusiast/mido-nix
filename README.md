# NixOS Mido Module

This module implements the `pkgs.fetchFromMicrosoft` fetcher via a `nixpkgs` overlay which downloads Windows ISOs from Microsoft's (reverse engineered) proprietary downloading API. Downloads are sourced from official Microsoft servers.

Example usage:

1. Add this repo to the inputs of your system flake and add `mido-nix.nixosModules.default` to its module set: 
   
   ```nix
   {
     inputs.mido-nix.url = "github:physics-enthusiast/mido-nix";
     # optional, not necessary for the module
     #inputs.mido-nix.inputs.nixpkgs.follows = "nixpkgs";
   
     outputs = { self, nixpkgs, mido-nix }: {
       # change `yourhostname` to your actual hostname
       nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
         # customize to your system
         system = "x86_64-linux";
         modules = [
           ./configuration.nix
           mido-nix.nixosModules.default
         ];
       };
     };
   }
   ```
   
   For an introduction to flakes, see [here](https://nixos.wiki/wiki/Flakes).

2. Use as a fetcher to create a derivation that places the ISO into the store:
   
   ```nix
     pkgs.fetchFromMicrosoft {
       productID = "2618";
       windowsVersion = "10";
     #  language = "English (United States)"
       hash="sha256-pvRwym0zHrNTuBXAQ+Mno0f1lPN/9SXxd2Rzj+gShS4=";
     };
   ```

## Reference

#### `productID`

`productID` is the number corresponding to the build of windows you want to download. For a list of currently available product IDs and their corresponding builds, see [here](https://massgrave.dev/msdl/).

#### `windowsVersion`

`windowsVersion` is the version of windows desired. Can be either 8, 10, or 11.

#### `language`

`language` is the language of the ISO that will be downloaded. For a list of available languages, run `mido_get_langs <productID> <windowsVersion>`. Note that the language must be copied exactly (for instance, "English (United States)", not "en-US" or "english").

Example:

```bash
mido_get_langs 2618 10
```

## Acknowledgements

This was heavily based and inspired by [GitHub - ElliotKillick/Mido: The Secure Microsoft Windows Downloader](https://github.com/ElliotKillick/Mido)

## License

MIT License - Copyright (C) 2023 Elliot Killick <contact@elliotkillick.com>
