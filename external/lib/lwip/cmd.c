/*
 * Copyright (c) 2013 Corey Tabaka
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files
 * (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <lk/console_cmd.h>

#include <kernel/event.h>
#include <lwip/api.h>
#include <lwip/apps/tftp_client.h>
#include <lwip/ip_addr.h>
#include <stdio.h>
#include <string.h>
#include <platform/time.h>

typedef struct {
  event_t done;
  bool failure;
  uint32_t bytes_received;
} get_state_t;

static int tftp_accept_write(void *handle, struct pbuf *p) {
  get_state_t *s = (get_state_t*)handle;
  //printf("%p got %d bytes from tftp\n", handle, p->tot_len);
  s->bytes_received += p->tot_len;
  return ERR_OK;
}

static void tftp_close(void *handle) {
  printf("%p close\n", handle);
  get_state_t *s = (get_state_t*)handle;
  s->failure = false;
  event_signal(&s->done, true);
}

static void tftp_err(void* handle, int err, const char* msg, int size) {
  get_state_t *s = (get_state_t*)handle;
  s->failure = true;
  event_signal(&s->done, true);
}

static int net_cmd(int argc, const console_cmd_args *argv) {
  if (argc < 2) {
    printf("%s commands:\n", argv[0].str);
usage:
    printf("%s lookup <hostname>\n", argv[0].str);
    printf("%s tftp get <host> <path>\n", argv[0].str);
    goto out;
  }

  if (!strcmp(argv[1].str, "lookup")) {
#if LWIP_DNS
    if (argc < 3) goto usage;

    ip_addr_t ip_addr;
    const char *hostname = argv[2].str;
    err_t err;

    err = netconn_gethostbyname(hostname, &ip_addr);
    if (err != ERR_OK) {
      printf("Failed to resolve host: %d\n", err);
    } else {
      printf("%s: %u.%u.%u.%u\n", hostname,
                        ip4_addr1_16(&ip_addr),
                        ip4_addr2_16(&ip_addr),
                        ip4_addr3_16(&ip_addr),
                        ip4_addr4_16(&ip_addr));
    }
#else
    puts("error, LWIP built without DNS support");
#endif
  } else if (strcmp(argv[1].str, "tftp") == 0) {
    if (argc < 5) goto usage;
    printf("%sting %s %s\n", argv[2].str, argv[3].str, argv[4].str);
    if (strcmp(argv[2].str, "get") == 0) {
      struct tftp_context ctx = {
        .write = tftp_accept_write,
        .close = tftp_close,
        .error = tftp_err,
      };
      err_t status = tftp_init_client(&ctx);
      printf("status %d\n", status);
      get_state_t handle = {
        .done = EVENT_INITIAL_VALUE(handle.done, false, 0),
        .bytes_received = 0,
      };
      ip_addr_t hostip;
      if (ipaddr_aton(argv[3].str, &hostip) != 1) {
        puts("error parsing IP");
        return 0;
      }
      uint64_t start = current_time_hires();
      printf("handle at %p\n", &handle);
      status = tftp_get(&handle, &hostip, 69, argv[4].str, TFTP_MODE_OCTET);
      printf("status %d\n", status);
      event_wait(&handle.done);
      uint64_t stop = current_time_hires();
      tftp_cleanup();
      event_destroy(&handle.done);
      double delta = (double)(stop - start) / 1000 / 1000;
      printf("%d bytes received in %f Sec\n", handle.bytes_received, delta);
      printf("bytes/sec %f\n", (double)handle.bytes_received / delta);
    }
  }

out:
  return 0;
}

STATIC_COMMAND_START
STATIC_COMMAND("net", "net toolbox", &net_cmd)
STATIC_COMMAND_END(net);

