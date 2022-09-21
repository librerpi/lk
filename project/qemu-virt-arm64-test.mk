# main project for qemu-aarch64
MODULES += \
	lib/hexdump \
	app/shell \
	lib/fs/zfs \
	#lib/cksum-helper \
	#lib/mincrypt

include project/virtual/test.mk
include project/virtual/fs.mk
include project/virtual/minip.mk
include project/target/qemu-virt-arm64.mk

