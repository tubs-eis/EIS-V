--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: Type definitions used in the EISV internal interfaces
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_config.all;
use eisv.eisv_config_pkg.all;

package eisv_types_pkg is
    -- Configuration
    constant eisv_cfg : eisV_cfg_t := eisv_unpack_cfg_f(EISV_CONFIG_C);

    -- Special std_ulogic vectors
    type mem_addr_t is array (31 downto 0) of std_ulogic;
    type instr_word_t is array (31 downto 0) of std_ulogic;
    type word_t is array (31 downto 0) of std_ulogic;
    type mul_result_t is array (63 downto 0) of std_ulogic;
    type byte_flag_t is array (3 downto 0) of std_ulogic;
    type encoded_opcode_t is array (6 downto 0) of std_ulogic;
    type shamt_t is array (4 downto 0) of std_ulogic;
    type trap_code_t is array (5 downto 0) of std_ulogic;

    type rf_addr_t is array (4 downto 0) of std_ulogic;
    constant R0 : rf_addr_t := (others => '0');

    -- Strongly typed RISCV instructions
    type opcode_t is (
        OP_LOAD,      OP_STORE,    OP_MADD,    OP_BRANCH,
        OP_LOAD_FP,   OP_STORE_FP, OP_MSUB,    OP_JALR,
        OP_CUST_0,    OP_CUST_1,   OP_NMSUB,   OP_RESVD_0,
        OP_MISC_MEM,  OP_AMO,      OP_NMADD,   OP_JAL,
        OP_OP_IMM,    OP_OP,       OP_OP_FP,   OP_SYSTEM,
        OP_AUIPC,     OP_LUI,      OP_RESVD_1, OP_RESVD_2,
        OP_OP_IMM_32, OP_OP_32,    OP_CUST_2,  OP_CUST_3,
        OP_48B_0,     OP_64B,      OP_48B_1,   OP_GE_80B
    );

    type decoded_instruction_t is record
        valid : std_ulogic;
        opcode : std_ulogic_vector(6 downto 0);
        imm : word_t;
        rs1 : rf_addr_t;
        rs2 : rf_addr_t;
        rd : rf_addr_t;
        shamt : shamt_t;
        funct3 : std_ulogic_vector(2 downto 0);
        funct7 : std_ulogic_vector(6 downto 0);
    end record;

    -- CSR Related types
    type csr_implementation_t is (
        READ_ONLY_ZERO, SPECIAL, UNIMPLEMENTED
    );

    type special_csr_t is (
        MHARTID, MSTATUS, MISA, MIE, MTVEC, MSCRATCH, MEPC, MCAUSE, MTVAL, MIP
    );

    -- MUX select enums
    type rf_write_sel_t is (
        EXECUTION_UNIT, LOAD_STORE_UNIT, PC_PLUS_4, OPB
    );

    type logic_op_t is (
        '^', '|', '&', CLEAR
    );

    type eu_result_sel_t is (
        OP_A, ADDER, LOGIC, SHIFTER, CONDITION, MULTIPLIER, DIVIDER
    );

    type operand_a_sel_t is (
        REG, PC, ZERO, RS1
    );

    type operand_b_sel_t is (
        REG, IMM, CSR
    );

    type forward_sel_t is (
        REG, EX, MEM, WB
    );

    type jump_sel_t is (
        PC_OFFSET, EU_RESULT
    );

    type condition_t is (
        ALWAYS, ZERO, NOT_ZERO, CARRY, NOT_CARRY, LESS, NOT_LESS
    );

    type memory_width_t is (
        WORD, HALF, BYTE
    );

    type shift_mode_t is (
        LEFT, RIGHT_LOGICAL, RIGHT_ARITHMETIC
    );

    type mul_mode_t is (
        MUL, MULH, MULHSU, MULHU
    );

    type div_mode_t is (
        DIV, DIVU, REMS, REMU
    );

    type pipeline_mux_sel_t is (
        PROGRESS, HOLD, BUBBLE, FLUSH
    );

    -- Control signals
    type control_word_t is record
        valid : std_ulogic;
        rf_wp1_enable : std_ulogic;
        rf_wp2_enable : std_ulogic;
        rf_rp1_enable : std_ulogic;
        rf_rp2_enable : std_ulogic;
        eu_result_sel : eu_result_sel_t;
        eu_result_is_result : std_ulogic;
        rf_write_sel : rf_write_sel_t;
        operand_a_sel : operand_a_sel_t;
        operand_b_sel : operand_b_sel_t;
        addsub : std_ulogic;
        adder_set_lsb_zero : std_ulogic;
        logic_op : logic_op_t;
        shift_mode : shift_mode_t;
        mul_mode : mul_mode_t;
        div_mode : div_mode_t;
        condition : condition_t;
        jump : std_ulogic;
        jump_sel : jump_sel_t;
        memory_access : std_ulogic;
        memory_store : std_ulogic;
        memory_width : memory_width_t;
        memory_unsigned : std_ulogic;
        flush : std_ulogic;
        trap_return : std_ulogic;
        is_system : std_ulogic;
        is_csr : std_ulogic;
        csr_access : std_ulogic;
        csr_implementation : csr_implementation_t;
        special_csr : special_csr_t;
        special_csr_write : std_ulogic;
        ecall : std_ulogic;
        ebreak : std_ulogic;
    end record;

    constant CTRL_NOP : control_word_t := (
        valid => '0',
        rf_wp1_enable => '0',
        rf_wp2_enable => '0',
        rf_rp1_enable => '1',
        rf_rp2_enable => '1',
        eu_result_sel => ADDER,
        eu_result_is_result => '1',
        rf_write_sel => EXECUTION_UNIT,
        operand_a_sel => ZERO,
        operand_b_sel => IMM,
        addsub => '0',
        adder_set_lsb_zero => '0',
        logic_op => '^',
        shift_mode => LEFT,
        mul_mode => MUL,
        div_mode => DIV,
        condition => ALWAYS,
        jump => '0',
        jump_sel => PC_OFFSET,
        memory_access => '0',
        memory_store => '0',
        memory_width => BYTE,
        memory_unsigned => '0',
        flush => '0',
        trap_return => '0',
        is_system => '0',
        is_csr => '0',
        csr_access => '0',
        csr_implementation => UNIMPLEMENTED,
        special_csr => MEPC,
        special_csr_write => '0',
        ecall => '0',
        ebreak => '0'
    );

    type hazard_t is record
        operand_a_forward_sel : forward_sel_t;
        operand_b_forward_sel : forward_sel_t;
        stall : std_ulogic;
    end record;

    type trap_cause_t is (
        EXTERNAL_INTERRUPT,
        TIMER_INTERRUPT,
        INSTRUCTION_ADDRESS_MISALIGNED,
        ILLEGAL_INSTRUCTION,
        BREAKPOINT,
        LOAD_ADDRESS_MISALIGNED,
        STORE_ADDRESS_MISALIGNED,
        ENVIRONMNENT_CALL
    );

    -- Pipeline signals
    type if_pipeline_t is record
        pc : mem_addr_t;
    end record;

    type de_pipeline_t is record
        pc : mem_addr_t;
        pc_offset : mem_addr_t;
        imm : word_t;
        rs1 : rf_addr_t;
        rp1_addr : rf_addr_t;
        rp2_addr : rf_addr_t;
        rd : rf_addr_t;
    end record;

    type ex_pipeline_t is record
        pc : mem_addr_t;
        imm : word_t;
        rs1 : rf_addr_t;
        rd : rf_addr_t;
        rp2_rdata : word_t;
        operand_b : word_t;
        eu_result : word_t;
        condition : std_ulogic;
    end record;

    type mem_pipeline_t is record
        pc : mem_addr_t;
        rs1 : rf_addr_t;
        rd : rf_addr_t;
        rp2_rdata : word_t;
        operand_b : word_t;
        eu_result : word_t;
        condition : std_ulogic;
    end record;

end package;