################################################################################
#
# kbd-toggle
#
################################################################################

KBD_TOGGLE_VERSION = 1.0
KBD_TOGGLE_SITE = $(BR2_EXTERNAL_ROCKOS_PATH)/package/kbd-toggle
KBD_TOGGLE_SITE_METHOD = local
KBD_TOGGLE_DEPENDENCIES = wayland cairo host-pkgconf

# Need wayland-scanner on the host to generate protocol headers
KBD_TOGGLE_BUILD_DEPENDENCIES = host-wayland

define KBD_TOGGLE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		WAYLAND_SCANNER="$(HOST_DIR)/bin/wayland-scanner"
endef

define KBD_TOGGLE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/kbd-toggle $(TARGET_DIR)/usr/bin/kbd-toggle
endef

$(eval $(generic-package))