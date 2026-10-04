TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NetSpeed
NetSpeed_FILES = Tweak.x
NetSpeed_CFLAGS = -fobjc-arc
NetSpeed_FRAMEWORKS = UIKit Foundation SystemConfiguration

include $(THEOS_MAKE_PATH)/tweak.mk
