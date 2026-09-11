{
  id = "fpga";
  description = "FPGA host hardware and management stack";
  kind = "nixos";
  modules = [ "infra:system/fpga" ];
}
