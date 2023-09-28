{
  description = "NixOS module which allows for declarative fetching of Windows ISOs";

  outputs = { self }: {
    nixosModules = {
      mido = import ./default.nix;
      default = self.nixosModules.mido;
    };
  };
}

