
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdint>
#include <string>

using namespace std;
uint32_t reg[32] = {0};
uint32_t sign_extend_12(uint32_t imm) {
    imm &= 0xFFF;
    if (imm & 0x800)
        imm |= 0xFFFFF000;
    return imm;
}

int64_t signed_value(uint32_t x) {
    if (x & 0x80000000u)
        return (int64_t)x - 0x100000000LL;
    return x;
}

uint32_t arithmetic_right(uint32_t x, unsigned shamt) {
    if (shamt == 0)
        return x;
    uint32_t result = x >> shamt;
    if (x & 0x80000000u)
        result |= (0xFFFFFFFFu << (32 - shamt));
    return result;
}

void calculate(uint32_t inst, uint32_t &result) {

    uint32_t opcode = inst & 0x7F;
    uint32_t funct3 = (inst >> 12) & 0x7;
    uint32_t funct7 = (inst >> 25) & 0x7F;
    uint32_t rs1    = (inst >> 15) & 0x1F;
    uint32_t rs2    = (inst >> 20) & 0x1F;
    uint32_t imm12  = (inst >> 20) & 0xFFF;
    uint32_t imm    = sign_extend_12(imm12);
    unsigned shamt  = imm12 & 0x1F;

    result = 0;   

    // R-type
    if (opcode == 0x33) {
        switch (funct3) {
        case 0:
            if (funct7 == 0x00) result = reg[rs1] + reg[rs2];       // ADD
            else if (funct7 == 0x20) result = reg[rs1] - reg[rs2];  // SUB
            break;
        case 1:
            if (funct7 == 0x00) result = reg[rs1] << (reg[rs2] & 0x1F);   // SLL
            break;
        case 2:
            if (funct7 == 0x00) result = signed_value(reg[rs1]) < signed_value(reg[rs2]); // SLT
            break;
        case 3:
            if (funct7 == 0x00) result = reg[rs1] < reg[rs2];       // SLTU
            break;
        case 4:
            if (funct7 == 0x00) result = reg[rs1] ^ reg[rs2];       // XOR
            break;
        case 5:
            if (funct7 == 0x00) result = reg[rs1] >> (reg[rs2] & 0x1F);              // SRL
            else if (funct7 == 0x20) result = arithmetic_right(reg[rs1], reg[rs2] & 0x1F); // SRA
            break;
        case 6:
            if (funct7 == 0x00) result = reg[rs1] | reg[rs2];       // OR
            break;
        case 7:
            if (funct7 == 0x00) result = reg[rs1] & reg[rs2];       // AND
            break;
        }
        return;
    }

    // I-type
    if (opcode == 0x13) {
        switch (funct3) {
        case 0: result = reg[rs1] + imm; break;                                // ADDI
        case 2: result = signed_value(reg[rs1]) < signed_value(imm); break;    // SLTI
        case 3: result = reg[rs1] < imm; break;                                // SLTIU
        case 4: result = reg[rs1] ^ imm; break;                                // XORI
        case 6: result = reg[rs1] | imm; break;                                // ORI
        case 7: result = reg[rs1] & imm; break;                                // ANDI
        case 1:
            if (funct7 == 0x00) result = reg[rs1] << shamt;                    // SLLI
            break;
        case 5:
            if (funct7 == 0x00) result = reg[rs1] >> shamt;                    // SRLI
            else if (funct7 == 0x20) result = arithmetic_right(reg[rs1], shamt); // SRAI
            break;
        }
        return;
    }
}

int main() {
    freopen("input.txt", "r", stdin);
    freopen("answers.txt", "w", stdout);
    reg[1] = 10;
    reg[2] = 20;
    uint32_t inst, rs1, rs2, result;
    int count = 0;
	
    while (cin >> hex >> inst) {
        calculate(inst, result);
        uint32_t rd = (inst >> 7) & 0x1F;
        if (rd != 0) reg[rd] = result;   
        cout << uppercase << hex << setfill('0')
            << setw(8) << result << '\n';

        count++;
    }

    cerr << "Generated " << count << " answers\n";
    return 0;
}
	
