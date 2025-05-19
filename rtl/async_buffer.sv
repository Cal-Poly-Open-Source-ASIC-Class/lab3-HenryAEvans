`timescale 1ns/1ps

module async_buffer #(
  parameter int WIDTH=1
) (
  input clk_i,
  input rst_ni,
  input valid_i,
  input [WIDTH-1:0] data_i,
  output [WIDTH-1:0] data_o
  );

  logic [WIDTH-1:0] data_reg;

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      data_reg <= '0;
    end else if (valid_i) begin
      data_reg <= data_i;
    end
  end

  assign data_o = valid_i ? data_i : data_reg;

endmodule
