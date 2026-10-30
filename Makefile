ARCHS = armv7
TARGET := iphone:clang:10.3:8.0
INSTALL_TARGET_PROCESSES = Untis

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Untis

Untis_FILES = $(wildcard *.m)
Untis_FRAMEWORKS = UIKit CoreGraphics QuartzCore Security
Untis_CFLAGS = -fobjc-arc
Untis_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/application.mk
