// ittm: instruction memory (ROM, đọc tổ hợp)
module ittm (
    input  wire [31:0] address,
    output wire [31:0] instruction
);
    reg [31:0] memory [0:16383];            // 64KB

    initial $readmemh("data/load_s_type_test/test2/input.txt", memory);

    assign instruction = memory[address >> 2];
endmodule


// ram_mem: data memory, đọc đồng bộ, hỗ trợ LB/LH/LW/LBU/LHU và SB/SH/SW
module ram_mem (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] dataW,
    input  logic [2:0]  funct3,
    input  logic        we,
    output logic [31:0] dataR
);
    logic [31:0] mem [0:255];               // 1KB

    initial $readmemh("data/load_s_type_test/test2/ram_init.txt", mem);

    wire [7:0]  idx   = addr[9:2];
    wire [31:0] rdata = mem[idx];
    wire [31:0] sh    = rdata >> {addr[1:0], 3'b000};   // đưa byte/half cần đọc về bit 0

    always @(posedge clk) begin
        if (we) begin
            case (funct3)
                3'b000:                                 // SB
                    case (addr[1:0])
                        2'b00:   mem[idx][7:0]   <= dataW[7:0];
                        2'b01:   mem[idx][15:8]  <= dataW[7:0];
                        2'b10:   mem[idx][23:16] <= dataW[7:0];
                        2'b11:   mem[idx][31:24] <= dataW[7:0];
                    endcase

                3'b001:                                 // SH
                    if (addr[1]) mem[idx][31:16] <= dataW[15:0];
                    else         mem[idx][15:0]  <= dataW[15:0];

                default: mem[idx] <= dataW;             // SW
            endcase
        end
        else begin
            case (funct3)
                3'b000:  dataR <= {{24{sh[7]}},  sh[7:0]};     // LB
                3'b001:  dataR <= {{16{sh[15]}}, sh[15:0]};    // LH
                3'b100:  dataR <= {24'b0, sh[7:0]};            // LBU
                3'b101:  dataR <= {16'b0, sh[15:0]};           // LHU
                default: dataR <= rdata;                       // LW
            endcase
        end
    end
endmodule


// alu
module alu (
    input  wire [31:0] A, B,
    input  wire [3:0]  op,                  // mã phép toán, xem ALU_* ở module hehe
    output reg  [31:0] result
);
    wire signed [31:0] sra = $signed(A) >>> B[4:0];   // tách riêng để không bị ép unsigned

    always @(*) begin
        case (op)
            4'd0:    result = A + B;                              // ADD
            4'd1:    result = A - B;                              // SUB
            4'd2:    result = A & B;                              // AND
            4'd3:    result = A | B;                              // OR
            4'd4:    result = A ^ B;                              // XOR
            4'd5:    result = {31'b0, $signed(A) < $signed(B)};   // SLT
            4'd6:    result = {31'b0, A < B};                     // SLTU
            4'd7:    result = A << B[4:0];                        // SLL
            4'd8:    result = A >> B[4:0];                        // SRL
            4'd9:    result = sra;                                // SRA
            4'd10:   result = {31'b0, A == B};                    // EQ (cho branch)
            default: result = 32'b0;
        endcase
    end
endmodule


// decoder: tách các trường của lệnh
module decoder (
    input  wire [31:0] instruction,
    output wire [6:0]  funct7,
    output wire [2:0]  funct3,
    output wire [6:0]  opcode,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd
);
    assign funct7 = instruction[31:25];
    assign funct3 = instruction[14:12];
    assign rs2    = instruction[24:20];
    assign rs1    = instruction[19:15];
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
endmodule


