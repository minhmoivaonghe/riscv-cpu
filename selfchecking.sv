`timescale 1ns/1ps
module tb;
    reg clock = 0;
    reg rst = 1;
    reg [31:0] ittr [0:63];
    integer i = 0, n = 17, error = 0;
    reg [31:0] hihi;

    hehe dut(
        .clock(clock),
        .rst(rst)   
    );

    always #5 clock <= !clock;

    initial begin
            $readmemh("answers.txt", ittr);
            #12 rst <= 0;
    end

    always @(posedge clock) begin
        if  (dut.state === 2 && !rst) begin
            if (dut.alu_result == ittr[i]) begin
                $display("pass %d : %h", i, dut.alu_result );
            end
            else begin
                $display("fail %d : %h result : %h", i, dut.alu_result, ittr[i]);
                error = error + 1;
            end
            i = i + 1;
            hihi <= dut.regs[dut.rd];
            if (i == n) begin
                $display("test done with %d error", error);
                $finish;
            end
        end
        
    end
endmodule