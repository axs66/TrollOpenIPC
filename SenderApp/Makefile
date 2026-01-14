TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat

THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TrollOpenIPCSenderApp

TrollOpenIPCSenderApp_FILES = Tweak.xm ../common/TOIPC.m
TrollOpenIPCSenderApp_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
