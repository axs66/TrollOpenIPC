TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TrollOpenIPCReceiverSB

TrollOpenIPCReceiverSB_FILES = Tweak.xm ../common/TOIPC.m
TrollOpenIPCReceiverSB_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
