#include <systemc.h>

#include "ghdl_module.hh"

struct sim_wrapper : public GHDLModule {
    sc_in<bool> i_eisV_clk;
    sc_in<bool> i_eisV_rst_n;
    sc_out<sc_bv<32>> o_imem_addr;
    sc_out<bool> o_imem_ren;
    sc_in<sc_bv<32>> i_imem_rdata;
    sc_out<sc_bv<32>> o_dmem_addr;
    sc_out<bool> o_dmem_ren;
    sc_in<sc_bv<32>> i_dmem_rdata;
    sc_out<bool> o_dmem_wen;
    sc_out<sc_bv<32>> o_dmem_wdata;
    sc_out<sc_bv<4>> o_dmem_byte_enable;
    sc_in<bool> i_external_interrupt_pending;
    sc_in<bool> i_timer_interrupt_pending;

   public:
    sim_wrapper(sc_module_name name, VHSocket vhsock) : GHDLModule(name, vhsock) {
        clk(i_eisV_clk);
    }

   protected:
    void copy_to_outbuffer(std::vector<uint8_t>& out_data) override;
    void copy_from_inbuffer(std::vector<uint8_t> const& in_data) override;
};
