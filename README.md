# RISC-V CPU

Thiết kế CPU RISC-V [RV32I, pipeline X tầng / single-cycle] bằng Verilog/SystemVerilog, kiểm tra bằng testbench tự động so sánh với đáp án tham chiếu.

## Cấu trúc thư mục

| Thư mục | Nội dung |
|---|---|
| `rtl/` | Mã nguồn thiết kế CPU |
| `tb/` | Testbench và testbench tự kiểm tra (self-checking) |
| `model/` | Chương trình C++ tạo đáp án tham chiếu |
| `data/input/` | Chương trình/lệnh đầu vào cho CPU |
| `data/expected/` | File đáp án mong đợi (kết quả, PC) |
| `sim/` | Script mô phỏng ModelSim |

## Tính năng

- Tập lệnh hỗ trợ: [liệt kê, ví dụ: R-type, I-type, load/store, branch, jump]
- [Xử lý hazard / forwarding nếu có]
- Tự động so sánh kết quả mô phỏng với đáp án

## Cách chạy

1. Tạo đáp án tham chiếu:
   ```
   g++ model/ittm.cpp -o ittm
   ./ittm
   ```
2. Mô phỏng bằng ModelSim: mở ModelSim, `cd` vào thư mục gốc project rồi chạy script trong `sim/` sử dụng file 'modelmsim' dán từng lệnh chạy nó trong script.
3. Xem kết quả PASS/FAIL trong cửa sổ Transcript.

## Công cụ

- ModelSim [phiên bản]
- g++ (để biên dịch chương trình tạo đáp án)

## Tác giả

Đỗ Thành Minh ([@minhmoivaonghe](https://github.com/minhmoivaonghe))