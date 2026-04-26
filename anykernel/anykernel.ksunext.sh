## AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=DarkHunterMoon_reborn — by Edbastida (educational use only)
do.devicecheck=1
do.modules=0
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
ui_print "             ~ Reborn Edition ~                 ";
ui_print "                                                ";
ui_print "    NetHunter Kernel  ·  Linux 5.4.302          ";
ui_print "    POCO X5 5G  /  Redmi Note 12 5G             ";
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
split_boot;
flash_boot;

## NetHunter: install Realtek .ko as a self-contained KSU Next module.
## AnyKernel3's built-in module path requires Magisk or classic KSU; KSU Next
## (com.rifsxd.ksunext) is not detected, so we install manually.
install_nethunter_realtek_module() {
  local SRC="$AKHOME/ksu_module";
  local DEST="/data/adb/modules/nethunter-realtek-drivers";

  [ -d "$SRC" ] || return 0;
  [ -d /data/adb ] || { ui_print " " "Warning: /data/adb missing — skipping Realtek module install"; return 0; }

  ui_print " " "Installing Realtek drivers as KSU Next module...";
  rm -rf "$DEST";
  mkdir -p "$DEST";
  cp -rf "$SRC"/. "$DEST"/;
  set_perm_recursive 0 0 0755 0644 "$DEST";
  [ -f "$DEST/service.sh"      ] && set_perm 0 0 0755 "$DEST/service.sh";
  [ -f "$DEST/post-fs-data.sh" ] && set_perm 0 0 0755 "$DEST/post-fs-data.sh";
  touch "$DEST/update";
  ui_print "  -> /data/adb/modules/nethunter-realtek-drivers";
}
install_nethunter_realtek_module;
## end install
