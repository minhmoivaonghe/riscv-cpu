`timescale 1ns/1ps
// Comment dòng nào để tắt nhóm test chưa cài đặt
`define TEST_SLT_SHIFT
`define TEST_LOAD
`define TEST_JALR

module tb_riscv;
    localparam W = 8*40;                       // độ dài tối đa của tên test (40 ký tự)

    reg clock = 0;
    reg rst   = 1;
    hehe dut (.clock(clock), .rst(rst));
    always #5 clock = ~clock;

    // ---------- hằng số & hàm mã hóa lệnh ----------
    localparam [6:0] OP_IMM = 7'b0010011, OP_LOAD = 7'b0000011, OP_JALR = 7'b1100111;
    localparam [2:0] ADD=0, SLL=1, SLT=2, SLTU=3, XOR=4, SR=5, OR=6, AND=7;   // funct3 của OP_IMM
    localparam [2:0] LB=0, LH=1, LW=2, LBU=4, LHU=5;                          // funct3 của load
    localparam [31:0] NOP = 32'h00000013;                                     // addi x0,x0,0

    function [31:0] enc_i(input [11:0] imm, input [4:0] rs1, input [2:0] f3,
                          input [4:0] rd,   input [6:0] op);
        enc_i = {imm, rs1, f3, rd, op};
    endfunction

    function [31:0] enc_r(input [6:0] f7, input [4:0] rs2, input [4:0] rs1,
                          input [2:0] f3, input [4:0] rd);
        enc_r = {f7, rs2, rs1, f3, rd, 7'b0110011};
    endfunction

    // ---------- sổ sách kiểm tra ----------
    integer n = 0, i, errors = 0, checks = 0;
    integer base, tgt, tgt2;
    reg            exp_chk  [0:255];
    reg [4:0]      exp_rd   [0:255];
    reg [31:0]     exp_val  [0:255];
    reg [W-1:0]    exp_name [0:255];
    reg            mon_en = 0;

    task check(input [31:0] got, input [31:0] expv, input [W-1:0] name);
        begin
            checks = checks + 1;
            if (got !== expv) begin                       // !== bắt được cả giá trị X
                errors = errors + 1;
                $display("[FAIL] %0s : got %h, expected %h", name, got, expv);
            end else
                $display("[PASS] %0s", name);
        end
    endtask

    // Nạp 1 lệnh vào bộ nhớ lệnh kèm kết quả mong đợi của thanh ghi rd
    task emit(input [31:0] w, input [4:0] rd, input [31:0] v, input [W-1:0] name);
        begin
            dut.u_mem.memory[n] = w;
            exp_chk[n] = 1; exp_rd[n] = rd; exp_val[n] = v; exp_name[n] = name;
            n = n + 1;
        end
    endtask

    task emit_nochk(input [31:0] w);                      // lệnh không cần kiểm tra
        begin dut.u_mem.memory[n] = w; n = n + 1; end
    endtask

    task t_imm (input [2:0] f3, input [4:0] rd, input [4:0] rs1, input [11:0] imm,
                input [31:0] v, input [W-1:0] name);
        begin emit(enc_i(imm, rs1, f3, rd, OP_IMM), rd, v, name); end
    endtask

    task t_load(input [2:0] f3, input [4:0] rd, input [4:0] rs1, input [11:0] imm,
                input [31:0] v, input [W-1:0] name);
        begin emit(enc_i(imm, rs1, f3, rd, OP_LOAD), rd, v, name); end
    endtask

    // Monitor: ngay sau khi 1 lệnh ghi xong (state == write), so sánh rd với giá trị mong đợi
    reg [31:0] cur;
    always @(posedge clock) if (mon_en && !rst && dut.state == 4'd2) begin
        cur = dut.pc >> 2;                                // pc của lệnh vừa thực thi
        #1;                                               // chờ non-blocking assignment xong
        if (exp_chk[cur]) check(dut.regs[exp_rd[cur]], exp_val[cur], exp_name[cur]);
    end

    // Chạy RIÊNG 1 lệnh: rs1 = x1 (= a), rd = x3. Dùng cho test dạng bảng.
    task run1(input [31:0] w, input [31:0] a, input [31:0] expv, input [W-1:0] name);
        begin
            dut.u_mem.memory[0] = w;
            dut.regs[1] = a;
            dut.regs[3] = 32'hBAD0BAD0;                   // giá trị mồi: nếu lệnh không ghi thì báo l  ỗi
            rst = 1; @(posedge clock); #1 rst = 0;
            repeat (3) @(posedge clock);                  // decode -> execute -> write
            #1 check(dut.regs[3], expv, name);
        end
    endtask

    task clear_state;
        begin
            for (i = 0; i < 32; i = i + 1) dut.regs[i] = 32'b0;
            dut.regs[15] = 32'hDEADBEEF;                  // mồi để bắt lỗi "imm[4:0] bị lẫn với rs2"
`ifdef TEST_LOAD
            for (i = 0; i < 1024; i = i + 1) dut.u_dmem.mem[i] = 8'h00;
            dut.u_dmem.mem[0] = 8'h80;  dut.u_dmem.mem[1] = 8'hFF;   // word @0 = 0x1234FF80
            dut.u_dmem.mem[2] = 8'h34;  dut.u_dmem.mem[3] = 8'h12;
            dut.u_dmem.mem[8] = 8'hAB;
`endif
        end
    endtask

    // ================= CHƯƠNG TRÌNH TEST DÀI =================
    task load_program;
        begin
            n = 0;
            // ---- Nhóm A: addi / andi / ori / xori + R-type hồi quy ----
            t_imm(ADD,  1, 0, 12'd5,   32'd5,        "addi x1=5");
            t_imm(ADD,  2, 1, 12'hFFF, 32'd4,        "addi imm=-1 (phu thuoc x1)");
            t_imm(ADD,  3, 0, 12'h7FF, 32'h000007FF, "addi imm max +2047");
            t_imm(ADD,  4, 0, 12'h800, 32'hFFFFF800, "addi imm min -2048");
            t_imm(ADD,  0, 1, 12'd100, 32'd0,        "addi ghi vao x0 (phai bo qua)");
            t_imm(ADD,  5, 0, 12'hFFF, 32'hFFFFFFFF, "addi x5=-1");
            t_imm(ADD,  6, 5, 12'd1,   32'd0,        "addi tran so -1+1");
            t_imm(ADD,  7, 4, 12'hFFF, 32'hFFFFF7FF, "addi -2048-1");
            t_imm(ADD, 18, 0, 12'h400, 32'h00000400, "addi imm bit10=1 khong duoc thanh SUB");
            t_imm(ADD, 19, 0, 12'd15,  32'd15,       "addi imm[4:0]=rs2(x15) khong bi lan");
            t_imm(AND,  8, 5, 12'h0F0, 32'h000000F0, "andi mask");
            t_imm(AND,  9, 5, 12'hFFF, 32'hFFFFFFFF, "andi sign-extend imm");
            t_imm(OR,  10, 0, 12'h800, 32'hFFFFF800, "ori sign-extend imm");
            t_imm(OR,  11, 1, 12'h0F0, 32'h000000F5, "ori");
            t_imm(XOR, 12, 1, 12'hFFF, 32'hFFFFFFFA, "xori -1 = NOT");
            t_imm(XOR, 13, 5, 12'hFFF, 32'h00000000, "xori ~(-1) = 0");
            emit(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd16), 5'd16, 32'd9,        "add x16=x1+x2 (R-type)");
            emit(enc_r(7'b0100000, 5'd1, 5'd2, 3'b000, 5'd17), 5'd17, 32'hFFFFFFFF, "sub x17=x2-x1 (R-type)");

`ifdef TEST_SLT_SHIFT
            // ---- Nhóm B: so sánh & dịch bit ----
            t_imm(SLT,  20, 5, 12'd0,   32'd1, "slti -1<0 (co dau)");
            t_imm(SLTU, 20, 5, 12'd0,   32'd0, "sltiu 0xFFFFFFFF<0 (khong dau)");
            t_imm(SLTU, 20, 0, 12'hFFF, 32'd1, "sltiu 0<0xFFFFFFFF (imm sign-ext)");
            t_imm(SLT,  20, 1, 12'd5,   32'd0, "slti bang nhau -> 0");
            t_imm(SLT,  20, 4, 12'h801, 32'd1, "slti -2048 < -2047");
            t_imm(SLL,  21, 1,  {7'b0000000,5'd31}, 32'h80000000, "slli 5<<31");
            t_imm(SR,   22, 21, {7'b0000000,5'd31}, 32'h00000001, "srli 0x80000000>>31");
            t_imm(SR,   23, 21, {7'b0100000,5'd31}, 32'hFFFFFFFF, "srai 0x80000000>>>31");
            t_imm(SR,   24, 21, {7'b0100000,5'd0},  32'h80000000, "srai dich 0");
            t_imm(SR,   25, 21, {7'b0000000,5'd0},  32'h80000000, "srli dich 0");
            t_imm(SLL,  26, 1,  {7'b0000000,5'd0},  32'd5,        "slli dich 0");
            t_imm(SR,   27, 1,  {7'b0100000,5'd1},  32'd2,        "srai so duong 5>>>1");
            t_imm(SR,   28, 5,  {7'b0000000,5'd4},  32'h0FFFFFFF, "srli -1>>4");
            t_imm(SR,   29, 5,  {7'b0100000,5'd4},  32'hFFFFFFFF, "srai -1>>>4");
`endif

`ifdef TEST_LOAD
            // ---- Nhóm C: load (dmem: @0=80 FF 34 12, @8=AB) ----
            t_load(LB,  20, 0, 12'd0, 32'hFFFFFF80, "lb sign-extend");
            t_load(LBU, 21, 0, 12'd0, 32'h00000080, "lbu zero-extend");
            t_load(LH,  22, 0, 12'd0, 32'hFFFFFF80, "lh sign-extend");
            t_load(LHU, 23, 0, 12'd0, 32'h0000FF80, "lhu zero-extend");
            t_load(LW,  24, 0, 12'd0, 32'h1234FF80, "lw little-endian");
            t_load(LB,  25, 0, 12'd3, 32'h00000012, "lb offset +3");
            t_imm (ADD, 26, 0, 12'd4, 32'd4,        "setup x26=4");
            t_load(LB,  27, 26, 12'hFFF, 32'h00000012, "lb offset am (4-1=3)");
            t_load(LW,   0, 0, 12'd0, 32'd0,        "lw vao x0 phai bo qua");
            t_load(LBU, 28, 26, 12'd4, 32'h000000AB, "lbu: dia chi = ADD (4+4=8), khong XOR");
            t_load(LH,  29, 0, 12'd2, 32'h00001234, "lh offset +2");
`endif

`ifdef TEST_JALR
            // ---- Nhóm D: jalr ----
            // (a) nhảy tới địa chỉ chẵn, kiểm tra link = pc+4
            base = n; tgt = (base + 3) * 4;
            emit(enc_i(tgt[11:0], 5'd0, 3'b000, 5'd29, OP_IMM), 5'd29, tgt, "jalr(a) nap dia chi dich");
            emit(enc_i(12'd0, 5'd29, 3'b000, 5'd28, OP_JALR), 5'd28, (base + 2) * 4, "jalr(a) link = pc+4");
            emit_nochk(enc_i(12'd111, 5'd0, 3'b000, 5'd30, OP_IMM));        // phải bị nhảy qua
            emit(enc_i(12'd1, 5'd0, 3'b000, 5'd31, OP_IMM), 5'd31, 32'd1, "jalr(a) toi dich");

            // (b) địa chỉ lẻ: phần cứng phải xóa bit 0; rd = x0
            base = n; tgt = (base + 3) * 4 + 1; tgt2 = (base + 4) * 4;
            emit(enc_i(tgt[11:0], 5'd0, 3'b000, 5'd29, OP_IMM), 5'd29, tgt, "jalr(b) nap dia chi le");
            emit(enc_i(12'd0, 5'd29, 3'b000, 5'd0, OP_JALR), 5'd0, 32'd0,  "jalr(b) rd=x0 khong ghi");
            emit_nochk(enc_i(12'd222, 5'd0, 3'b000, 5'd30, OP_IMM));        // phải bị nhảy qua
            emit(enc_i(tgt2[11:0], 5'd0, 3'b000, 5'd27, OP_JALR), 5'd27, tgt2, "jalr(b) pc sau nhay phai chan");
            emit(enc_i(12'd2, 5'd0, 3'b000, 5'd31, OP_IMM), 5'd31, 32'd2, "jalr(b) toi dich");

            // (c) rs1 + imm: nhảy tới địa chỉ jalr + 12
            base = n; tgt = (base + 1) * 4;
            emit(enc_i(tgt[11:0], 5'd0, 3'b000, 5'd29, OP_IMM), 5'd29, tgt, "jalr(c) nap dia chi");
            emit(enc_i(12'd12, 5'd29, 3'b000, 5'd28, OP_JALR), 5'd28, (base + 2) * 4, "jalr(c) rs1+imm, link");
            emit_nochk(enc_i(12'd333, 5'd0, 3'b000, 5'd30, OP_IMM));        // bị nhảy qua
            emit_nochk(enc_i(12'd334, 5'd0, 3'b000, 5'd30, OP_IMM));        // bị nhảy qua
            emit(enc_i(12'd3, 5'd0, 3'b000, 5'd31, OP_IMM), 5'd31, 32'd3, "jalr(c) toi dich");
`endif
        end
    endtask

    // ================= ĐIỀU KHIỂN CHÍNH =================
    initial begin
        #1;
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_riscv);
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_mem.memory[i] = NOP;
            exp_chk[i] = 1'b0;
        end
        clear_state;

        // ===== PHẦN 1: test từng lệnh riêng lẻ (dạng bảng). Dán output của script Python vào đây =====
        run1(enc_i(12'h7FF, 5'd1, ADD,  5'd3, OP_IMM), 32'h7FFFFFFF, 32'h800007FE, "addi tran so duong");
        run1(enc_i(12'h800, 5'd1, ADD,  5'd3, OP_IMM), 32'h80000000, 32'h7FFFF800, "addi tran so am");
        run1(enc_i(12'hFFF, 5'd1, SLTU, 5'd3, OP_IMM), 32'hFFFFFFFF, 32'h00000000, "sltiu max<max");
        run1(enc_i(12'h000, 5'd1, SLT,  5'd3, OP_IMM), 32'h80000000, 32'h00000001, "slti INT_MIN<0");

        // ===== PHẦN 2: chương trình dài, có phụ thuộc dữ liệu =====
        clear_state;
        load_program;
        mon_en = 1;
        rst = 1; repeat (2) @(posedge clock); #1 rst = 0;
        wait (dut.pc >= n * 4);                           // chạy hết chương trình
        #20 mon_en = 0;

`ifdef TEST_JALR
        check(dut.regs[30], 32'd0, "jalr: lenh bi nhay qua khong duoc chay");
`endif
        check(dut.regs[0], 32'd0, "x0 luon bang 0");

        $display("=== %0d checks, %0d errors ===", checks, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $finish;
    end

    initial begin #200000; $display("[TIMEOUT] CPU bi treo?"); $finish; end   // chống treo
endmodule