{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    clang
    cmake
    ninja
    pkg-config
    chromium
    android-tools
  ];
}
