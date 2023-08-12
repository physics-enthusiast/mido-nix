{ pkgs, lib, config, ... }:
{
  config = lib.mkMerge [
    nixpkgs.overlays = [
      (final: prev: {
        fetchFromMicrosoft = final.callPackage ./fetchFromMicrosoft.nix {};
      })    
    ];
  ];
}
