`timescale 1ns / 1ps

module tb_processor();

// Тактовый сигнал и сброс
reg clk = 0;
reg rst = 0;

// Подключение верхнего модуля
top dut (
    .clk_i(clk),
    .rst_i(rst)
);

always #5 clk = ~clk;

// ==============================================
// ТЕСТ 1: Базовые арифметические операции
// ==============================================
initial begin
   $dumpfile("dump.vcd"); $dumpvars;
   /*
   //$monitor(" Registers: A=%h, B=%h, C=%h, D=%h, 0=%h, 1=%h, 2=%h, 3=%h", 
                 dut.u1.RF[0], dut.u1.RF[1], dut.u1.RF[2], dut.u1.RF[3], dut.u0.mem[16'h0100], dut.u0.mem[16'h0101], dut.u0.mem[16'h0102], dut.u0.mem[16'h0103]);
    rst = 1'b1;
    // Инициализация памяти для теста арифметики
    $readmemh("out.bin.hex", dut.u0.mem);
    #25
    rst = 1'b0;
    @(dut.u1.halt);
    #10
    $display(" Registers: A=%h, B=%h, C=%h, D=%h", 
                 dut.u1.RF[0], dut.u1.RF[1], dut.u1.RF[2], dut.u1.RF[3]);
    $display("  Flags: Z=%b, C=%b, V=%b, S=%b, IF=%b",
                 dut.u1.flags[0], dut.u1.flags[1], dut.u1.flags[2], 
                 dut.u1.flags[3], dut.u1.flags[4]);
    // Проверка результатов
    if (dut.u1.RF[0] != 8'h10 || dut.u1.RF[1] != 8'h02 || 
        dut.u1.flags[0] != 1'b0 || dut.u1.flags[1] != 1'b1) begin
        $display("TEST 1 FAILED!");
    end else begin
        $display("TEST 1 PASSED!");
    end
    #10
    rst = 1'b1;
    // Инициализация памяти для теста арифметики
    $readmemh("out2.bin.hex", dut.u0.mem);
    #25
    rst = 1'b0;
    @(dut.u1.halt);
    #10
    if (dut.u1.RF[1] != 8'h05 || dut.u0.mem[16'h0100] != 8'h05) begin
        $display("TEST 2 FAILED!");
    end else begin
        $display("TEST 2 PASSED!");
    end

    */
    #10
    rst = 1'b1;
    // Инициализация памяти для теста арифметики
    $readmemh("out3.bin.hex", dut.u0.mem);
    #25
    rst = 1'b0;
    @(dut.u1.halt);
    $display(" Registers: A=%h, B=%h, C=%h, D=%h", 
                 dut.u1.RF[0], dut.u1.RF[1], dut.u1.RF[2], dut.u1.RF[3]);
    $display("  Flags: Z=%b, C=%b, V=%b, S=%b, IF=%b",
                 dut.u1.flags[0], dut.u1.flags[1], dut.u1.flags[2], 
                 dut.u1.flags[3], dut.u1.flags[4]);
    $display("All tests completed");
    $finish;
end

endmodule