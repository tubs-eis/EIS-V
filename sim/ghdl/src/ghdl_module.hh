#include <sys/socket.h>
#include <sys/un.h>
#include <systemc.h>

class VHSocket {
   public:
    VHSocket(std::string name, int in_buffer_size, int out_buffer_size);

    void vhsend(std::vector<uint8_t> const& out_data);
    void vhrecv(std::vector<uint8_t>& in_data);

    int get_out_buffer_size();
    int get_in_buffer_size();

   private:
    int fd;
    int addrlen;
    sockaddr_un addr;
    int in_buffer_size;
    int out_buffer_size;
};

struct GHDLModule : public sc_module {
    SC_HAS_PROCESS(GHDLModule);

   public:
    sc_in<bool> clk;
    GHDLModule(sc_module_name name, VHSocket vhsock) : vhsock(vhsock) {
        SC_THREAD(vhsock_thread);
    }

   protected:
    virtual void copy_to_outbuffer(std::vector<uint8_t>& out_data) = 0;
    virtual void copy_from_inbuffer(std::vector<uint8_t> const& in_data) = 0;

   private:
    VHSocket vhsock;

    void vhsock_thread();
};