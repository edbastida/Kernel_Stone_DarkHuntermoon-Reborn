## AnyKernel3 Ramdisk Mod Script — Magisk variant (no built-in KSU)
## osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=DarkHunterMoon_reborn — by Edbastida (educational use only)
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

## ── Banner + educational-use warning ────────────────────────────────────────
ui_print " ";
ui_print "================================================";
ui_print "                                                ";
ui_print "   ___    _ _              _   _    _           ";
ui_print "  | __|__| | |__  __ _ ___| |_(_)__| |__ _      ";
ui_print "  | _|/ _\` | '_ \\/ _\` (_-<  _| / _\` / _\` |     ";
ui_print "  |___\\__,_|_.__/\\__,_/__/\\__|_\\__,_\\__,_|     ";
ui_print "                                                ";
ui_print "    >>  D A R K   H U N T E R   M O O N  <<     ";
ui_print "        ~ Reborn Edition · Magisk build ~       ";
ui_print "                                                ";
ui_print "    NetHunter Kernel  ·  Linux 5.4.302          ";
ui_print "    POCO X5 5G  /  Redmi Note 12 5G             ";
ui_print "                                                ";
ui_print "    Root: provide via Magisk after first boot.  ";
ui_print "                                                ";
ui_print "================================================";
ui_print " ";
ui_print "  /!\\  AVISO  /  WARNING                        ";
ui_print "                                                ";
ui_print "  Este kernel se distribuye EXCLUSIVAMENTE      ";
ui_print "  con fines educativos y de investigacion en    ";
ui_print "  seguridad. El uso contra sistemas o redes     ";
ui_print "  sin autorizacion expresa es ILEGAL. El        ";
ui_print "  autor (Edbastida) no se responsabiliza del    ";
ui_print "  mal uso de este software.                     ";
ui_print "                                                ";
ui_print "  Provided for EDUCATIONAL and SECURITY         ";
ui_print "  RESEARCH purposes only. Unauthorized use      ";
ui_print "  against any system or network is illegal.     ";
ui_print "  The author assumes no liability for misuse.   ";
ui_print "                                                ";
ui_print "================================================";
ui_print " ";

## AnyKernel install
## With do.modules=1 + do.systemless=1, AnyKernel3 places .ko files in
## modules/system/lib/modules/ and patches the kernel for Magisk-systemless
## module loading. The user must flash Magisk separately to activate them.
split_boot;
flash_boot;
## end install
