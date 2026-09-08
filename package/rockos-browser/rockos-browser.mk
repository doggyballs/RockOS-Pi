################################################################################
#
# rockos-browser
#
################################################################################

ROCKOS_BROWSER_VERSION = 1.0
ROCKOS_BROWSER_SITE = $(BR2_EXTERNAL_ROCKOS_PATH)/rockos-browser
ROCKOS_BROWSER_SITE_METHOD = local
ROCKOS_BROWSER_DEPENDENCIES = qt5base qt5webengine

define ROCKOS_BROWSER_CONFIGURE_CMDS
	(cd $(@D); $(TARGET_MAKE_ENV) $(HOST_DIR)/bin/qmake \
		-spec devices/linux-buildroot-g++ rockos-browser.pro)
endef

define ROCKOS_BROWSER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define ROCKOS_BROWSER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rockos-browser $(TARGET_DIR)/usr/bin/rockos-browser
endef

$(eval $(generic-package))
