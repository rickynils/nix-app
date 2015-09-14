{ pkgs ? import <nixpkgs> {} }:

{
  build = pkgs.callPackage ./default.nix {};
}
