--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: EISV Core top level module
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_core is
    generic (
        HART_ID : integer := 0
    );
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- Instruction Memory Interface
        imem_addr_o : out mem_addr_t;
        imem_ren_o : out std_ulogic;
        imem_rdata_i : in word_t;
        -- Data Memory Interface
        dmem_addr_o : out mem_addr_t;
        dmem_ren_o : out std_ulogic;
        dmem_rdata_i : in word_t;
        dmem_wen_o : out std_ulogic;
        dmem_wdata_o : out word_t;
        dmem_byte_enable_o : out byte_flag_t;
        -- System Interface
        external_interrupt_pending_i : in std_ulogic;
        timer_interrupt_pending_i : in std_ulogic
    );
end entity;

architecture rtl of eisv_core is

    signal instr_rdata_ff, instr_rdata_nxt : word_t;

    signal if_fetch_valid_nxt, if_fetch_valid_ff : std_ulogic;
    signal if_bubble : std_ulogic;
    signal if_instr_rdata : word_t;
    signal if_pc : mem_addr_t;
    signal if_pipeline_out : if_pipeline_t;
    signal if_pipeline_reg : if_pipeline_t;
    signal if_hold_pc : std_ulogic;
    signal if_jump_addr : mem_addr_t;
    signal if_pipeline_mux_sel : pipeline_mux_sel_t;
    signal if_valid : std_ulogic;

    signal de_ctrl_out : control_word_t;
    signal de_pipeline_out : de_pipeline_t;
    signal de_pipeline_reg : de_pipeline_t;
    signal de_pipeline_mux_sel : pipeline_mux_sel_t;

    signal ex_jump_pc : mem_addr_t;
    signal ex_ctrl : control_word_t;
    signal ex_pipeline_out : ex_pipeline_t;
    signal ex_pipeline_reg : ex_pipeline_t;
    signal ex_pipeline_mux_sel : pipeline_mux_sel_t;
    signal ex_special_csr_value : word_t;

    signal mem_ctrl : control_word_t;
    signal mem_pipeline_out : mem_pipeline_t;
    signal mem_pipeline_reg : mem_pipeline_t;
    signal mem_pipeline_mux_sel : pipeline_mux_sel_t;
    signal mem_misaligned : std_ulogic;

    signal wb_mem_rdata : word_t;
    signal wb_wp1_data : word_t;
    signal wb_wp2_data : word_t;
    signal wb_ctrl : control_word_t;

    signal hazard_out : hazard_t;
    signal hazard_reg : hazard_t;
    signal if_bubble_reg : std_ulogic;

    signal reg_bypass_reg : word_t;
    signal rp1_rdata : word_t;
    signal rp2_rdata : word_t;
    signal rp1_forward : word_t;
    signal rp2_forward : word_t;

    signal controller_flushing : std_ulogic;
    signal controller_flushed : std_ulogic;
    signal controller_trap : std_ulogic;
    signal controller_trap_return : std_ulogic;
    signal controller_trap_cause_in : trap_cause_t;
    signal controller_trap_cause_out : trap_cause_t;
    signal controller_jump_trap_handler : std_ulogic;
    signal controller_jump_trap_return : std_ulogic;

    signal epc : mem_addr_t;
    signal mtvec : mem_addr_t;
    signal mstatus_mie : std_ulogic;
    signal mie_mtie, mie_meie : std_ulogic;

    signal pipeline_control_write_epc : std_ulogic;
    signal pipeline_control_write_epc_value : mem_addr_t;
    signal pipeline_control_write_mtval : std_ulogic;
    signal pipeline_control_write_mtval_value : mem_addr_t;
    signal pipeline_control_interrupt_stack_push : std_ulogic;

