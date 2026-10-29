{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      inputs.import-tree.matchNot ".*/checks/lib(/.*)?" ./modules/nix
    );

  inputs = {
    infra-lib.url = "github:hakan-demirli/infra-lib";

    nixpkgs.follows = "infra-lib/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-qmllint.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    nixpkgs-openwrt.url = "github:NixOS/nixpkgs/31ecbaca1bdefa45dffc409f0250bd8039ea0010";
    flake-parts.follows = "infra-lib/flake-parts";
    import-tree.follows = "infra-lib/import-tree";
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.follows = "infra-lib/disko";
    sops-nix.follows = "infra-lib/sops-nix";
    impermanence.follows = "infra-lib/impermanence";
    srvos.follows = "infra-lib/srvos";
    nixos-hardware.follows = "infra-lib/nixos-hardware";
    nix-darwin.follows = "infra-lib/nix-darwin";

    nur = {
      url = "github:hakan-demirli/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
