# luci-app-vnt2web —— OpenWrt 上的 VNT 组网客户端（LuCI 插件）
#
# 用 OpenWrt SDK 或 buildroot 编译：
#   ./scripts/feeds update -a && ./scripts/feeds install -a
#   cp -a luci-app-vnt2web package/
#   make package/luci-app-vnt2web/compile V=s
#
# 不想搭 SDK 时用仓库里的 scripts/build-ipk.sh（免编译直接出包）。

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-vnt2web
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=VirKing <https://github.com/virkingz>
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-vnt2web
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=VNT 组网客户端
  URL:=https://github.com/virkingz/luci-app-vnt2web
  DEPENDS:=+luci-base +rpcd +kmod-tun +unzip
  PKGARCH:=all
endef

define Package/luci-app-vnt2web/description
  把 vnt-dev/vnt 的 vnt2_cli 核心封装成 OpenWrt 服务与 LuCI 界面。

  插件本身只做「壳」：设置组网参数、托管 vnt2_cli 进程、按架构在线下载与更新核心。
  组网的建立由 vnt2_cli 完成，无需在路由器上编译 VNT。

  支持以路由器为出口的异地互访（点对网）、端口映射，以及镜像/代理两种下载加速方式。
endef

define Build/Compile
endef

# 文件布局：
#   root/    -> 原样安装到设备根
#   htdocs/  -> /www（LuCI 静态资源）
define Package/luci-app-vnt2web/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/vnt2web $(1)/etc/init.d/vnt2web

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/vnt2web $(1)/etc/config/vnt2web

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/95-vnt2web $(1)/etc/uci-defaults/95-vnt2web

	$(INSTALL_DIR) $(1)/usr/share/vnt2web
	$(INSTALL_DATA) ./files/usr/share/vnt2web/vnt.sh $(1)/usr/share/vnt2web/vnt.sh
	$(INSTALL_DATA) ./files/usr/share/vnt2web/vnt-core.sh $(1)/usr/share/vnt2web/vnt-core.sh

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/usr/libexec/rpcd/vnt2web $(1)/usr/libexec/rpcd/vnt2web

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-vnt2web.json $(1)/usr/share/rpcd/acl.d/luci-app-vnt2web.json

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-app-vnt2web.json $(1)/usr/share/luci/menu.d/luci-app-vnt2web.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/vnt
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/vnt2web/client.js \
		$(1)/www/luci-static/resources/view/vnt2web/client.js
endef

# 卸载时清理运行期数据（核心二进制、日志）。配置由 conffiles 机制处理。
define Package/luci-app-vnt2web/postrm
#!/bin/sh
[ -f "$${IPKG_INSTROOT}/etc/init.d/vnt2web" ] || { rm -rf /etc/vnt2web /var/log/vnt2web; }
exit 0
endef

$(eval $(call BuildPackage,luci-app-vnt2web))
