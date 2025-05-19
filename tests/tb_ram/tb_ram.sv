`timescale 1ns/1ps

module tb_ram ();

  logic           clk_i;
  logic           rst_ni;
  logic   [9:0]   pA_wb_addr_i;
  logic   [9:0]   pB_wb_addr_i;
  logic           pA_wb_stb_i;
  logic           pB_wb_stb_i;
  logic           pA_wb_we_i;
  logic           pB_wb_we_i;
  logic   [31:0]  pA_wb_data_i;
  logic   [31:0]  pB_wb_data_i;

  logic           pA_wb_ack_o;
  logic           pB_wb_ack_o;
  logic           pA_wb_stall_o;
  logic           pB_wb_stall_o;
  logic  [31:0]   pA_wb_data_o;
  logic  [31:0]   pB_wb_data_o;

  dual_port DUT (.*);

  task static pA_read(input logic [9:0] addr_in, input int num_reads, output logic [31:0] data_out);
    @(posedge clk_i);
    wait (pA_wb_stall_o == 0);
    pA_wb_addr_i <= 10'(addr_in);
    pA_wb_stb_i <= 1;
    pA_wb_we_i <= 0;

    for (int i = 1; i < num_reads; i++) begin
      while (1) begin
        @(posedge clk_i);
        if (pA_wb_stall_o) begin
          pA_wb_stb_i <= 0;
        end else begin
          pA_wb_stb_i <= 1;
          break;
        end
      end
      pA_wb_addr_i <= 10'(addr_in + 4*i);
    end

    @(posedge clk_i);
    wait (pA_wb_ack_o == 1);
    pA_wb_stb_i <= 0;
    pA_wb_we_i <= 0;
    data_out = pA_wb_data_o;
  endtask

  task static pA_write(input logic [9:0] addr_in, input logic [31:0] data_in, input int num_writes);
    for (int i = 0; i < num_writes; i++) begin
      while (1) begin
        @(posedge clk_i);
        if (pA_wb_stall_o) begin
          pA_wb_stb_i <= 0;
        end else begin
          pA_wb_stb_i <= 1;
          break;
        end
      end
      pA_wb_addr_i <= 10'(addr_in + 4*i);
      pA_wb_data_i <= data_in;
      pA_wb_we_i <= 1;
    end
    @(posedge clk_i);
    pA_wb_stb_i <= 0;
    pA_wb_we_i <= 0;
    wait (pA_wb_ack_o == 1);
  endtask

  task static pB_read(input logic [9:0] addr_in, input int num_reads, output logic [31:0] data_out);
    @(posedge clk_i);
    wait (pB_wb_stall_o == 0);
    pB_wb_addr_i <= 10'(addr_in);
    pB_wb_stb_i <= 1;
    pB_wb_we_i <= 0;

    for (int i = 1; i < num_reads; i++) begin
      while (1) begin
        @(posedge clk_i);
        if (pB_wb_stall_o) begin
          pB_wb_stb_i <= 0;
        end else begin
          pB_wb_stb_i <= 1;
          break;
        end
      end
      pB_wb_addr_i <= 10'(addr_in + 4*i);
    end

    @(posedge clk_i);
    wait (pB_wb_ack_o == 1);
    pB_wb_stb_i <= 0;
    pB_wb_we_i <= 0;
    data_out = pB_wb_data_o;
  endtask

  task static pB_write(input logic [9:0] addr_in, input logic [31:0] data_in, input int num_writes);
    for (int i = 0; i < num_writes; i++) begin
      while (1) begin
        @(posedge clk_i);
        if (pB_wb_stall_o) begin
          pB_wb_stb_i <= 0;
        end else begin
          pB_wb_stb_i <= 1;
          break;
        end
      end
      pB_wb_addr_i <= 10'(addr_in + 4*i);
      pB_wb_data_i <= data_in;
      pB_wb_we_i <= 1;
    end
    @(posedge clk_i);
    pB_wb_stb_i <= 0;
    pB_wb_we_i <= 0;
    wait (pB_wb_ack_o == 1);
  endtask

  always begin
    #1;
    clk_i <= ~clk_i;
  end

  logic [31:0] data_outA, data_outB;
  always begin
    $dumpfile("tb_fib.vcd");
    $dumpvars(0);
    clk_i <= 0;
    rst_ni <= 1;
    rst_ni <= 0;

    pA_write(4, 32'hdeadbeef, 1);
    pA_read(4, 1, data_outA);
    assert (data_outA == 32'hdeadbeef) else $error("Port A RAM1 Test Failed");

    pA_write(10'h204, 32'hbeefbeef, 1);
    pA_read(10'h204, 1, data_outA);
    assert (data_outA == 32'hbeefbeef) else $error("Port B RAM1 Test Failed");

    pA_write(10'h100, 32'hc0ffeeee, 5);
    pA_read(10'h100, 5, data_outA);
    assert (data_outA == 32'hc0ffeeee) else $error("Pipelined Read/Write failed");

    pA_write(20, 32'hc0ffee, 4);
    pA_read(10'h100, 4, data_outA);
    assert (data_outA == 32'hc0ffee) $error("Simulataneous Test Port A Failed");
    #5;
    $finish();
  end

  always begin
    #41;
    pB_write(0, 32'hbeefdead, 4);
    pB_read(0, 4, data_outB);
    assert (data_outB == 32'hbeefdead) else $error ("Simultaneous Test Port B Failed");
    #100;

  end

endmodule
