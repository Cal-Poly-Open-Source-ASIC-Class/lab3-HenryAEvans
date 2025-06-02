`timescale 1ns/1ps

module tb_ram ();

  logic           clk_i;
  logic           rst_ni;
  logic   [8:0]   pA_wb_addr_i;
  logic   [8:0]   pB_wb_addr_i;
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


  wire VPWR, VGND;
  assign VPWR = 1;
  assign VGND = 0;

  dual_port DUT (.*);

  task static pA_read(input logic [8:0] addr_in, input int num_reads, output logic [31:0] data_out);
    @(posedge clk_i);
    wait (pA_wb_stall_o == 0);
    pA_wb_addr_i <= 9'(addr_in);
    pA_wb_stb_i <= 1;
    pA_wb_we_i <= 0;

    for (int i = 1; i < num_reads; i++) begin
      @(posedge clk_i);
      while (pA_wb_stall_o) begin
        pA_wb_stb_i <= 0;
        @(posedge clk_i);
      end
      pA_wb_stb_i <= 1;
      pA_wb_addr_i <= 9'(addr_in + 4*i);
    end

    @(posedge clk_i);
    wait (pA_wb_ack_o == 1);
    pA_wb_stb_i <= 0;
    pA_wb_we_i <= 0;
    data_out = pA_wb_data_o;
  endtask

  task static pA_write(input logic [8:0] addr_in, input logic [31:0] data_in, input int num_writes);
    for (int i = 0; i < num_writes; i++) begin
      @(posedge clk_i);
      while (pA_wb_stall_o) begin
        pA_wb_stb_i <= 0;
        @(posedge clk_i);
      end
      pA_wb_stb_i <= 1;
      pA_wb_addr_i <= 9'(addr_in + 4*i);
      pA_wb_data_i <= data_in;
      pA_wb_we_i <= 1;
    end
    @(posedge clk_i);
    pA_wb_stb_i <= 0;
    pA_wb_we_i <= 0;
    wait (pA_wb_ack_o == 1);
  endtask

  task static pB_read(input logic [8:0] addr_in, input int num_reads, output logic [31:0] data_out);
    @(posedge clk_i);
    wait (pB_wb_stall_o == 0);
    pB_wb_addr_i <= 9'(addr_in);
    pB_wb_stb_i <= 1;
    pB_wb_we_i <= 0;

    for (int i = 1; i < num_reads; i++) begin
      @(posedge clk_i);
      while (pB_wb_stall_o) begin
        pB_wb_stb_i <= 0;
        @(posedge clk_i);
      end
      pB_wb_stb_i <= 1;
      pB_wb_addr_i <= 9'(addr_in + 4*i);
    end

    @(posedge clk_i);
    wait (pB_wb_ack_o == 1);
    pB_wb_stb_i <= 0;
    pB_wb_we_i <= 0;
    data_out = pB_wb_data_o;
  endtask

  task static pB_write(input logic [8:0] addr_in, input logic [31:0] data_in, input int num_writes);
    for (int i = 0; i < num_writes; i++) begin
      @(posedge clk_i);
      while (pB_wb_stall_o) begin
        @(posedge clk_i);
        pB_wb_stb_i <= 0;
      end
      pB_wb_stb_i <= 1;
      pB_wb_addr_i <= 9'(addr_in + 4*i);
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
    $dumpfile("tb_ram.vcd");
    $dumpvars(2);
    clk_i <= 0;
    rst_ni <= 1;
    pA_wb_stb_i <= 0;
    pA_wb_addr_i <= 0;
    pA_wb_data_i <= 0;
    pA_wb_we_i <= 0;
    pB_wb_stb_i <= 0;
    pB_wb_addr_i <= 0;
    pB_wb_data_i <= 0;
    pB_wb_we_i <= 0;
    #5;
    rst_ni <= 0;

    pA_write(4, 32'hdeadbeef, 1);
    pA_read(4, 1, data_outA);
    assert (data_outA == 32'hdeadbeef) else $error("Port A RAM1 Test Failed");

    pA_write(9'h104, 32'hbeefbeef, 1);
    pA_read(9'h104, 1, data_outA);
    assert (data_outA == 32'hbeefbeef) else $error("Port B RAM1 Test Failed");

    pA_write(9'h100, 32'hc0ffeeee, 5);
    pA_read(9'h100, 5, data_outA);
    assert (data_outA == 32'hc0ffeeee) else $error("Pipelined Read/Write failed");

    pA_write(20, 32'hc0ffee, 4);
    pA_read(20, 4, data_outA);
    #1;
    assert (data_outA == 32'hc0ffee) else $error("Simulataneous Test Port A Failed, got %X", data_outA);
    #5;
    $finish();
  end

  always begin
    #43;
    pB_write(0, 32'hbeefdead, 4);
    pB_read(0, 4, data_outB);
    #5;
    assert (data_outB == 32'hbeefdead) else $error ("Simultaneous Test Port B Failed");
    #100;

  end

  initial #100000 $error("Timeout");

endmodule
