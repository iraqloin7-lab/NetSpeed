TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NetSpeed

NetSpeed_FILES = Tweak.x
NetSpeed_CFLAGS = -fobjc-arc

include $(THEOS_MAKEFILE_PATH)/tweak.mk
