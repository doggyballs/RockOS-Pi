################################################################################
#
# wvkbd
#
################################################################################

WVKBD_VERSION = 0.20
WVKBD_SITE = $(call github,jjsullivan5196,wvkbd,v$(WVKBD_VERSION))
WVKBD_DEPENDENCIES = wayland libxkbcommon pango cairo
WVKBD_LICENSE = GPL-1.0+
WVKBD_LICENSE_FILES = LICENSE

define WVKBD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		PREFIX=/usr \
		LAYOUT=mobintl \
		SCDOC=true
endef

define WVKBD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/wvkbd-mobintl $(TARGET_DIR)/usr/bin/wvkbd
endef

$(eval $(generic-package))
