ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed.)
  endif
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = SystemEmulator
VERSION = 0.1
PACKAGE_NAME = SystemEmulator

SystemEmulator_APPLICATION_ICON = SystemEmulator.png

SystemEmulator_RESOURCE_FILES = \
Resources/Info-gnustep.plist \
Resources/SystemEmulator.png

SystemEmulator_HEADER_FILES = \
Source/GSUTMConstants.h \
Source/GSUTMConfiguration.h \
Source/GSUTMConsoleController.h \
Source/GSUTMVirtualMachine.h \
Source/GSUTMMainWindowController.h \
Source/GSUTMAppDelegate.h

SystemEmulator_HEADER_FILES += \
Source/GSUTMAssistant.h

SystemEmulator_OBJC_FILES = \
Source/GSUTMConfiguration.m \
Source/GSUTMDisplayView.m \
Source/GSUTMConsoleController.m \
Source/GSUTMVirtualMachine.m \
Source/GSUTMMainWindowController.m \
Source/GSUTMAppDelegate.m \
Source/GSUTMAssistant.m \
Source/main.m

GSASSISTANT_FRAMEWORK = -lGSAssistantFramework -L/System/Applications/Utilities/CreateLiveMediaAssistant.app/Frameworks/GSAssistantFramework.framework
ADDITIONAL_INCLUDE_DIRS += -I/System/Applications/Utilities/CreateLiveMediaAssistant.app/Frameworks/GSAssistantFramework.framework/Headers
SystemEmulator_TOOL_LIBS += \
	-lX11 \
	-ldispatch
ADDITIONAL_LIB_DIRS += -L/System/Applications/Utilities/CreateLiveMediaAssistant.app/Frameworks/GSAssistantFramework.framework

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
