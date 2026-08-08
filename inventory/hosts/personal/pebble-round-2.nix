{
  id = "pebble-round-2";
  hostname = "pebble-round-2";
  roles = [ ];
  state = "planned";

  location.kind = "workstation";

  ownership = {
    class = "personal";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "sifli";
    cpu_sockets = 1;
    cpu_cores_per_socket = 2;
    cpu_threads_per_core = 1;
    cpu_model = "SiFli SF32LB52J (Arm Cortex-M33 STAR-MC1 big.LITTLE, HCPU 192MHz + LCPU 24MHz)";
    ram_mib = 16;
    arch = "arm-none-eabi";
    os = "pebbleos";
    chassis = "Pebble Round 2 (getafix@dvt2)";
  };

  monitoring = {
    enabled = false;
    always_on = false;
  };

  labels = {
    device_type = "coredevices-pebble-round-2";
    device_role = "wearable-smartwatch";
    board = "getafix";
    board_revision = "dvt2";
    platform = "gabbro";
    pebbleos_version = "v4.28.0";
    pebbleos_sdk_version = "0.1.7";
    display = "1.3-inch 260x260 64-color e-paper touch";
    connectivity = "ble-only";
    controls_host = "";
  };
}
