LOCAL_DIR := $(GET_LOCAL_DIR)

GLOBAL_INCLUDES += \
	$(LOCAL_DIR)/include

PLATFORM := bcm28xx
ARCH := arm64
ARM_CPU := cortex-a53
HAVE_ARM_TIMER = 1

GLOBAL_DEFINES += CRYSTAL=19200000 BCM2837=1

#include make/module.mk

