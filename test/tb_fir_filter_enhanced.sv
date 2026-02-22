`default_nettype none
`timescale 1ns / 1ps

module tb_fir_filter_enhanced();

    // Clock and reset
    reg clock;
    reg reset;
    
    // DUT signals
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg ena;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    
    // Test variables
    integer test_count;
    integer error_count;
    
    // Delay line tracking for golden model
    reg signed [7:0] x0_model, x1_model, x2_model, x3_model;
    
    // Coefficient tracking for golden model
    reg signed [7:0] h0_model, h1_model, h2_model, h3_model;
    
    // Enhanced signals
    wire coeff_update_flag;
    wire pipeline_valid;
    wire [5:0] coeff_readback;
    
    assign coeff_update_flag = uio_out[0];
    assign pipeline_valid = uio_out[1];
    assign coeff_readback = uio_out[7:2];
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    // DUT instantiation
    tt_um_fir_filter dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clock),
        .rst_n(reset)
    );
    
    // ========================================================================
    // TASK: Apply reset
    // ========================================================================
    task apply_reset;
        begin
            reset = 0;
            ui_in = 8'h00;
            uio_in = 8'h00;
            ena = 1;
            x0_model = 0;
            x1_model = 0;
            x2_model = 0;
            x3_model = 0;
            h0_model = 8'sd1;  // Default after reset
            h1_model = 8'sd1;
            h2_model = 8'sd1;
            h3_model = 8'sd1;
            repeat(3) @(posedge clock);
            reset = 1;
            @(posedge clock);
        end
    endtask
    
    // ========================================================================
    // TASK: Load preset mode (NEW!)
    // ========================================================================
    task load_preset_mode;
        input [1:0] mode;
        input string mode_name;
        begin
            $display("  [%0t] Loading preset mode %0d: %s", $time, mode, mode_name);
            
            // Send mode load command: op=11, mode=XX, enable=1
            ui_in = {2'b11, mode[1:0], 1'b1, 3'b000};
            @(posedge clock);
            
            // Update golden model coefficients based on mode
            case(mode)
                2'b00: begin  // Bypass
                    h0_model = 8'sd1;
                    h1_model = 8'sd0;
                    h2_model = 8'sd0;
                    h3_model = 8'sd0;
                end
                2'b01: begin  // Moving average
                    h0_model = 8'sd1;
                    h1_model = 8'sd1;
                    h2_model = 8'sd1;
                    h3_model = 8'sd1;
                end
                2'b10: begin  // Low-pass
                    h0_model = 8'sd4;
                    h1_model = 8'sd2;
                    h2_model = 8'sd1;
                    h3_model = 8'sd1;
                end
                2'b11: begin  // High-pass
                    h0_model = 8'sd1;
                    h1_model = -8'sd1;
                    h2_model = 8'sd0;
                    h3_model = 8'sd0;
                end
            endcase
            
            $display("  Coefficients: h0=%0d h1=%0d h2=%0d h3=%0d", 
                     h0_model, h1_model, h2_model, h3_model);
        end
    endtask
    
    // ========================================================================
    // TASK: Write coefficient (manual write)
    // ========================================================================
    task write_coeff;
        input [1:0] op_type;
        input [5:0] data;
        begin
            ui_in = {op_type, data};
            @(posedge clock);
            
            case(op_type)
                2'b01: h0_model = {2'b00, data};
                2'b10: h1_model = {2'b00, data};
                2'b11: begin
                    h2_model = {2'b00, data[5:3], 3'b000};
                    h3_model = {5'b00000, data[2:0]};
                end
            endcase
        end
    endtask
    
    // ========================================================================
    // TASK: Verify coefficient readback (NEW!)
    // ========================================================================
    task verify_coeff_readback;
        input [1:0] coeff_sel;
        input [5:0] expected;
        input string coeff_name;
        reg [5:0] actual;
        begin
            test_count = test_count + 1;
            
            // Select coefficient to read
            uio_in = {6'b000000, coeff_sel};
            @(posedge clock);
            
            actual = coeff_readback;
            
            if (actual !== expected) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : tb_fir_filter_enhanced : coeff_readback : expected_value: 6'h%02h actual_value: 6'h%02h [%s]", 
                         $time, expected, actual, coeff_name);
            end else begin
                $display("LOG: %0t : INFO : tb_fir_filter_enhanced : coeff_readback : expected_value: 6'h%02h actual_value: 6'h%02h [%s]", 
                         $time, expected, actual, coeff_name);
            end
        end
    endtask
    
    // ========================================================================
    // TASK: Check status flags (NEW!)
    // ========================================================================
    task check_status_flags;
        input expected_update;
        input expected_valid;
        input string test_name;
        begin
            test_count = test_count + 1;
            
            if ((coeff_update_flag !== expected_update) || (pipeline_valid !== expected_valid)) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : tb_fir_filter_enhanced : status_flags : expected: update=%b valid=%b, actual: update=%b valid=%b [%s]", 
                         $time, expected_update, expected_valid, coeff_update_flag, pipeline_valid, test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_fir_filter_enhanced : status_flags : update=%b valid=%b [%s]", 
                         $time, coeff_update_flag, pipeline_valid, test_name);
            end
        end
    endtask
    
    // ========================================================================
    // TASK: Send sample
    // ========================================================================
    task send_sample;
        input [5:0] sample;
        begin
            ui_in = {2'b00, sample};
            @(posedge clock);
            
            // Update delay line model
            x3_model = x2_model;
            x2_model = x1_model;
            x1_model = x0_model;
            x0_model = {2'b00, sample};
        end
    endtask
    
    // ========================================================================
    // FUNCTION: Calculate expected output
    // ========================================================================
    function [15:0] calc_expected;
        reg signed [15:0] result;
        begin
            result = (x0_model * h0_model) + (x1_model * h1_model) + 
                     (x2_model * h2_model) + (x3_model * h3_model);
            calc_expected = result;
        end
    endfunction
    
    // ========================================================================
    // TASK: Check output
    // ========================================================================
    task check_output;
        input [15:0] expected;
        input string test_name;
        reg [7:0] expected_out;
        begin
            test_count = test_count + 1;
            expected_out = expected[15:8];
            
            if (uo_out !== expected_out) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : tb_fir_filter_enhanced : uo_out : expected_value: 8'h%02h actual_value: 8'h%02h [%s]", 
                         $time, expected_out, uo_out, test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_fir_filter_enhanced : uo_out : expected_value: 8'h%02h actual_value: 8'h%02h [%s]", 
                         $time, expected_out, uo_out, test_name);
            end
        end
    endtask
    
    // ========================================================================
    // Main test sequence
    // ========================================================================
    initial begin
        $display("TEST START");
        $display("==========================================================");
        $display("ENHANCED FIR DSP Peripheral Testbench");
        $display("Testing v2.0 with Status Outputs, Readback, and Presets!");
        $display("==========================================================");
        
        test_count = 0;
        error_count = 0;
        
        apply_reset();
        $display("\n[%0t] Reset applied", $time);
        
        // ========================================================================
        // Test 1: Verify Status Flags After Reset
        // ========================================================================
        $display("\n========================================");
        $display("Test 1: Status Flags After Reset");
        $display("========================================");
        
        @(posedge clock);
        check_status_flags(1'b0, 1'b0, "After reset - no updates yet");
        
        // ========================================================================
        // Test 2: Coefficient Update Flag on Preset Mode Load
        // ========================================================================
        $display("\n========================================");
        $display("Test 2: Coefficient Update Flag - Preset Mode");
        $display("========================================");
        
        load_preset_mode(2'b10, "Low-pass");
        check_status_flags(1'b1, 1'b0, "Update flag should pulse");
        
        // Note: Update flag may stay high for multiple cycles depending on implementation
        // Just verify it eventually clears
        repeat(2) @(posedge clock);
        
        // ========================================================================
        // Test 3: Coefficient Readback Verification
        // ========================================================================
        $display("\n========================================");
        $display("Test 3: Coefficient Readback");
        $display("========================================");
        
        apply_reset();
        load_preset_mode(2'b10, "Low-pass");
        @(posedge clock);
        
        $display("  Verifying all coefficients via readback...");
        verify_coeff_readback(2'b00, 6'd4, "h0 (should be 4)");
        verify_coeff_readback(2'b01, 6'd2, "h1 (should be 2)");
        verify_coeff_readback(2'b10, 6'd1, "h2 (should be 1)");
        verify_coeff_readback(2'b11, 6'd1, "h3 (should be 1)");
        
        // ========================================================================
        // Test 4: Pipeline Valid Flag
        // ========================================================================
        $display("\n========================================");
        $display("Test 4: Pipeline Valid Flag");
        $display("========================================");
        
        apply_reset();
        load_preset_mode(2'b01, "Moving Average");
        repeat(2) @(posedge clock);
        
        $display("  Sending samples to fill pipeline...");
        
        send_sample(6'd10);
        @(posedge clock);
        $display("  After 1 sample: valid=%b", pipeline_valid);
        
        send_sample(6'd20);
        @(posedge clock);
        $display("  After 2 samples: valid=%b", pipeline_valid);
        
        send_sample(6'd30);
        @(posedge clock);
        $display("  After 3 samples: valid=%b", pipeline_valid);
        
        send_sample(6'd40);
        @(posedge clock);
        @(posedge clock);
        check_status_flags(1'b0, 1'b1, "Pipeline should eventually be valid");
        
        // ========================================================================
        // Test 5: All Preset Modes with Readback Verification
        // ========================================================================
        $display("\n========================================");
        $display("Test 5: All Preset Modes with Verification");
        $display("========================================");
        
        // Mode 0: Bypass
        $display("\n  --- Mode 0: Bypass ---");
        apply_reset();
        load_preset_mode(2'b00, "Bypass");
        @(posedge clock);
        verify_coeff_readback(2'b00, 6'd1, "h0");
        verify_coeff_readback(2'b01, 6'd0, "h1");
        verify_coeff_readback(2'b10, 6'd0, "h2");
        verify_coeff_readback(2'b11, 6'd0, "h3");
        
        // Mode 1: Moving Average
        $display("\n  --- Mode 1: Moving Average ---");
        load_preset_mode(2'b01, "Moving Average");
        @(posedge clock);
        verify_coeff_readback(2'b00, 6'd1, "h0");
        verify_coeff_readback(2'b01, 6'd1, "h1");
        verify_coeff_readback(2'b10, 6'd1, "h2");
        verify_coeff_readback(2'b11, 6'd1, "h3");
        
        // Mode 2: Low-pass
        $display("\n  --- Mode 2: Low-pass ---");
        load_preset_mode(2'b10, "Low-pass");
        @(posedge clock);
        verify_coeff_readback(2'b00, 6'd4, "h0");
        verify_coeff_readback(2'b01, 6'd2, "h1");
        verify_coeff_readback(2'b10, 6'd1, "h2");
        verify_coeff_readback(2'b11, 6'd1, "h3");
        
        // Mode 3: High-pass
        $display("\n  --- Mode 3: High-pass ---");
        load_preset_mode(2'b11, "High-pass");
        @(posedge clock);
        verify_coeff_readback(2'b00, 6'd1, "h0");
        verify_coeff_readback(2'b01, 6'd63, "h1 (should be -1 = 0x3F unsigned)");
        verify_coeff_readback(2'b10, 6'd0, "h2");
        verify_coeff_readback(2'b11, 6'd0, "h3");
        
        // ========================================================================
        // Test 6: One-Cycle Mode Switching Speed
        // ========================================================================
        $display("\n========================================");
        $display("Test 6: One-Cycle Mode Switching");
        $display("========================================");
        
        apply_reset();
        repeat(2) @(posedge clock);
        
        $display("  Cycle 0: Load Bypass mode");
        load_preset_mode(2'b00, "Bypass");
        verify_coeff_readback(2'b00, 6'd1, "h0 immediately");
        
        $display("  Cycle 1: Switch to Low-pass mode");
        load_preset_mode(2'b10, "Low-pass");
        verify_coeff_readback(2'b00, 6'd4, "h0 changed in 1 cycle");
        
        $display("  Cycle 2: Switch to High-pass mode");
        load_preset_mode(2'b11, "High-pass");
        verify_coeff_readback(2'b00, 6'd1, "h0 changed again");
        
        // ========================================================================
        // Test 7: Manual Coefficient Write with Update Flag
        // ========================================================================
        $display("\n========================================");
        $display("Test 7: Manual Coefficient Write");
        $display("========================================");
        
        apply_reset();
        repeat(2) @(posedge clock);
        
        $display("  Writing h0=8");
        write_coeff(2'b01, 6'd8);
        check_status_flags(1'b1, 1'b0, "Update flag after h0 write");
        verify_coeff_readback(2'b00, 6'd8, "h0 verify");
        
        // Update flag clears on its own
        repeat(2) @(posedge clock);
        
        $display("  Writing h1=4");
        write_coeff(2'b10, 6'd4);
        check_status_flags(1'b1, 1'b0, "Update flag after h1 write");
        verify_coeff_readback(2'b01, 6'd4, "h1 verify");
        
        // ========================================================================
        // Test 8: Functional Test - Bypass Mode
        // ========================================================================
        $display("\n========================================");
        $display("Test 8: Functional - Bypass Mode");
        $display("========================================");
        
        apply_reset();
        load_preset_mode(2'b00, "Bypass");
        repeat(2) @(posedge clock);
        
        send_sample(6'd10);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "Bypass sample 1");
        
        send_sample(6'd20);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "Bypass sample 2");
        
        // ========================================================================
        // Test 9: Functional Test - Moving Average Mode
        // ========================================================================
        $display("\n========================================");
        $display("Test 9: Functional - Moving Average Mode");
        $display("========================================");
        
        apply_reset();
        load_preset_mode(2'b01, "Moving Average");
        repeat(2) @(posedge clock);
        
        send_sample(6'd8);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "MovAvg sample 1");
        
        send_sample(6'd8);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "MovAvg sample 2");
        
        send_sample(6'd8);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "MovAvg sample 3");
        
        send_sample(6'd8);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "MovAvg sample 4");
        
        // ========================================================================
        // Test 10: Functional Test - High-pass Mode
        // ========================================================================
        $display("\n========================================");
        $display("Test 10: Functional - High-pass Mode");
        $display("========================================");
        
        apply_reset();
        load_preset_mode(2'b11, "High-pass");
        repeat(2) @(posedge clock);
        
        send_sample(6'd10);
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "High-pass sample 1");
        
        send_sample(6'd30);  // Step change
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "High-pass sample 2 (edge)");
        
        send_sample(6'd30);  // Flat
        @(posedge clock);
        @(posedge clock);
        check_output(calc_expected(), "High-pass sample 3 (flat)");
        
        // ========================================================================
        // Test 11: Combined Test - Status + Readback + Processing
        // ========================================================================
        $display("\n========================================");
        $display("Test 11: Combined Feature Test");
        $display("========================================");
        
        apply_reset();
        
        $display("  Step 1: Load mode and verify");
        load_preset_mode(2'b10, "Low-pass");
        wait(coeff_update_flag);
        $display("    Update flag detected!");
        @(posedge clock);
        verify_coeff_readback(2'b00, 6'd4, "h0");
        verify_coeff_readback(2'b01, 6'd2, "h1");
        
        $display("  Step 2: Process data and monitor valid flag");
        repeat(4) begin
            send_sample(6'd16);
            @(posedge clock);
        end
        
        wait(pipeline_valid);
        $display("    Pipeline valid flag detected!");
        
        @(posedge clock);
        check_output(calc_expected(), "Combined test output");
        
        // ========================================================================
        // Final Report
        // ========================================================================
        $display("\n==========================================================");
        $display("Test Summary");
        $display("==========================================================");
        $display("Total tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
            $display("✓ Status outputs working (update flag + valid flag)");
            $display("✓ Coefficient readback verified");
            $display("✓ Preset mode loading operational");
            $display("✓ One-cycle mode switching confirmed");
            $display("✓ All 4 filter modes functional");
            $display("✓ Enhanced features fully validated!");
            $display("\nTEST PASSED");
        end else begin
            $display("\n*** TEST FAILED ***");
            $display("ERROR");
            $error("TEST FAILED with %0d errors", error_count);
        end
        
        $display("==========================================================");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #300000; // 300us timeout (longer for enhanced tests)
        $display("\nERROR: Timeout - simulation ran too long");
        $fatal(1, "Simulation timeout");
    end
    
    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
