### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers | tuy chinh cho Sony Xperia 1 VI (pdx245)

### AnyKernel setup
properties() { '
kernel.string=@KERNEL_STRING@
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=pdx245
device.name2=XQ-C72
device.name3=XQ-EC54
device.name4=XQ-EC72
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
# Tren pdx245 (GKI), boot chi chua kernel + dtb, ramdisk nam o init_boot.
# Vi vay KHONG dung dump_boot/write_boot (se bao "No ramdisk found"),
# ma chi split_boot roi flash_boot de thay kernel va giu nguyen phan con lai.
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
# Boot khong co ramdisk nen bo qua buoc kiem tra Magisk cpio.
NO_MAGISK_CHECK=1;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
split_boot;
flash_boot;
## end boot install
