`timescale 1ns/1ps
module tb;
    reg clock = 0;
    reg rst = 1;
    reg [31:0] ittr [0:63];
    reg [31:0] pcvalue[0:63];
    reg [4:0] hehe;
    reg [31:0] hihi;

    integer i = 0, n = 0, error = 0, j = 0 , i1;

    hehe dut(
        .clock(clock),
        .rst(rst)   
    );

    always #5 clock <= !clock;

    initial begin
            $readmemh("data/load_s_type_test/test2/answers.txt", ittr);
            $readmemh("data/load_s_type_test/test2/exp_pc.txt", pcvalue);
            #12 rst <= 0;
            for (i1 = 0; i1 < $size(pcvalue); i1 = i1 + 1)
                if ((^pcvalue[i1]) !== 1'bx)
                    n = n + 1;
    end

reg check_en;
reg [31:0] wb_data_captured;   
reg check_value;


    always @(posedge clock) begin
        if (rst) begin
            check_en <= 0;
            i = 0;
        end
        else begin
            if  (dut.state === 3) begin
                if (dut.wb_data === ittr[j] || dut.is_branch || dut.rd === 0 || dut.is_stype && dut.pc === pcvalue[i]) begin
                    $display("pass %d WB : %h  %d  PC : %h ", j, dut.wb_data, i,  dut.pc );
                end
                else begin
                    if (dut.pc != pcvalue[i] && dut.rd != 0 && !dut.is_stype) begin
                        $display("fail PC %d : %h result : %h", i, dut.pc, pcvalue[i]);
                        error = error + 1;
                    end
                    if (dut.wb_data != ittr[j] && !dut.is_branch) begin
                        $display("fail WB %d : %h result : %h", j, dut.wb_data, ittr[j]);
                        error = error + 1;
                    end
                end
                if (!dut.is_branch && !dut.is_stype ) j = j + 1;
                i = i + 1;
                if (i == n) begin
                    $display("test done with %d error", error);
                    $finish;
                end
            end
        end
    end
endmodule