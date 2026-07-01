{ inputs, lib, ... }:
let
  inherit (inputs) infra-lib;

  types = infra-lib.lib.types { inherit lib; };

  inventory = infra-lib.lib.mkInventory {
    inherit lib types;
    inherit (inputs) self;
  };

  codegen = infra-lib.lib.mkCodegen { inherit lib inventory; };

  intent = infra-lib.lib.mkIntent { inherit lib inventory; };

  builder = infra-lib.lib.mkRole {
    inherit inputs lib inventory;
    inherit (inputs) self;
    libRoot = infra-lib;
  };

  hostFacts = infra-lib.lib.mkHostFacts inventory;
  kexecRootKeys = infra-lib.lib.mkKexecRootKeys inventory;
in
{
  flake = {
    lib = {
      inherit
        inventory
        codegen
        intent
        types
        hostFacts
        kexecRootKeys
        ;
    };

    inherit (builder) nixosConfigurations darwinConfigurations nixosModules;
  };
}
