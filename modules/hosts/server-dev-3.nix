{
  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [ "ttm.pages_limit=33554432" ];
  };
}
