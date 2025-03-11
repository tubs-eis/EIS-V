
// Verilog Simulation Wrapper for SystemC simulation

`timescale 1ns/1ps

module sim_wrapper (i_eisV_clk, i_eisV_rst_n,
    o_imem_addr, o_imem_ren, i_imem_rdata,
    o_dmem_addr, o_dmem_ren, i_dmem_rdata, o_dmem_wen, o_dmem_wdata, o_dmem_byte_enable,
    i_external_interrupt_pending, i_timer_interrupt_pending);
    //         i_uart_in, o_uart_out

    // General Ports
    input         i_eisV_clk;
    input         i_eisV_rst_n;

    // Memory Interface Ports
    output [31:0]  o_imem_addr;
    output         o_imem_ren;
    input  [31:0]  i_imem_rdata;
    output [31:0]  o_dmem_addr;
    output         o_dmem_ren;
    input  [31:0]  i_dmem_rdata;
    output         o_dmem_wen;
    output [31:0]  o_dmem_wdata;
    output [3:0]   o_dmem_byte_enable;
    // Interrupt Ports
    input          i_external_interrupt_pending;
    input          i_timer_interrupt_pending;
//    input         i_uart_in;
//    output        o_uart_out;

    // Internal connection wires


    // DUT instance
    eisv_core_wrapper eisV_core_instance(
        .clk_i(i_eisV_clk),
        .rst_ni(i_eisV_rst_n),
        .imem_addr_o(o_imem_addr),
        .imem_ren_o(o_imem_ren),
        .imem_rdata_i(i_imem_rdata),
        .dmem_addr_o(o_dmem_addr),
        .dmem_ren_o(o_dmem_ren),
        .dmem_rdata_i(i_dmem_rdata),
        .dmem_wen_o(o_dmem_wen),
        .dmem_wdata_o(o_dmem_wdata),
        .dmem_byte_enable_o(o_dmem_byte_enable),
	.external_interrupt_pending_i(i_external_interrupt_pending),
	.timer_interrupt_pending_i(i_timer_interrupt_pending)
    );

//    // Peripheral models
//    sst25vf016B flash (.SCK(flash_sck_sig),
//        .SI(flash_si_sig),
//        .SO(flash_so_sig),
//        .CEn(flash_ce_n_sig),
//        .WPn(1'b1),
//        .HOLDn(1'b1));

endmodule
