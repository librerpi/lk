LOCAL_DIR := $(GET_LOCAL_DIR)

MODULE := $(LOCAL_DIR)

GLOBAL_INCLUDES += \
	$(LOCAL_DIR)/upstream/src/include \
	$(LOCAL_DIR)/upstream/src/include/posix \

MODULE_FLOAT_SRCS += \
	$(LOCAL_DIR)/cmd.c \

MODULE_SRCS += \
	$(LOCAL_DIR)/sys_arch.c \
	$(LOCAL_DIR)/netif.c \
	$(LOCAL_DIR)/upstream/src/api/api_lib.c \
	$(LOCAL_DIR)/upstream/src/api/api_msg.c \
	$(LOCAL_DIR)/upstream/src/api/err.c \
	$(LOCAL_DIR)/upstream/src/api/netbuf.c \
	$(LOCAL_DIR)/upstream/src/api/netifapi.c \
	$(LOCAL_DIR)/upstream/src/api/sockets.c \
	$(LOCAL_DIR)/upstream/src/api/tcpip.c \
	$(LOCAL_DIR)/upstream/src/core/def.c \
	$(LOCAL_DIR)/upstream/src/core/dns.c \
	$(LOCAL_DIR)/upstream/src/core/inet_chksum.c \
	$(LOCAL_DIR)/upstream/src/core/init.c \
	$(LOCAL_DIR)/upstream/src/core/ip.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/acd.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/dhcp.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/etharp.c \
	$(LOCAL_DIR)/upstream/src/core/mem.c \
	$(LOCAL_DIR)/upstream/src/core/memp.c \
	$(LOCAL_DIR)/upstream/src/core/netif.c \
	$(LOCAL_DIR)/upstream/src/core/pbuf.c \
	$(LOCAL_DIR)/upstream/src/core/raw.c \
	$(LOCAL_DIR)/upstream/src/core/stats.c \
	$(LOCAL_DIR)/upstream/src/core/sys.c \
	$(LOCAL_DIR)/upstream/src/core/tcp.c \
	$(LOCAL_DIR)/upstream/src/core/tcp_in.c \
	$(LOCAL_DIR)/upstream/src/core/tcp_out.c \
	$(LOCAL_DIR)/upstream/src/core/timeouts.c \
	$(LOCAL_DIR)/upstream/src/core/udp.c \
	$(LOCAL_DIR)/upstream/src/netif/ethernet.c \

LWIP_IP_TYPE := IPV4

ifeq ($(LWIP_IP_TYPE),IPV4)

GLOBAL_INCLUDES += \
	$(LOCAL_DIR)/include/ipv4 \

MODULE_SRCS += \
	$(LOCAL_DIR)/upstream/src/core/ipv4/autoip.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/icmp.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/igmp.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/ip4.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/ip4_addr.c \
	$(LOCAL_DIR)/upstream/src/core/ipv4/ip4_frag.c \

endif

ifeq ($(LWIP_APP_TFTP),1)
MODULE_SRCS += \
	$(LOCAL_DIR)/upstream/src/apps/tftp/tftp.c
endif

include make/module.mk

