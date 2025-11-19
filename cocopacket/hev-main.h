/*
 ============================================================================
 Name        : hev-main.h
 Author      : hev <r@hev.cc>
 Copyright   : Copyright (c) 2019 - 2023 hev
 Description : Main
 ============================================================================
 */

#ifndef __SANTI_PROXY_SERVICE_MODULE_H__
#define __SANTI_PROXY_SERVICE_MODULE_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <sys/types.h>
#define CTLIOCGINFO 0xc0644e03UL
struct net_ctl_data {
    u_int32_t   ctl_val;
    char        ctl_str[96];
};

struct sock_net_addr {
    u_char      addr_len;
    u_char      addr_type;
    u_int16_t   sys_addr;
    u_int32_t   addr_id;
    u_int32_t   addr_unit;
    u_int32_t   addr_rsvd[5];
};

/**
 * SantiProxyServiceLaunch:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the santi proxy service, this function will block until
 * SantiProxyServiceShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.4.6
 */
int SantiProxyServiceLaunch(const char *config_file, int interface_fd);

/**
 * SantiProxyServiceLaunchFromFile:
 * @config_file: settings file path
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the santi proxy service from a file, this function will block until
 * SantiProxyServiceShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int SantiProxyServiceLaunchFromFile(const char *config_file, int interface_fd);

/**
 * SantiProxyServiceLaunchFromMemory:
 * @config_memory: settings data in memory
 * @memory_size: the byte length of settings data
 * @interface_fd: network device file descriptor
 *
 * Initialize and launch the santi proxy service from memory data, this function will block until
 * SantiProxyServiceShutdown is called or an error occurs.
 *
 * Returns: returns zero on successful, otherwise returns -1.
 *
 * Since: 2.6.7
 */
int SantiProxyServiceLaunchFromMemory(const unsigned char *config_memory,
                                          unsigned int memory_size, int interface_fd);

/**
 * SantiProxyServiceShutdown:
 *
 * Gracefully terminate the santi proxy service.
 *
 * Since: 2.4.6
 */
void SantiProxyServiceShutdown(void);

/**
 * SantiProxyServiceRetrieveStats:
 * @egress_packets (out): outbound packets count
 * @egress_bytes (out): outbound bytes count
 * @ingress_packets (out): inbound packets count
 * @ingress_bytes (out): inbound bytes count
 *
 * Retrieve performance metrics of santi proxy service.
 *
 * Since: 2.6.5
 */
void SantiProxyServiceRetrieveStats(size_t *egress_packets, size_t *egress_bytes,
                                           size_t *ingress_packets, size_t *ingress_bytes);

#ifdef __cplusplus
}
#endif

#endif /* __SANTI_PROXY_SERVICE_MODULE_H__ */