// immcheck: sinh immediate theo loại lệnh, useimm = 1 thì ALU lấy imm thay rs2
module immcheck (
    input  wire [31:0] instruction,
    output reg  [31:0] imm,
    output reg         useimm
);
    always @(*) begin
        imm    = 32'b0;
        useimm = 1'b0;

        case (instruction[6:0])
            // I-type: LOAD / OP-IMM / JALR
            7'b0000011, 7'b0010011, 7'b1100111: begin
                imm    = {{20{instruction[31]}}, instruction[31:20]};
                useimm = 1'b1;
            end

            // S-type: STORE
            7'b0100011: begin
                imm    = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                useimm = 1'b1;
            end

            // B-type: BRANCH
            7'b1100011:
                imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                       instruction[30:25], instruction[11:8], 1'b0};

            // J-type: JAL
            7'b1101111:
                imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                       instruction[20], instruction[30:21], 1'b0};

            // U-type: LUI / AUIPC
            7'b0110111, 7'b0010111: begin
                imm    = {instruction[31:12], 12'b0};
                useimm = 1'b1;
            end

            default: ;
        endcase
    end
endmodule


// hehe: CPU top (multi-cycle)
// FSM: decode -> [execute (load) | smem (store)] -> write
module hehe (
    input wire clock,
    input wire rst
);
    // hằng số
    localparam [3:0]
        decode  = 4'd0,
        execute = 4'd1,                     // chờ RAM đọc (chỉ LOAD)
        smem    = 4'd2,                     // bật ghi RAM (chỉ STORE)
        write   = 4'd3;                     // ghi regs, cập nhật PC

    localparam
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_AND  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_XOR  = 4'd4,
        ALU_SLT  = 4'd5,
        ALU_SLTU = 4'd6,
        ALU_SLL  = 4'd7,
        ALU_SRL  = 4'd8,
        ALU_SRA  = 4'd9,
        ALU_EQ   = 4'd10;

    // thanh ghi
    integer i;
    reg  [31:0] pc = 32'd0;
    reg  [31:0] A, B;                       // rs1, rs2 chốt ở decode
    reg  [3:0]  state = decode;
    reg  [31:0] regs [0:31];

    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;

    // tín hiệu của lệnh hiện tại
    wire [31:0] ir, imm, alu_result;
    wire        useimm;
    wire [6:0]  funct7, opcode;
    wire [2:0]  funct3;
    wire [4:0]  rs1, rs2, rd;
    wire [3:0]  alu_op;

    logic [31:0] load_out;
    logic        mem_we = 0;

    // nhận diện lệnh
    wire is_rtype  = (opcode == 7'b0110011);
    wire is_opimm  = (opcode == 7'b0010011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_stype  = (opcode == 7'b0100011);
    wire is_branch = (opcode == 7'b1100011);
    wire is_jal    = (opcode == 7'b1101111);
    wire is_jalr   = (opcode == 7'b1100111);
    wire is_lui    = (opcode == 7'b0110111);
    wire is_auipc  = (opcode == 7'b0010111);

    // toán hạng ALU: LUI = 0 + imm, AUIPC = pc + imm
    wire [31:0] alu_b = useimm ? imm : B;
    wire [31:0] alu_a = is_lui ? 32'b0 : is_auipc ? pc : A;

    // khối con
    ittm    u_mem (.address(pc), .instruction(ir));

    decoder u_dec (
        .instruction(ir),
        .funct7(funct7), .funct3(funct3), .opcode(opcode),
        .rs1(rs1), .rs2(rs2), .rd(rd)
    );

    immcheck u_imm (.instruction(ir), .imm(imm), .useimm(useimm));

    alu u_alu (.A(alu_a), .B(alu_b), .op(alu_op), .result(alu_result));

    ram_mem u_ram (
        .clk(clock), .addr(alu_result), .dataW(B),
        .funct3(funct3), .we(mem_we), .dataR(load_out)
    );

    // giải mã alu_op
    // BRANCH: funct3[2:1] = 00 -> EQ, 10 -> SLT, 11 -> SLTU
    wire [3:0] alu_op_branch = (funct3[2:1] == 2'b10) ? ALU_SLT  :
                               (funct3[2:1] == 2'b11) ? ALU_SLTU :
                                                        ALU_EQ;

    wire [3:0] alu_op_arith  = (funct3 == 3'b000) ? ((is_rtype && funct7[5]) ? ALU_SUB : ALU_ADD) :
                               (funct3 == 3'b001) ? ALU_SLL  :
                               (funct3 == 3'b010) ? ALU_SLT  :
                               (funct3 == 3'b011) ? ALU_SLTU :
                               (funct3 == 3'b100) ? ALU_XOR  :
                               (funct3 == 3'b101) ? (funct7[5] ? ALU_SRA : ALU_SRL) :
                               (funct3 == 3'b110) ? ALU_OR   :
                                                    ALU_AND;

    // LOAD/STORE/JAL/JALR/LUI/AUIPC chỉ cần phép cộng
    assign alu_op = (is_load || is_stype || is_jal || is_jalr || is_lui || is_auipc) ? ALU_ADD :
                    (is_branch)                                                      ? alu_op_branch :
                                                                                       alu_op_arith;

    // dữ liệu ghi về rd
    wire [31:0] wb_data = (is_jal || is_jalr) ? (pc + 4) :
                          (is_load)           ? load_out :
                                                alu_result;

    // FSM
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            pc    <= 32'b0;
            state <= decode;
        end
        else begin
            case (state)
                decode: begin
                    A     <= regs[rs1];
                    B     <= regs[rs2];
                    state <= is_load  ? execute :
                             is_stype ? smem    : write;
                end

                execute: state <= write;

                smem: begin
                    mem_we <= 1;
                    state  <= write;
                end

                write: begin
                    mem_we <= 0;

                    if (rd != 5'd0 && !is_branch && !is_stype)
                        regs[rd] <= wb_data;

                    // cập nhật PC
                    if (is_branch) begin
                        case (funct3)
                            // BNE/BGE/BGEU: nhảy khi kết quả so sánh = 0
                            3'b001, 3'b101, 3'b111:
                                pc <= !alu_result ? pc + imm : pc + 4;
                            // BEQ/BLT/BLTU: nhảy khi kết quả so sánh = 1
                            default:
                                pc <=  alu_result ? pc + imm : pc + 4;
                        endcase
                    end
                    else if (is_jal)  pc <= pc + imm;
                    else if (is_jalr) pc <= {alu_result[31:1], 1'b0};   // (rs1 + imm) & ~1
                    else              pc <= pc + 4;

                    state <= decode;
                end

                default: state <= decode;
            endcase
        end
    end
endmodule