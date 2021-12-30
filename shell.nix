{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.elixir pkgs.nodejs pkgs.stripe-cli
  ];
}
