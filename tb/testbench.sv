    module ittm (
        input  wire [31:0] address,
        output wire [31:0] instruction
    );
        reg [31:0] memory [0:2];

        initial begin
            memory[0] = 32'h002081B3; // ADD x3,x1,x2
            memory[1] = 32'h40118233; // SUB x4,x3,x1
            memory[2] = 32'h004182B3; // ADD x5,x3,x4
        end
        assign instruction = memory[address >> 2];
    endmodule
    module test;
        reg clock = 0, rst = 1;
        hehe dut (.clock(clock), .rst(rst));
        always #5 clock = ~clock;
        task automatic taskName(arguments);
            
            
        endtask //automatic
        initial begin
            #20 rst = 0;
            #300 $finish;
        end        
    endmodule