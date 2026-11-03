include $(TOPDIR)/rules.mk

PKG_NAME:=xray-core
PKG_VERSION:=26.10.31
PKG_RELEASE:=1
PKG_SOURCE:=Xray-$(PKG_VERSION)-linux-arm64-v8a.zip
PKG_SOURCE_URL:=https://github.com/XTLS/Xray-core/releases/download/v$(PKG_VERSION)/
PKG_SOURCE_URL_FILE:=Xray-linux-arm64-v8a.zip
PKG_HASH:=1811c8f1da0c3b6dc707ebaf1c8390e987ba39859a8f0a7aadd8526157f2ec8d
PKG_LICENSE:=MPL-2.0
PKG_MAINTAINER:=Demogorgon314

include $(INCLUDE_DIR)/package.mk

define Package/xray-core
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Official Xray ARM64 binary for PassWall2
  URL:=https://github.com/XTLS/Xray-core
  DEPENDS:=@aarch64 +ca-bundle
endef

define Package/xray-core/description
  SHA-256 pinned official Xray release managed by PassWall2.
  Corresponding source: https://github.com/XTLS/Xray-core/tree/v$(PKG_VERSION)
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	unzip -q -o $(DL_DIR)/$(PKG_SOURCE) -d $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/xray-core/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/share/licenses/xray-core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/xray $(1)/usr/bin/xray
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/licenses/xray-core/LICENSE
endef

$(eval $(call BuildPackage,xray-core))
