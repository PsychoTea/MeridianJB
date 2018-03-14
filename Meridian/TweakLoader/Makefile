THEOS := $(shell source ~/.profile; bash -l -c "echo $$THEOS")
ARCHS  = arm64 armv7 armv7s
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TweakLoader
TweakLoader_FILES = TweakLoader.x
TweakLoader_USE_SUBSTRATE=0

include $(THEOS_MAKE_PATH)/tweak.mk
