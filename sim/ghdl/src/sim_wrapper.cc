#include "sim_wrapper.hh"

static constexpr uint8_t STD_ULOGIC_0 = 2;
static constexpr uint8_t STD_ULOGIC_1 = 3;

static constexpr char STD_ULOGIC_CHAR[]{'U', 'X', '0', '1', 'Z', 'W', 'L', 'H', '-'};

static bool ulogic_to_bit(uint8_t ulogic) {
    if (ulogic == STD_ULOGIC_0) {
        return false;
    } else if (ulogic == STD_ULOGIC_1) {
        return true;
    } else {
        printf("WARN: Converting '%c' to '0'\n", STD_ULOGIC_CHAR[ulogic]);
        return false;
    }
}

static uint8_t bit_to_ulogic(bool bit) {
    if (bit) {
        return STD_ULOGIC_1;
    } else {
        return STD_ULOGIC_0;
    }
}

template <int n>
static int copy_from_ghdl(uint8_t const* src, sc_bv<n>& dst) {
    for (int i = n - 1; i >= 0; i--) {
        dst[i] = ulogic_to_bit(*src);
        src++;
    }
    return n;
}

static int copy_from_ghdl(uint8_t const* src, bool& dst) {
    dst = ulogic_to_bit(*src);
    return 1;
}

template <int n>
static int copy_to_ghdl(sc_bv<n> const& src, uint8_t* dst) {
    for (int i = n - 1; i >= 0; i--) {
        *dst = bit_to_ulogic(bool(src[i]));
        dst++;
    }
    return n;
}

static int copy_to_ghdl(bool const& src, uint8_t* dst) {
    *dst = bit_to_ulogic(src);
    return 1;
}

void sim_wrapper::copy_to_outbuffer(std::vector<uint8_t>& out_data) {
    uint8_t* out_ptr = out_data.data();
    int written;

    written = copy_to_ghdl(i_eisV_rst_n.read(), out_ptr);
    out_ptr += written;

    written = copy_to_ghdl(i_imem_rdata.read(), out_ptr);
    out_ptr += written;

    written = copy_to_ghdl(i_dmem_rdata.read(), out_ptr);
    out_ptr += written;

    written = copy_to_ghdl(i_external_interrupt_pending.read(), out_ptr);
    out_ptr += written;

    written = copy_to_ghdl(i_timer_interrupt_pending.read(), out_ptr);
    out_ptr += written;
}

void sim_wrapper::copy_from_inbuffer(std::vector<uint8_t> const& in_data) {
    uint8_t const* in_ptr = in_data.data();
    int read;

#define READ_TO_OUT(port)                      \
    decltype(port)::data_type port##_buf;      \
    read = copy_from_ghdl(in_ptr, port##_buf); \
    in_ptr += read;                            \
    port.write(port##_buf);

    READ_TO_OUT(o_imem_addr)
    READ_TO_OUT(o_imem_ren)
    READ_TO_OUT(o_dmem_addr)
    READ_TO_OUT(o_dmem_ren)
    READ_TO_OUT(o_dmem_wen)
    READ_TO_OUT(o_dmem_wdata)
    READ_TO_OUT(o_dmem_byte_enable)
}
