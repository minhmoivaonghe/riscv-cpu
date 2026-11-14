        module ittm (
            input  wire [31:0] address,
            output wire [31:0] instruction
        );
            reg [31:0] memory [0:63];
            initial begin
                $readmemh("input.txt", memory);
            end
            assign instruction = memory[address >> 2];
        endmodule

        module alu (
            input  wire [31:0] A, B,
            input  wire [3:0]  op,
            output wire [31:0] result
        );
            wire signed [31:0] sra = $signed(A) >>> B[4:0]; // tách wire, tránh ép unsigned trong ?:
            assign result =
                (op == 4'd0) ? A + B :
                (op == 4'd1) ? A - B :
                (op == 4'd2) ? A & B :
                (op == 4'd3) ? A | B :
                (op == 4'd4) ? A ^ B :
                (op == 4'd5) ? {31'b0, $signed(A) < $signed(B)} : // SLT
                (op == 4'd6) ? {31'b0, A < B} :                   // SLTU
                (op == 4'd7) ? A << B[4:0] :                      // SLL
                (op == 4'd8) ? A >> B[4:0] :                      // SRL
                (op == 4'd9) ? sra :                              // SRA
                (op == 4'd10)? {31'b0 , A == B} : 32'b0;          // SUB
        endmodule
        
        module decoder (
            input  wire [31:0] instruction,

            output wire [6:0] funct7,
            output wire [2:0] funct3,
            output wire [6:0] opcode,
            output wire [4:0] rs1,
            output wire [4:0] rs2,
            output wire [4:0] rd
        );

            assign funct7 = instruction[31:25];
            assign funct3 = instruction[14:12];
            assign rs2    = instruction[24:20];
            assign rs1    = instruction[19:15];
            assign opcode = instruction[6:0];
            assign rd     = instruction[11:7];
        endmodule


        module immcheck (
            input  wire [31:0] instruction,
            output reg  [31:0] imm,
            output reg         useimm
        );
            always @(*) begin
                imm    = 32'b0;
                useimm = 1'b0;
                case (instruction[6:0])
                    7'b0000011, 7'b0010011, 7'b1100111: begin
                        imm    = {{20{instruction[31]}}, instruction[31:20]};
                        useimm = 1'b1;
                    end
                    7'b1100011 : begin
                        imm = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                    end
                    7'b1101111 : begin
                        imm = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
                    end

                    default: ;
                endcase
            end
        endmodule
        module hehe (
            input wire clock,
            input wire rst
        );
            integer i;
            reg  [31:0] pc = 32'd0;
            reg  [31:0] A, B;
            reg  [3:0]  state = 4'd0;
            reg  [31:0] regs [0:31];
            reg  [3:0]  alu_op;

            wire [31:0] ir;
            wire [31:0] imm;
            wire        useimm;
            wire [6:0]  funct7, opcode;
            wire [2:0]  funct3;
            wire [4:0]  rs1, rs2, rd;
            wire [31:0] alu_result;
            wire [31:0] alu_b = useimm ? imm : B;

            ittm   u_mem (.address(pc), .instruction(ir));

            decoder u_dec (
                .instruction(ir),
                .funct7(funct7), .funct3(funct3), .opcode(opcode),
                .rs1(rs1), .rs2(rs2), .rd(rd)
            );

            immcheck u_imm (.instruction(ir), .imm(imm), .useimm(useimm));
            alu u_alu (.A(A), .B(alu_b), .op(alu_op), .result(alu_result));

            wire is_op    = (opcode == 7'b0110011);
            wire is_opimm = (opcode == 7'b0010011);
            wire is_load  = (opcode == 7'b0000011);
            wire is_branch = (opcode == 7'b1100011);
            wire is_jal    = (opcode == 7'b1101111);
            wire is_jalr   = (opcode == 7'b1100111);
            wire is_rtype  = (opcode == 7'b0110011);

            localparam [3:0]
                decode  = 4'd0,
                execute = 4'd1,
                write   = 4'd2;
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

            initial begin
                for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
            end
            wire [31:0] wb_data = (is_jal || is_jalr) ? (pc + 4) : 
                                  (is_load)           ? regs[alu_result] :
                                                        alu_result;
            always @(posedge clock or posedge rst) begin
                if (rst) begin
                    pc    <= 32'b0;
                    state <= decode;
                end else begin
                    case (state)
                        decode: begin
                            A <= regs[rs1];
                            B <= regs[rs2];
                            state <= execute;
                        end
                        execute: begin
                            if (is_load || is_jalr || is_jal) alu_op <= 4'd0;       
                            else if (is_branch) begin
                                case (funct3)
                                    3'b000, 3'b001: alu_op <= ALU_EQ;   // beq, bne
                                    3'b100, 3'b101: alu_op <= ALU_SLT;  // blt, bge
                                    3'b110, 3'b111: alu_op <= ALU_SLTU; // bltu, bgeu
                                    default:        alu_op <= ALU_EQ;
                                endcase
                            end
                            else begin
                                case (funct3)
                                    3'b000: alu_op <= (is_rtype && funct7[5]) ? ALU_SUB : ALU_ADD; // add/sub 
                                    3'b001: alu_op <= ALU_SLL;
                                    3'b010: alu_op <= ALU_SLT;
                                    3'b011: alu_op <= ALU_SLTU;
                                    3'b100: alu_op <= ALU_XOR;
                                    3'b101: alu_op <= funct7[5] ? ALU_SRA : ALU_SRL;
                                    3'b110: alu_op <= ALU_OR;
                                    3'b111: alu_op <= ALU_AND;
                                endcase
                            end
                            state <= write;
                        end
                        write: begin
                            if (rd != 5'd0 && !is_branch) begin            
                                regs[rd] <= wb_data;
                            end
                            if (is_branch) begin
                                case (funct3)
                                    3'b001, 3'b101, 3'b111 : begin
                                        if (!alu_result) begin
                                            pc <= pc +  imm; 
                                        end
                                        else pc <= pc + 4;

                                    end
                                    default : begin
                                        if (alu_result) begin
                                            pc <= pc +  imm; 
                                        end
                                        else pc <= pc + 4;
                                    end
                                endcase  
                            end
                            else if (is_jal)
                                pc <= pc +  imm;  
                            else if (is_jalr)
                                pc <= {alu_result[31:1], 1'b0};
                            else 
                                pc <= pc + 4;
                            state <= decode;
                        end
                        default: state <= decode;
                    endcase
                end
            end
        endmodule