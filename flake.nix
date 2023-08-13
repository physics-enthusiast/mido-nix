{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  outputs = { self }: {
    nixosModules = {
      mido = import ./default.nix;
      default = self.nixosModules.mido;
    };
  };
}

