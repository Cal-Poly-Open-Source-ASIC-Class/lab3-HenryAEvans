`timescale 1ns/1ps

module dual_port (
  input           clk_i,
  input           rst_ni,
  input   [9:0]   pA_wb_addr_i,
  input   [9:0]   pB_wb_addr_i,
  input           pA_wb_stb_i,
  input           pB_wb_stb_i,
  input           pA_wb_we_i,
  input           pB_wb_we_i,
  input   [31:0]  pA_wb_data_i,
  input   [31:0]  pB_wb_data_i,

  output  logic   pA_wb_ack_o,
  output  logic   pB_wb_ack_o,
  output          pA_wb_stall_o,
  output          pB_wb_stall_o,
  output  [31:0]  pA_wb_data_o,
  output  [31:0]  pB_wb_data_o
  );

  logic ram1_we, ram1_en, ram2_we, ram2_en;
  logic [31:0] ram1_din, ram1_dout, ram2_din, ram2_dout;
  logic [8:0] ram1_addr, ram2_addr;

  DFFRAM512x32 ram1 (
      .CLK(clk_i),
      .WE0({4{ram1_we}}),
      .EN0(ram1_en),
      .Di0(ram1_din),
      .Do0(ram1_dout),
      .A0(ram1_addr)
    );

  DFFRAM512x32 ram2 (
      .CLK(clk_i),
      .WE0({4{ram2_we}}),
      .EN0(ram2_en),
      .Di0(ram2_din),
      .Do0(ram2_dout),
      .A0(ram2_addr)
    );

    // async buffers for storing inputs

    logic [9:0] pA_addr;

    async_buffer #(.WIDTH(10)) pA_addr_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pA_wb_stb_i),
      .data_i(pA_wb_addr_i),
      .data_o(pA_addr)
      );

    logic [9:0] pB_addr;
    async_buffer #(.WIDTH(10)) pB_addr_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pB_wb_stb_i),
      .data_i(pB_wb_addr_i),
      .data_o(pB_addr)
      );

    logic [31:0] pA_data;
    async_buffer #(.WIDTH(32)) pA_data_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pA_wb_stb_i),
      .data_i(pA_wb_data_i),
      .data_o(pA_data)
      );

    logic [31:0] pB_data;
    async_buffer #(.WIDTH(32)) pB_data_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pB_wb_stb_i),
      .data_i(pB_wb_data_i),
      .data_o(pB_data)
      );

    logic pA_we;
    async_buffer #(.WIDTH(1)) pA_we_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pA_wb_stb_i),
      .data_i(pA_wb_we_i),
      .data_o(pA_we)
      );

    logic pB_we;
    async_buffer #(.WIDTH(1)) pB_we_buff (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .valid_i(pB_wb_stb_i),
      .data_i(pB_wb_we_i),
      .data_o(pB_we)
      );

    logic contention;
    logic last_access;
    logic pA_access, pB_access;
    logic pA_busy, pA_busy_reg, pB_busy, pB_busy_reg;

    assign pA_wb_stall_o = contention && pA_busy && !last_access;
    assign pB_wb_stall_o = contention && pB_busy && last_access;

    assign pA_access = pA_busy && !pA_wb_stall_o;
    assign pB_access = pB_busy && !pB_wb_stall_o;

    always_ff @(posedge clk_i) begin
      if (rst_ni) begin
        pA_busy_reg <= 0;
        pB_busy_reg <= 0;
    end else begin
      if (pA_access) begin
        pA_busy_reg <= 0;
      end else if (pA_wb_stb_i) begin
        pA_busy_reg <= 1;
      end
      if (pB_access) begin
        pB_busy_reg <= 0;
      end else if (pB_wb_stb_i) begin
        pB_busy_reg <= 1;
      end
    end
    end

    assign pA_busy = pA_wb_stb_i ? 1 : pA_busy_reg;
    assign pB_busy = pB_wb_stb_i ? 1 : pB_busy_reg;

    assign contention = pA_busy && pB_busy && (pA_wb_addr_i[9] == pB_wb_addr_i[9]);


    logic ram1_mux_in, ram2_mux_in;

    // mux between ports for data in and address
    assign ram1_din = ram1_mux_in ? pB_data : pA_data;
    assign ram1_addr = ram1_mux_in ? pB_addr[8:0] : pA_addr[8:0];
    assign ram2_din = ram2_mux_in ? pB_data : pA_data;
    assign ram2_addr = ram2_mux_in ? pB_addr[8:0] : pA_addr[8:0];

    // mux between output ports
    logic pA_mux_out, pB_mux_out;
    assign pA_wb_data_o = pA_mux_out ? ram2_dout : ram1_dout;
    assign pB_wb_data_o = pB_mux_out ? ram2_dout : ram1_dout;

    // enable RAMs when requested
    assign ram1_en = (pA_busy && !pA_addr[9])          || (pB_busy && !pB_addr[9]);
    assign ram1_we = (pA_busy && !pA_addr[9] && pA_we) || (pB_busy && !pB_addr[9] && pA_we);
    assign ram2_en = (pA_busy && pA_addr[9])           || (pB_busy && pB_addr[9]);
    assign ram2_we = (pA_busy && pA_addr[9] && pA_we)  || (pB_busy && pB_addr[9] && pA_we);


    // track the last port that was allowed access during contention
    always_ff @(posedge clk_i) begin
      if (rst_ni) begin
        last_access <= 0;
      end else if (contention && pA_access) begin
        last_access <= 0;
      end else if (contention && pB_access) begin
        last_access <= 1;
      end
    end

    // register access signals to get ACK signals
    always_ff @(posedge clk_i) begin
      if (rst_ni) begin
        pA_wb_ack_o <= 0;
        pB_wb_ack_o <= 0;
      end else begin
        pA_wb_ack_o <= pA_access;
        pB_wb_ack_o <= pB_access;
      end
    end

    // save the last RAM accessed for each port
    always_ff @(posedge clk_i) begin
      if (rst_ni) begin
        pA_mux_out <= 0;
        pB_mux_out <= 0;
      end else begin
        if (pA_access) begin
          pA_mux_out <= pA_addr[9];
        end
        if (pB_access) begin
          pB_mux_out <= pB_addr[9];
        end
      end
    end

    // Mux RAMs between the two ports
    assign ram1_mux_in = pB_access && !pB_addr[9];
    assign ram2_mux_in = pB_access && pB_addr[9];

endmodule
