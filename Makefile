#
# Copyright (C) 2015-2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=vmlinux-btf
PKG_VERSION:=$(LINUX_VERSION)
PKG_RELEASE:=6

include $(INCLUDE_DIR)/package.mk

PKG_BUILD_PARALLEL:=1

define Package/vmlinux-btf
  SECTION:=kernel
  CATEGORY:=Kernel
  TITLE:=Kernel vmlinux.btf for CO-RE compatibility
endef

define Package/vmlinux-btf/description
  Supplies kernel BTF information to ensure CO-RE eBPF compatibility.
  This package builds a shadow kernel tree using the OpenWrt kernel source,
  applies the same patches/files, and generates detached BTF information
  without modifying the main kernel build directory.
endef

define Package/vmlinux-btf/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	ln -sf /usr/lib/debug/boot/vmlinux /usr/lib/debug/boot/vmlinux-$$(uname -r)
fi
endef

define Package/vmlinux-btf/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	rm -f /usr/lib/debug/boot/vmlinux-$$(uname -r)
fi
endef

PAHOLE_JOBS := $(if $(filter -j%,$(PKG_JOBS)),$(patsubst -j%,%,$(filter -j%,$(PKG_JOBS))),1)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)

	$(TAR) -C $(PKG_BUILD_DIR) -xf $(DL_DIR)/$(LINUX_SOURCE)
	mv $(PKG_BUILD_DIR)/linux-$(LINUX_VERSION) $(PKG_BUILD_DIR)/shadow-kernel

	cp $(LINUX_DIR)/.config $(PKG_BUILD_DIR)/shadow-kernel/.config
endef

define Build/Compile
	$(PKG_BUILD_DIR)/shadow-kernel/scripts/config \
		--file $(PKG_BUILD_DIR)/shadow-kernel/.config \
		--disable WERROR \
		--enable KALLSYMS \
		--enable TRACEPOINTS \
		--enable DEBUG_KERNEL \
		--disable DEBUG_INFO_NONE \
		--disable DEBUG_INFO_REDUCED \
		--disable DEBUG_INFO_SPLIT \
		--enable DEBUG_INFO \
		--enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
		--enable DEBUG_INFO_BTF \
		--enable DEBUG_INFO_BTF_KFUNC \
		--enable PAHOLE_HAS_LANG_EXCLUDE \
		--enable BPF \
		--enable BPF_SYSCALL \
		--enable BPF_JIT \
		--enable BPF_JIT_DEFAULT_ON \
		--enable BPF_JIT_ALWAYS_ON \
		--enable BPF_STREAM_PARSER \
		--enable FTRACE \
		--enable KPROBES \
		--enable KRETPROBES \
		--enable KPROBE_EVENTS \
		--enable BPF_EVENTS \
		--enable NET_SCHED \
		--enable NET_INGRESS \
		--enable NET_EGRESS \
		--enable NET_SCH_INGRESS \
		--enable NET_SCH_FIFO \
		--enable NET_SCH_HTB \
		--enable NET_SCH_TBF \
		--enable NET_SCH_FQ \
		--enable NET_SCH_FQ_CODEL \
		--enable NET_SCH_CAKE \
		--enable NET_CLS \
		--enable NET_CLS_ACT \
		--enable NET_CLS_U32 \
		--enable NET_CLS_FLOWER \
		--enable NET_CLS_BPF \
		--enable NET_ACT_GACT \
		--enable NET_ACT_MIRRED \
		--enable NET_ACT_POLICE \
		--enable NET_ACT_BPF \
		--enable MACVLAN \
		--enable XDP_SOCKETS \
		--enable XDP_SOCKETS_DIAG \
		--set-str EXTRA_FIRMWARE "" \
		--set-str INITRAMFS_SOURCE ""

	$(MAKE) -C $(PKG_BUILD_DIR)/shadow-kernel \
		$(KERNEL_MAKE_FLAGS) \
		KBUILD_HOSTLDFLAGS="$(KBUILD_HOSTLDFLAGS) -lz" \
		olddefconfig

	$(MAKE) -C $(PKG_BUILD_DIR)/shadow-kernel \
		$(KERNEL_MAKE_FLAGS) \
		$(PKG_JOBS) \
		KBUILD_HOSTLDFLAGS="-L$(STAGING_DIR_HOST)/lib -lz" \
		vmlinux

	pahole \
		--jobs=$(PAHOLE_JOBS) \
		--btf_encode_detached=$(PKG_BUILD_DIR)/vmlinux-btf \
		$(PKG_BUILD_DIR)/shadow-kernel/vmlinux
endef

define Build/Clean
	rm -rf $(PKG_BUILD_DIR)
endef

define Package/vmlinux-btf/install
	$(INSTALL_DIR) $(1)/usr/lib/debug/boot
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/vmlinux-btf $(1)/usr/lib/debug/boot/vmlinux
	$(LN) vmlinux $(1)/usr/lib/debug/boot/vmlinux-$(LINUX_VERSION)
endef

$(eval $(call BuildPackage,vmlinux-btf))