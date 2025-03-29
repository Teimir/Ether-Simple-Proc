module ram (
  input clk_i,
  input rst_i,
  // A\D line
  input [15:0] address_i,
  input [7:0] data_i,
  input we_i,
  output logic [7:0] data_o
);

logic [7:0] mem [65536];

always_ff @( posedge clk_i ) begin
  if (we_i) mem [address_i] <= data_i;
end

always_ff @(posedge clk_i) begin
  data_o <= mem [address_i]; 
end
  
endmodule