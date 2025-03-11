#include "vhsock.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>

static char STD_ULOGIC_CHAR[] = {'U', 'X', '0', '1', 'Z', 'W', 'L', 'H', '-'};

vhsock_handle* vhsock_create() {
    printf("Creating empty vhsock handle\n");

    vhsock_handle* sock = malloc(sizeof(vhsock_handle));
    memset(&sock->name, 0, VHSOCK_NAME_MAXLEN);
    sock->in_buffer_size = 0;
    sock->in_buffer = NULL;
    sock->out_buffer_size = 0;
    sock->out_buffer = NULL;
    sock->fd = 0;
    sock->connected = 0;

    return sock;
}

void vhsock_init(vhsock_handle* sock) {
    printf("Initializing Socket: %s, %d, %p, %d, %p\n", sock->name, sock->in_buffer_size,
           sock->in_buffer, sock->out_buffer_size, sock->out_buffer);

    sock->fd = socket(AF_UNIX, SOCK_SEQPACKET, 0);

    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    memset(addr.sun_path, '\0', 108);
    memcpy(&addr.sun_path[1], &sock->name, VHSOCK_NAME_MAXLEN);

    socklen_t addrlen = sizeof(sa_family_t) + 1 + strlen(&addr.sun_path[1]);
    bind(sock->fd, (struct sockaddr*)&addr, addrlen);

    listen(sock->fd, 1);

    sock->fd = accept(sock->fd, (struct sockaddr*)&addr, &addrlen);

    printf("Connected %s\n", addr.sun_path + 1);
}

void vhsock_send(vhsock_handle* sock) {
    int result = send(sock->fd, sock->out_buffer->data, sock->out_buffer_size, 0);
    if (result == -1) {
        perror("send");
        exit(0);
    }
}

void vhsock_recv(vhsock_handle* sock) {
    int result = recv(sock->fd, sock->in_buffer->data, sock->in_buffer_size, 0);
    if (result == -1) {
        perror("send");
        exit(0);
    }
}