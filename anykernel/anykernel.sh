## AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=NetHunter Kernel for POCO X5 5G / Redmi Note 12 5G
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=stone
device.name2=moonstone
device.name3=sunstone
supported.versions=
supported.patchlevels=
'; }

# boot shell variables
block=boot;
is_slot_device=auto;

## AnyKernel methods (DO NOT CHANGE)
. tools/ak3-core.sh;

## AnyKernel install
split_boot;
flash_boot;
## end install
