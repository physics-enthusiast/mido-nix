{
  description = "NixOS module which allows for declarative fetching of Windows ISOs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  
  outputs = { self, nixpkgs }: let
  systems = [
    "x86_64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
    "aarch64-linux"
  ];
  forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  suffix-version = version: attrs: nixpkgs.lib.mapAttrs' (name: value: nixpkgs.lib.nameValuePair (name + version) value) attrs;
  suffix-stable = suffix-version "-23_05";
  in
  {
    nixosModules = {
      midoFetch = import ./mido-fetch-iso.nix;
	  midoGet = import ./mido-get-lang.nix;
      default = import ./default.nix;
    };
    packages = forAllSystems (system:
      import ./mido-get-lang.nix {
        pkgs = nixpkgs.legacyPackages.${system};
	  });
  };
}

