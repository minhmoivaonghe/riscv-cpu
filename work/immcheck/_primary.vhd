library verilog;
use verilog.vl_types.all;
entity immcheck is
    port(
        instruction     : in     vl_logic_vector(31 downto 0);
        imm             : out    vl_logic_vector(31 downto 0);
        useimm          : out    vl_logic
    );
end immcheck;
