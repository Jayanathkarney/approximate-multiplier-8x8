// ===========================================================================
// Testbench for 8-bit Approximate Pipelined Wallace Tree Multiplier
// Single Mode Testing with Fixed Input Sets
// ===========================================================================

`timescale 1ns/1ps

module tb_approx_mult8b;

    // ===== CONFIGURATION PARAMETER =====
    // Change this value (0-4) for each compilation/run
    parameter TEST_MODE = 4;  // <<< CHANGE THIS FOR EACH RUN
    // ===================================

    // Testbench signals
    reg [7:0] A, B;
    reg [4:0] MODE;
    reg CLK;
    reg VDDI, GNDI;
    wire [15:0] Y;
    
    // Expected result for comparison
    reg [15:0] expected;
    integer error;
    integer total_tests;
    integer error_count;
    real total_error;
    integer max_error;
    
    // File handles for logging
    integer log_file;
    integer i;
    
    // Fixed test vectors (50 sets)
    reg [7:0] test_a [0:49];
    reg [7:0] test_b [0:49];
    
    // Instantiate DUT
    APPROX_MULT8B dut (
        .A(A),
        .B(B),
        .MODE(MODE),
        .CLK(CLK),
        .VDDI(VDDI),
        .GNDI(GNDI),
        .Y(Y)
    );
    
    // Clock generation (100 MHz = 10ns period)
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end
    
    // Power supply
    initial begin
        VDDI = 1;
        GNDI = 0;
    end
    
    // Initialize fixed test vectors
    initial begin
        // Corner cases
        test_a[0] = 8'd0;     test_b[0] = 8'd0;
        test_a[1] = 8'd0;     test_b[1] = 8'd255;
        test_a[2] = 8'd255;   test_b[2] = 8'd0;
        test_a[3] = 8'd255;   test_b[3] = 8'd255;
        test_a[4] = 8'd1;     test_b[4] = 8'd1;
        test_a[5] = 8'd128;   test_b[5] = 8'd128;
        
        // Fixed random-like values (same for all modes)
        test_a[6] = 8'd17;    test_b[6] = 8'd89;
        test_a[7] = 8'd234;   test_b[7] = 8'd12;
        test_a[8] = 8'd56;    test_b[8] = 8'd145;
        test_a[9] = 8'd199;   test_b[9] = 8'd73;
        test_a[10] = 8'd42;   test_b[10] = 8'd211;
        test_a[11] = 8'd167;  test_b[11] = 8'd34;
        test_a[12] = 8'd91;   test_b[12] = 8'd188;
        test_a[13] = 8'd223;  test_b[13] = 8'd67;
        test_a[14] = 8'd78;   test_b[14] = 8'd156;
        test_a[15] = 8'd145;  test_b[15] = 8'd99;
        test_a[16] = 8'd23;   test_b[16] = 8'd203;
        test_a[17] = 8'd189;  test_b[17] = 8'd45;
        test_a[18] = 8'd112;  test_b[18] = 8'd134;
        test_a[19] = 8'd201;  test_b[19] = 8'd81;
        test_a[20] = 8'd64;   test_b[20] = 8'd192;
        test_a[21] = 8'd178;  test_b[21] = 8'd56;
        test_a[22] = 8'd95;   test_b[22] = 8'd167;
        test_a[23] = 8'd212;  test_b[23] = 8'd39;
        test_a[24] = 8'd51;   test_b[24] = 8'd221;
        test_a[25] = 8'd156;  test_b[25] = 8'd93;
        test_a[26] = 8'd29;   test_b[26] = 8'd178;
        test_a[27] = 8'd243;  test_b[27] = 8'd14;
        test_a[28] = 8'd87;   test_b[28] = 8'd149;
        test_a[29] = 8'd134;  test_b[29] = 8'd105;
        test_a[30] = 8'd73;   test_b[30] = 8'd198;
        test_a[31] = 8'd209;  test_b[31] = 8'd62;
        test_a[32] = 8'd46;   test_b[32] = 8'd183;
        test_a[33] = 8'd167;  test_b[33] = 8'd118;
        test_a[34] = 8'd102;  test_b[34] = 8'd141;
        test_a[35] = 8'd230;  test_b[35] = 8'd27;
        test_a[36] = 8'd59;   test_b[36] = 8'd176;
        test_a[37] = 8'd195;  test_b[37] = 8'd84;
        test_a[38] = 8'd121;  test_b[38] = 8'd153;
        test_a[39] = 8'd248;  test_b[39] = 8'd36;
        test_a[40] = 8'd68;   test_b[40] = 8'd207;
        test_a[41] = 8'd184;  test_b[41] = 8'd91;
        test_a[42] = 8'd115;  test_b[42] = 8'd162;
        test_a[43] = 8'd237;  test_b[43] = 8'd49;
        test_a[44] = 8'd82;   test_b[44] = 8'd194;
        test_a[45] = 8'd159;  test_b[45] = 8'd127;
        test_a[46] = 8'd34;   test_b[46] = 8'd216;
        test_a[47] = 8'd203;  test_b[47] = 8'd75;
        test_a[48] = 8'd96;   test_b[48] = 8'd168;
        test_a[49] = 8'd225;  test_b[49] = 8'd53;
    end
    
    // Main test procedure
    initial begin
        // Create unique log file and VCD file for this mode
        log_file = $fopen($sformatf("multiplier_mode%0d_results.txt", TEST_MODE), "w");
        
        // Initialize
        A = 0;
        B = 0;
        MODE = TEST_MODE;
        total_tests = 0;
        error_count = 0;
        total_error = 0.0;
        max_error = 0;
        
        $display("========================================");
        $display("Testing Approximate Multiplier");
        $display("MODE = %b (%0d)", TEST_MODE, TEST_MODE);
        $display("========================================");
        
        $fwrite(log_file, "========================================\n");
        $fwrite(log_file, "Approximate Multiplier Test Results\n");
        $fwrite(log_file, "MODE = %b (%0d)\n", TEST_MODE, TEST_MODE);
        $fwrite(log_file, "========================================\n\n");
        
        // Wait for a few cycles
        repeat(5) @(posedge CLK);
        
        // Test all 50 fixed input sets
        for (i = 0; i < 50; i = i + 1) begin
            test_multiplication(test_a[i], test_b[i], TEST_MODE, i);
        end
        
        // Report statistics
        $display("\n========================================");
        $display("Test Summary for MODE %0d", TEST_MODE);
        $display("========================================");
        $display("Total tests: %0d", total_tests);
        $display("Total Errors: %0d", error_count);
        $display("Average Error: %0f", total_error / 50.0);
        $display("Max Error: %0d", max_error);
        $display("Error Rate: %0.2f%%", (error_count * 100.0) / 50.0);
        
        $fwrite(log_file, "\n========================================\n");
        $fwrite(log_file, "Test Summary for MODE %0d\n", TEST_MODE);
        $fwrite(log_file, "========================================\n");
        $fwrite(log_file, "Total tests: %0d\n", total_tests);
        $fwrite(log_file, "Total Errors: %0d\n", error_count);
        $fwrite(log_file, "Average Error: %0f\n", total_error / 50.0);
        $fwrite(log_file, "Max Error: %0d\n", max_error);
        $fwrite(log_file, "Error Rate: %0.2f%%\n", (error_count * 100.0) / 50.0);
        
        $display("\n========================================");
        $display("Test Completed Successfully!");
        $display("========================================");
        
        $fclose(log_file);
        #100;
        $finish;
    end
    
    // Task to test a single multiplication
    task test_multiplication;
        input [7:0] a_val;
        input [7:0] b_val;
        input [4:0] mode_val;
        input integer test_num;
        integer abs_error;
        begin
            A = a_val;
            B = b_val;
            MODE = mode_val;
            expected = a_val * b_val;
            
            // Wait for pipeline delay (3 cycles)
            @(posedge CLK);
            @(posedge CLK);
            @(posedge CLK);
            @(posedge CLK); // Extra cycle for output stabilization
            
            // Calculate error
            if (Y != expected) begin
                if (Y > expected)
                    abs_error = Y - expected;
                else
                    abs_error = expected - Y;
                    
                error = abs_error;
                error_count = error_count + 1;
                total_error = total_error + abs_error;
                
                if (abs_error > max_error)
                    max_error = abs_error;
                
                // Log all errors
                $display("  Test #%0d ERROR: A=%0d, B=%0d, Expected=%0d, Got=%0d, Error=%0d", 
                         test_num, a_val, b_val, expected, Y, abs_error);
                $fwrite(log_file, "  Test #%0d ERROR: A=%0d, B=%0d, Expected=%0d, Got=%0d, Error=%0d\n", 
                        test_num, a_val, b_val, expected, Y, abs_error);
            end else begin
                // Exact match
                $display("  Test #%0d PASS: A=%0d, B=%0d, Result=%0d", test_num, a_val, b_val, Y);
                $fwrite(log_file, "  Test #%0d PASS: A=%0d, B=%0d, Result=%0d\n", test_num, a_val, b_val, Y);
            end
            
            total_tests = total_tests + 1;
        end
    endtask
    
    // Waveform dumping with mode-specific filename
    initial begin
        $dumpfile($sformatf("approx_mult8b_mode%0d.vcd", TEST_MODE));
        $dumpvars(0, tb_approx_mult8b);
    end
    
    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
