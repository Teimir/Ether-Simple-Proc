module rtc (
  input clk_i,
  input rst_i,
  // IO Interface
  output reg irq_o,
  output [31:0] current_millis
);

localparam CLK_FREQ = 50_000_000;    // Пример: 50 МГц
localparam MS_DIVIDER = CLK_FREQ / 1000;

reg [31:0] milliseconds;
reg [15:0] counter;

always @(posedge clk_i or posedge rst_i) begin
  if (rst_i) begin
    counter <= 0;
    milliseconds <= 0;
    irq_o <= 0;
  end else begin
    // Обновление счетчика
    if (counter >= MS_DIVIDER - 1) begin
      counter <= 0;
      milliseconds <= milliseconds + 1;
      irq_o <= 1;
    end else begin
      counter <= counter + 1;
      irq_o <= 0;
    end
  end
end

assign current_millis = milliseconds;

endmodule