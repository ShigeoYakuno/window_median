`timescale 1ns/1ps

module tb_median_filter;

    // Parameters
    localparam int DATA_WIDTH = 16;
    localparam real CLK_PERIOD = 10.0; // 100MHz
    localparam real SAMPLE_PERIOD = 300.0; // For simulation acceleration
    localparam int DEPTH = 15;
    localparam int MEDIAN_INDEX = DEPTH / 2;

    // Signals
    logic ck100m;
    logic srst_n;
    logic enable;
    logic [DATA_WIDTH-1:0] in;
    logic [DATA_WIDTH-1:0] out;
    logic out_enable;

    // DUT
    median_filter_resource_optimized dut (
        .ck100m    (ck100m),
        .srst_n    (srst_n),
        .enable    (enable),
        .in        (in),
        .out       (out),
        .out_enable(out_enable)
    );

    // Clock generation
    initial begin
        ck100m = 0;
        forever #(CLK_PERIOD/2) ck100m = ~ck100m;
    end

    // File handles
    integer input_file;
    integer output_file;
    integer read_data;
    integer scan_status;

    // Sample counter
    integer sample_index;

    // Logging control
    logic log_enable;

    // Snapshot for logging
    logic [DATA_WIDTH-1:0] window_snapshot [0:DEPTH-1];
    logic [DATA_WIDTH-1:0] median_snapshot;
    logic [DATA_WIDTH-1:0] in_snapshot;
    integer sample_snapshot;

    // Initialization and stimulus
    initial begin
        input_file = $fopen("C:/users/yakun/screen/sim/window_median/input.txt", "r");
        if (input_file == 0) begin
            $display("ERROR: Failed to open input.txt.");
            $finish;
        end

        output_file = $fopen("C:/users/yakun/screen/sim/window_median/output_w.txt", "w");
        if (output_file == 0) begin
            $display("ERROR: Failed to create output.txt.");
            $finish;
        end

        srst_n = 0;
        enable = 0;
        in = 0;
        sample_index = 0;
        log_enable = 0;

        repeat(100) @(posedge ck100m);
        srst_n = 1;
        $display("Reset deasserted");

        // Feed input data
        while (!$feof(input_file)) begin
            scan_status = $fscanf(input_file, "%d", read_data);
            if (scan_status == 1) begin
                #(SAMPLE_PERIOD);
                @(posedge ck100m);
                in <= read_data;
                enable <= 1;
                sample_index++;
            end
            @(posedge ck100m);
            enable <= 0;
        end
        $display("All input data sent");
        #(SAMPLE_PERIOD * 20);
        $fclose(input_file);
        $fclose(output_file);
        $display("Simulation finished");
        $finish;
    end

    // Output logging
    always @(posedge ck100m) begin
        if (srst_n && out_enable) begin
            $fdisplay(output_file, "%d", out);
        end
    end

endmodule
