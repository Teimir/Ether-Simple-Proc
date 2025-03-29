module top (
  input clk_i,
  input rst_i
);

wire [15:0] ram_address_line;
wire [7:0] ram_data_to_r_line;
wire [7:0] ram_data_from_r_line;
wire ram_we;

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
  .clk_i(clk_i),
  .rst_i(rst_i),
  // A\D line
  .address_o(ram_address_line),  
  .data_i(ram_data_from_r_line),
  .we_i(ram_we),              
  .data_o(ram_data_to_r_line)
);

  
endmodule