begin

    -- Shared components
    register_file_inst: entity eisv.eisv_register_file
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        rp1_addr_i => de_pipeline_out.rp1_addr,
        rp1_enable_i => '1',
        rp1_data_o => rp1_rdata,
        rp2_addr_i => de_pipeline_out.rp2_addr,
        rp2_enable_i => '1',
        rp2_data_o => rp2_rdata,
        wp1_addr_i => mem_pipeline_reg.rd,
        wp1_enable_i => wb_ctrl.rf_wp1_enable,
        wp1_data_i => wb_wp1_data,
        wp2_addr_i => (others => '0'),
        wp2_enable_i => '0',
        wp2_data_i => (others => '0')
    );

    csrs_inst: entity eisv.eisv_csrs
     generic map (
        HART_ID => HART_ID
     )
     port map (
        clk_i => clk_i,
        rst_ni => rst_ni,
        read_sel_i => ex_ctrl.special_csr,
        read_data_o => ex_special_csr_value,
        write_enable_i => wb_ctrl.special_csr_write,
        write_sel_i => wb_ctrl.special_csr,
        write_data_i => mem_pipeline_reg.eu_result,
        external_interrupt_pending_i => external_interrupt_pending_i,
        timer_interrupt_pending_i => timer_interrupt_pending_i,
        interrupt_stack_push_i => pipeline_control_interrupt_stack_push,
        write_epc_i => pipeline_control_write_epc,
        write_epc_value_i => pipeline_control_write_epc_value,
        write_mtval_i => pipeline_control_write_mtval,
        write_mtval_value_i => pipeline_control_write_mtval_value,
        epc_o => epc,
        mtvec_o => mtvec,
        mstatus_mie_o => mstatus_mie,
        mie_mtie_o => mie_mtie,
        mie_meie_o => mie_meie,
        trap_enter_i => controller_jump_trap_handler,
        trap_leave_i => controller_jump_trap_return,
        trap_cause_i => controller_trap_cause_out
     );

    controller_inst: entity eisv.eisv_controller
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        trap_i => controller_trap,
        trap_return_i => controller_trap_return,
        trap_cause_i => controller_trap_cause_in,
        flushed_i => controller_flushed,
        flushing_o => controller_flushing,
        jump_trap_handler_o => controller_jump_trap_handler,
        jump_trap_return_o => controller_jump_trap_return,
        trap_cause_o => controller_trap_cause_out
    );

    load_store_unit_inst: entity eisv.eisv_load_store_unit
     port map(
       clk_i => clk_i,
       rst_ni => rst_ni,
       data_addr_o => dmem_addr_o,
       data_ren_o => dmem_ren_o,
       data_rdata_i => dmem_rdata_i,
       data_wen_o => dmem_wen_o,
       data_wdata_o => dmem_wdata_o,
       data_byte_enable_o => dmem_byte_enable_o,
       acc_enable_i => mem_ctrl.memory_access,
       acc_store_i => mem_ctrl.memory_store,
       acc_address_i => mem_addr_t(ex_pipeline_reg.eu_result),
       acc_width_i => mem_ctrl.memory_width,
       acc_data_i => ex_pipeline_reg.rp2_rdata,
       acc_misaligned_o => mem_misaligned,
       res_enable_i => wb_ctrl.memory_access and not wb_ctrl.memory_store,
       res_width_i => wb_ctrl.memory_width,
       res_byte_addr_i => std_ulogic_vector(mem_pipeline_reg.eu_result(1 downto 0)),
       res_is_unsigned => wb_ctrl.memory_unsigned,
       res_data_o => wb_mem_rdata
    );


    -- Pipeline control logic
    pipeline_control : process (all) is
    begin
        pipeline_control_write_epc <= '0';
        pipeline_control_write_epc_value <= (others => '0');
        pipeline_control_write_mtval <= '0';
        pipeline_control_write_mtval_value <= (others => '0');
        pipeline_control_interrupt_stack_push <= '0';

        controller_trap <= '0';
        controller_trap_return <= '0';
        controller_trap_cause_in <= ILLEGAL_INSTRUCTION;

        if_pipeline_mux_sel <= PROGRESS;
        de_pipeline_mux_sel <= PROGRESS;
        ex_pipeline_mux_sel <= PROGRESS;
        mem_pipeline_mux_sel <= PROGRESS;

        -- IF stage stall
        if hazard_out.stall then
            de_pipeline_mux_sel <= BUBBLE;
            if_pipeline_mux_sel <= HOLD;
        end if;

        -- IF branch delay
        if not if_fetch_valid_ff or de_ctrl_out.jump then
            if_pipeline_mux_sel <= HOLD;
        end if;

        -- DE illegal instruction
        if if_valid and not de_ctrl_out.valid then
            controller_trap <= '1';
            controller_trap_cause_in <= ILLEGAL_INSTRUCTION;
            pipeline_control_write_epc <= '1';
            pipeline_control_write_epc_value <= de_pipeline_out.pc;

            de_pipeline_mux_sel <= FLUSH;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        -- DE environment_call
        if de_ctrl_out.ecall then
            controller_trap <= '1';
            controller_trap_cause_in <= ENVIRONMNENT_CALL;
            pipeline_control_write_epc <= '1';
            pipeline_control_write_epc_value <= de_pipeline_out.pc;

            de_pipeline_mux_sel <= FLUSH;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        -- DE breakpoint
        if de_ctrl_out.ebreak then
            controller_trap <= '1';
            controller_trap_cause_in <= BREAKPOINT;
            pipeline_control_write_epc <= '1';
            pipeline_control_write_epc_value <= de_pipeline_out.pc;
            pipeline_control_write_mtval <= '1';
            pipeline_control_write_mtval_value <= de_pipeline_out.pc;

            de_pipeline_mux_sel <= FLUSH;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        -- DE trap return
        if de_ctrl_out.trap_return then
            controller_trap_return <= '1';

            de_pipeline_mux_sel <= FLUSH;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        -- EX instruction_address_misaligned
        if ex_ctrl.jump and (ex_jump_pc(1) or ex_jump_pc(0)) then
            controller_trap <= '1';
            controller_trap_cause_in <= INSTRUCTION_ADDRESS_MISALIGNED;
            pipeline_control_write_epc <= '1';
            pipeline_control_write_epc_value <= ex_pipeline_out.pc;
            pipeline_control_write_mtval <= '1';
            pipeline_control_write_mtval_value <= ex_jump_pc;

            ex_pipeline_mux_sel <= FLUSH;
            de_pipeline_mux_sel <= BUBBLE;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        -- MEM address misaligned
        if mem_misaligned then
            controller_trap <= '1';
            case to_bit(mem_ctrl.memory_store) is
                when '0' => controller_trap_cause_in <= LOAD_ADDRESS_MISALIGNED;
                when '1' => controller_trap_cause_in <= STORE_ADDRESS_MISALIGNED;
            end case;

            pipeline_control_write_epc <= '1';
            pipeline_control_write_epc_value <= mem_pipeline_out.pc;
            pipeline_control_write_mtval <= '1';
            pipeline_control_write_mtval_value <= mem_addr_t(ex_pipeline_reg.eu_result);

            mem_pipeline_mux_sel <= FLUSH;
            ex_pipeline_mux_sel <= BUBBLE;
            de_pipeline_mux_sel <= BUBBLE;
            if_pipeline_mux_sel <= BUBBLE;
        end if;

        if mstatus_mie and ex_ctrl.valid then
            if mie_mtie and timer_interrupt_pending_i then
                controller_trap <= '1';
                controller_trap_cause_in <= TIMER_INTERRUPT;

                pipeline_control_write_epc <= '1';
                pipeline_control_write_epc_value <= ex_pipeline_out.pc;
                pipeline_control_write_mtval <= '0';

                pipeline_control_interrupt_stack_push <= '1';

                ex_pipeline_mux_sel <= FLUSH;
                de_pipeline_mux_sel <= BUBBLE;
                if_pipeline_mux_sel <= BUBBLE;
            end if;

            if mie_meie and external_interrupt_pending_i then
                controller_trap <= '1';
                controller_trap_cause_in <= EXTERNAL_INTERRUPT;

                pipeline_control_write_epc <= '1';
                pipeline_control_write_epc_value <= ex_pipeline_out.pc;
                pipeline_control_write_mtval <= '0';

                pipeline_control_interrupt_stack_push <= '1';

                ex_pipeline_mux_sel <= FLUSH;
                de_pipeline_mux_sel <= BUBBLE;
                if_pipeline_mux_sel <= BUBBLE;
            end if;
        end if;

        if controller_flushing then
            if_pipeline_mux_sel <= BUBBLE;
        end if;
    end process;

    controller_flushed <= wb_ctrl.flush;

    -- Stage 0 (PC)
    s0 : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_ni then
                instr_rdata_ff <= instr_rdata_nxt;
                if_fetch_valid_ff <= if_fetch_valid_nxt;
                if_pipeline_reg <= if_pipeline_out;
            else
                if_fetch_valid_ff <= '0';
                if_pipeline_reg.pc <= (others => '0');
            end if;
        end if;
    end process;

    if_stage_inst : entity eisv.eisv_if_stage
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        instr_addr_o => imem_addr_o,
        instr_ren_o => imem_ren_o,
        hold_pc_i => if_hold_pc,
        jump_en_i => ex_ctrl.jump or controller_jump_trap_handler or controller_jump_trap_return,
        condition_i => ex_pipeline_out.condition,
        jump_addr_i => if_jump_addr,
        pipeline_i => if_pipeline_reg,
        pipeline_o => if_pipeline_out
    );

    if_jump_addr <= mtvec when controller_jump_trap_handler else
                    epc when controller_jump_trap_return
                    else ex_jump_pc;
    if_fetch_valid_nxt <= not de_ctrl_out.jump or hazard_out.stall;
    if_bubble <= '1' when if_pipeline_mux_sel = BUBBLE or if_pipeline_mux_sel = FLUSH else '0';
    if_hold_pc <= '1' when (??if_bubble) or if_pipeline_mux_sel = HOLD else '0';

    -- Stage 1
    s1 : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_ni then
                case de_pipeline_mux_sel is
                    when PROGRESS => ex_ctrl <= de_ctrl_out;
                    when HOLD => ex_ctrl <= ex_ctrl;
                    when BUBBLE | FLUSH => ex_ctrl <= CTRL_NOP;
                end case;

                if de_pipeline_mux_sel = FLUSH then
                    ex_ctrl.flush <= '1';
                end if;

                hazard_reg <= hazard_out;
                if_bubble_reg <= if_bubble;
                reg_bypass_reg <= wb_wp1_data;

                de_pipeline_reg <= de_pipeline_out;
            else
                ex_ctrl <= CTRL_NOP;
            end if;
        end if;
    end process;

    instr_rdata_nxt <= instr_rdata_ff when hazard_reg.stall else imem_rdata_i;
    if_instr_rdata <= instr_rdata_ff when hazard_reg.stall else imem_rdata_i;
    if_pc <= de_pipeline_reg.pc when hazard_reg.stall else if_pipeline_reg.pc;
    if_valid <= if_fetch_valid_ff and not if_bubble_reg;

    de_stage_inst : entity eisv.eisv_de_stage
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        pipeline_i => if_pipeline_reg,
        pc_i => if_pc,
        instr_rdata_i => if_instr_rdata,
        instr_valid_i => if_valid,
        pipeline_o => de_pipeline_out,
        ctrl_o => de_ctrl_out
    );

    hazard_unit_inst: entity eisv.eisv_hazard_unit
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        de_ctrl_out_i => de_ctrl_out,
        de_pipeline_out_i => de_pipeline_out,
        de_pipeline_reg_i => de_pipeline_reg,
        ex_ctrl_i => ex_ctrl,
        ex_pipeline_reg_i => ex_pipeline_reg,
        mem_ctrl_i => mem_ctrl,
        mem_pipeline_reg_i => mem_pipeline_reg,
        wb_ctrl_i => wb_ctrl,
        hazard_o => hazard_out
    );

    -- Stage 2
    s2 : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_ni then
                case ex_pipeline_mux_sel is
                    when PROGRESS => mem_ctrl <= ex_ctrl;
                    when HOLD => mem_ctrl <= mem_ctrl;
                    when BUBBLE | FLUSH => mem_ctrl <= CTRL_NOP;
                end case;

                if ex_pipeline_mux_sel = FLUSH then
                    mem_ctrl.flush <= '1';
                end if;

                ex_pipeline_reg <= ex_pipeline_out;
            else
                mem_ctrl <= CTRL_NOP;
            end if;
        end if;
    end process;

    forward : process (all) is
    begin
        case hazard_reg.operand_a_forward_sel is
            when REG => rp1_forward <= rp1_rdata;
            when EX => rp1_forward <= ex_pipeline_reg.eu_result;
            when MEM => rp1_forward <= wb_wp1_data;
            when WB => rp1_forward <= reg_bypass_reg;
        end case;

        case hazard_reg.operand_b_forward_sel is
            when REG => rp2_forward <= rp2_rdata;
            when EX => rp2_forward <= ex_pipeline_reg.eu_result;
            when MEM => rp2_forward <= wb_wp1_data;
            when WB => rp2_forward <= reg_bypass_reg;
        end case;
    end process;

    jump_select : process (all) is
    begin
        case ex_ctrl.jump_sel is
            when PC_OFFSET => ex_jump_pc <= de_pipeline_reg.pc_offset;
            when EU_RESULT => ex_jump_pc <= mem_addr_t(ex_pipeline_out.eu_result);
        end case;
    end process;

    ex_stage_inst: entity eisv.eisv_ex_stage
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        ctrl_i => ex_ctrl,
        pipeline_i => de_pipeline_reg,
        special_csr_value_i => ex_special_csr_value,
        rp1_forward_i => rp1_forward,
        rp2_forward_i => rp2_forward,
        pipeline_o => ex_pipeline_out
    );

    -- Stage 3
    s3 : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_ni then
                case mem_pipeline_mux_sel is
                    when PROGRESS => wb_ctrl <= mem_ctrl;
                    when HOLD => wb_ctrl <= wb_ctrl;
                    when BUBBLE | FLUSH => wb_ctrl <= CTRL_NOP;
                end case;

                if mem_pipeline_mux_sel = FLUSH then
                    wb_ctrl.flush <= '1';
                end if;

                mem_pipeline_reg <= mem_pipeline_out;
            else
                wb_ctrl <= CTRL_NOP;
            end if;
        end if;
    end process;

    mem_stage_inst : entity eisv.eisv_mem_stage
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        ctrl_i => mem_ctrl,
        pipeline_i => ex_pipeline_reg,
        pipeline_o => mem_pipeline_out
    );

    -- Stage 4
    rf_write : process (all) is
    begin
        case wb_ctrl.rf_write_sel is
            when EXECUTION_UNIT =>
                wb_wp1_data <= mem_pipeline_reg.eu_result;
            when LOAD_STORE_UNIT =>
                wb_wp1_data <= wb_mem_rdata;
            when PC_PLUS_4 =>
                wb_wp1_data <= word_t(unsigned(mem_pipeline_reg.pc) + 4);
            when OPB =>
                wb_wp1_data <= mem_pipeline_reg.operand_b;
        end case;

        wb_wp2_data <= mem_pipeline_reg.eu_result;
    end process;

end architecture;