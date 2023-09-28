{ pkgs, lib, config, ... }:
{
  imports = [
    ./mido-fetch-iso.nix
    ./mido-get-lang.nix
  ];
}
