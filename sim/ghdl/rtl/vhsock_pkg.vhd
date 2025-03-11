library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vhsock_pkg is

    type c_string_t is array (natural range<>) of character;

    type std_ulogic_vector_ptr_t is access std_ulogic_vector;

    type vhsock_handle_t is record
        name : c_string_t(0 to 31);
        in_buffer_size : integer;
        in_buffer : std_ulogic_vector_ptr_t;
        out_buffer_size : integer;
        out_buffer : std_ulogic_vector_ptr_t;
    end record;

    type vhsock_handle_ptr_t is access vhsock_handle_t;

    impure function vhsock_create return vhsock_handle_ptr_t;
    attribute foreign of vhsock_create : function is "VHPIDIRECT vhsock_create";

    procedure vhsock_init(variable sock: vhsock_handle_t);
    attribute foreign of vhsock_init : procedure is "VHPIDIRECT vhsock_init";

    procedure vhsock_send(variable sock: vhsock_handle_t);
    attribute foreign of vhsock_send : procedure is "VHPIDIRECT vhsock_send";

    procedure vhsock_recv(variable sock: vhsock_handle_t);
    attribute foreign of vhsock_recv : procedure is "VHPIDIRECT vhsock_recv";

end package;

package body vhsock_pkg is
    impure function vhsock_create return vhsock_handle_ptr_t is
    begin
    end function;

    procedure vhsock_init(variable sock: vhsock_handle_t) is
    begin
    end procedure;

    procedure vhsock_send(variable sock: vhsock_handle_t) is
    begin
    end procedure;

    procedure vhsock_recv(variable sock: vhsock_handle_t) is
    begin
    end procedure;
end package body;
