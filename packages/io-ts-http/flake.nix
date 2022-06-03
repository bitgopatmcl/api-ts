{
  description = "@api-ts/io-ts-http";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat, workspace }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.callPackage "../../workspace.nix" {
          inherit pkgs;
          nodePackage = "@api-ts/io-ts-http";
        }
      );
}
