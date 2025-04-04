module top (
  input clk_i,
  input rst_i
);

// RAM signals
wire [15:0] ram_address_line;
wire [7:0] ram_data_to_r_line;
wire [7:0] ram_data_from_r_line;
wire ram_we;

// Core IO signals
logic [7:0] io_data_i;
wire [7:0] io_data_o;
wire [7:0] io_addr_o;
wire io_we_o;

// RTC signals
wire rtc_irq;
wire [31:0] rtc_snap_millis;

logic [7:0] device_id;

// Чтение данных
always_comb begin
  case(io_addr_o)
    0: io_data_i = device_id;
    1: io_data_i = rtc_snap_millis[7:0];
    2: io_data_i = rtc_snap_millis[15:8];
    3: io_data_i = rtc_snap_millis[23:16];
    4: io_data_i = rtc_snap_millis[31:24];
    default: io_data_i = 8'b0;
  endcase
end

always_comb begin
  if (rtc_irq) device_id = 8'h1; //RTC
  else device_id = 8'h0;
end


ram u0(
  .clk_i         (clk_i),
  .rst_i         (rst_i),
  // A\D line
  .address_i     (ram_address_line),
  .data_i        (ram_data_to_r_line),
  .we_i          (ram_we),
  .data_o        (ram_data_from_r_line)
);

core u1(
  .clk_i         (clk_i),
  .rst_i         (rst_i),
  // Memory interface
  .address_o     (ram_address_line),
  .data_i        (ram_data_from_r_line),
  .we_i          (ram_we),
  .data_o        (ram_data_to_r_line),
  // IO interface
  .irq_i         (rtc_irq),
  .io_data_i     (io_data_i),
  .io_data_o     (io_data_o),
  .io_addr_o     (io_addr_o),
  .io_we_o       (io_we_o)
);


rtc u2(
  .clk_i              (clk_i),
  .rst_i              (rst_i),
  .current_millis     (rtc_snap_millis),
  .irq_o              (rtc_irq)
);
  
endmodule