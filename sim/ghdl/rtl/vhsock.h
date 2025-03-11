#include <stddef.h>

#define VHSOCK_NAME_MAXLEN 32

typedef struct {
    size_t size1;
    size_t size2;
    char data[];
} std_ulogic_vector;

typedef struct {
    // Visible to VHDL
    char name[VHSOCK_NAME_MAXLEN];
    int in_buffer_size;
    std_ulogic_vector* in_buffer;
    int out_buffer_size;
    std_ulogic_vector* out_buffer;
    // Not visible to VHDL
    int fd;
    int connected;
} vhsock_handle;

vhsock_handle* vhsock_create(void);
void vhsock_init(vhsock_handle* sock);
void vhsock_send(vhsock_handle* sock);
void vhsock_recv(vhsock_handle* sock);
