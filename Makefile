THEOS_PACKAGE_SCHEME = roothide
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NetSpeed

NetSpeed_FILES = Tweak.x
NetSpeed_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk
