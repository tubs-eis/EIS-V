#include "ghdl_module.hh"

static constexpr char STD_ULOGIC_CHAR[]{'U', 'X', '0', '1', 'Z', 'W', 'L', 'H', '-'};

VHSocket::VHSocket(std::string name, int in_buffer_size, int out_buffer_size)
    : in_buffer_size(in_buffer_size), out_buffer_size(out_buffer_size) {
    fd = socket(AF_UNIX, SOCK_SEQPACKET, 0);
    // Init addr with "\0" + name
    addr.sun_family = AF_UNIX;
    memset(addr.sun_path, '\0', 108);
    memcpy(&addr.sun_path[1], name.c_str(), name.length());
    addrlen = sizeof(sa_family_t) + 1 + name.length();

    int result;
    do {
        result = connect(fd, reinterpret_cast<sockaddr*>(&addr), addrlen);
    } while (result == -1 && errno == ECONNREFUSED);
    errno = 0;
}

void VHSocket::vhsend(std::vector<uint8_t> const& out_data) {
    assert(out_data.size() == out_buffer_size);

    int result = send(fd, out_data.data(), out_buffer_size, 0);
    if (result == -1) {
        perror("send");
        exit(0);
    }
}

void VHSocket::vhrecv(std::vector<uint8_t>& in_data) {
    assert(in_data.size() == in_buffer_size);
    int result = recv(fd, in_data.data(), in_buffer_size, 0);

    if (result == -1) {
        perror("recv");
        exit(0);
    }
}

int VHSocket::get_out_buffer_size() {
    return out_buffer_size;
}

int VHSocket::get_in_buffer_size() {
    return in_buffer_size;
}

void GHDLModule::vhsock_thread() {
    std::vector<uint8_t> out_buffer(vhsock.get_out_buffer_size());
    std::vector<uint8_t> in_buffer(vhsock.get_in_buffer_size());
    while (1) {
        wait(clk.posedge_event());
        wait(1, SC_PS);
        copy_to_outbuffer(out_buffer);
        vhsock.vhsend(out_buffer);
        vhsock.vhrecv(in_buffer);
        copy_from_inbuffer(in_buffer);
    }
}
