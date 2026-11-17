#
# Copyright (C) 2008-2024 The LuCI Team
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-vnt2web
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=VirKing <https://github.com/virkingz>

LUCI_TITLE:=VNT2WEB - OpenWrt 上的 VNT 组网（Web 版）
LUCI_DESCRIPTION:=把 vnt2_web 核心封装成 OpenWrt 服务与 LuCI 界面：设置访问令牌与端口、托管核心进程、按架构在线更新核心、查看日志。组网的添加与启停由 vnt2_web 自带网页完成。
LUCI_DEPENDS:=+luci-base +rpcd +kmod-tun +unzip
LUCI_PKGARCH:=all

# 配置文件：opkg 升级时不覆盖用户改动
define Package/$(PKG_NAME)/conffiles
/etc/config/vnt2web
endef

# 重装/升级前先停服务，避免运行中的核心被替换后留下孤儿进程
define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/vnt2web stop  >/dev/null 2>&1
	/etc/init.d/vnt2web disable >/dev/null 2>&1
}
exit 0
endef

# 安装后确保脚本可执行（有些归档/Windows 打包会丢可执行位），并启用服务
define Package/$(PKG_NAME)/postinst
#!/bin/sh
chmod 0755 \
	"$${IPKG_INSTROOT}/etc/init.d/vnt2web" \
	"$${IPKG_INSTROOT}/etc/uci-defaults/95-vnt2web" \
	"$${IPKG_INSTROOT}/usr/libexec/rpcd/vnt2web" >/dev/null 2>&1
exit 0
endef

# 卸载时清理运行期数据（核心二进制与日志；配置由 conffiles 机制处理）
define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -f "$${IPKG_INSTROOT}/etc/init.d/vnt2web" ] || {
	rm -rf /etc/vnt2web /tmp/vnt2web
}
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
