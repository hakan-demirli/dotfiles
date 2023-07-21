
* ```lscpu``` ensure virtualizaation is AMD-V

* ```sudo dmesg | grep -i -e DMAR -e IOMMU``` ensure it is enabled and valid

* ```./iom.sh```
    * -> We have a greate IOMMU Group:
    * ```IOMMU Group 10:
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti Mobile] [10de:2191] (rev a1)
    01:00.1 Audio device [0403]: NVIDIA Corporation TU116 High Definition Audio Controller [10de:1aeb] (rev a1)
    01:00.2 USB controller [0c03]: NVIDIA Corporation TU116 USB 3.1 Host Controller [10de:1aec] (rev a1)
    01:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU116 USB Type-C UCSI Controller [10de:1aed] (rev a1)
    ```

*
* Add this to `/etc/default/grub`. Kernel parameter.
    * ```vfio-pci.ids=10de:2191,10de:1aeb,10de:1aec,10de:1aed```
        * Example:
        ```GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet amd_iommu=on iommu=pt video=efifb:off vfio-pci.ids=10de:2191,10de:1aeb,10de:1aec,10de:1aed"```

* Rebuild the Grub config
    * ```sudo grub-mkconfig -o /boot/grub/grub.cfg```

* Create the following file with following content:
    * ```/etc/modprobe.d/vfio.conf```
        * ```softdep drm pre: vfio-pci``

* Reboot

* Verify it worked
    * ```sudo dmesg | grep -i vfio```
    * ```lspci -nnk -d 10de:2191```

Kernel modules