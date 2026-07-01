{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      inputs.import-tree.matchNot ".*/checks/lib(/.*)?" ./modules/nix
    );

  inputs = {
    infra-lib.url = "github:hakan-demirli/infra-lib";

    nixpkgs.follows = "infra-lib/nixpkgs";
    flake-parts.follows = "infra-lib/flake-parts";
    import-tree.follows = "infra-lib/import-tree";
    disko.follows = "infra-lib/disko";
    sops-nix.follows = "infra-lib/sops-nix";
    impermanence.follows = "infra-lib/impermanence";
    srvos.follows = "infra-lib/srvos";
    nixos-hardware.follows = "infra-lib/nixos-hardware";
    nix-darwin.follows = "infra-lib/nix-darwin";

    nur.url = "github:hakan-demirli/NUR";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
