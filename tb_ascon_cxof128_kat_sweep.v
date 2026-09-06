`timescale 1ns / 1ps

module tb_ascon_cxof128_kat_sweep;

    localparam VECTOR_COUNT = 1089;

    reg         clk;
    reg         reset;
    reg         start;
    reg  [63:0] z_bits_len;
    reg  [15:0] custom_blocks_total;
    reg  [15:0] msg_blocks_total;
    reg  [15:0] out_blocks_total;
    reg  [63:0] custom_block_in;
    reg         custom_block_valid;
    wire        custom_block_ready;
    reg  [63:0] msg_block_in;
    reg         msg_block_valid;
    wire        msg_block_ready;
    wire [63:0] digest_block_out;
    wire        digest_block_valid;
    wire        busy;
    wire        done;

    integer vector_file;
    integer fields_read;
    integer vector_index;
    integer kat_count;
    integer custom_bytes;
    integer message_bytes;
    integer custom_count;
    integer message_count;
    integer digest_count;
    integer expected_digest_count;
    integer vector_errors;
    integer total_errors;
    integer i;
    integer start_cycle;
    integer done_cycle;
    integer operation_cycles;
    integer p12_count;
    integer case5_mode;
    real throughput_mbps;

    reg [63:0] custom_words [0:4];
    reg [63:0] message_words [0:4];
    reg [63:0] expected_words [0:7];
    reg [8*512-1:0] vector_path;

    ascon_cxof128_core uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .z_bits_len(z_bits_len),
        .custom_blocks_total(custom_blocks_total),
        .msg_blocks_total(msg_blocks_total),
        .out_blocks_total(out_blocks_total),
        .custom_block_in(custom_block_in),
        .custom_block_valid(custom_block_valid),
        .custom_block_ready(custom_block_ready),
        .msg_block_in(msg_block_in),
        .msg_block_valid(msg_block_valid),
        .msg_block_ready(msg_block_ready),
        .digest_block_out(digest_block_out),
        .digest_block_valid(digest_block_valid),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    function [63:0] kat_word;
        input [63:0] core_word;
        begin
            kat_word = {
                core_word[7:0],   core_word[15:8],
                core_word[23:16], core_word[31:24],
                core_word[39:32], core_word[47:40],
                core_word[55:48], core_word[63:56]
            };
        end
    endfunction

    task send_custom_block;
        input [63:0] block;
        begin
            @(posedge clk);
            wait (custom_block_ready);
            @(negedge clk);
            custom_block_in = block;
            custom_block_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            custom_block_valid = 1'b0;
            custom_block_in = 64'd0;
            @(posedge clk);
            wait (!custom_block_ready);
        end
    endtask

    task send_message_block;
        input [63:0] block;
        begin
            @(posedge clk);
            wait (msg_block_ready);
            @(negedge clk);
            msg_block_in = block;
            msg_block_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            msg_block_valid = 1'b0;
            msg_block_in = 64'd0;
            @(posedge clk);
            wait (!msg_block_ready);
        end
    endtask

    task run_loaded_vector;
        input integer out_bits;
        begin
            custom_blocks_total = custom_count;
            msg_blocks_total = message_count;
            out_blocks_total = out_bits / 64;
            digest_count = 0;
            vector_errors = 0;
            p12_count = 0;

            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            start_cycle = $time / 10;
            @(negedge clk);
            start = 1'b0;

            for (i = 0; i < custom_count; i = i + 1)
                send_custom_block(custom_words[i]);

            for (i = 0; i < message_count; i = i + 1)
                send_message_block(message_words[i]);

            wait (done);
            done_cycle = $time / 10;
            operation_cycles = done_cycle - start_cycle;
            if (message_bytes == 0)
                throughput_mbps = 0.0;
            else
                throughput_mbps =
                    (800.0 * message_bytes) / operation_cycles;

            $display(
                "PERF,count=%0d,z_bytes=%0d,msg_bytes=%0d,out_bits=%0d,start_cycle=%0d,done_cycle=%0d,cycles=%0d,p12_count=%0d,throughput_mbps=%0.6f",
                kat_count, custom_bytes, message_bytes, out_bits,
                start_cycle, done_cycle, operation_cycles, p12_count,
                throughput_mbps
            );
            @(posedge clk);

            if (digest_count != expected_digest_count) begin
                $display("FAIL Count %0d: expected %0d digest blocks, got %0d",
                         kat_count, expected_digest_count, digest_count);
                vector_errors = vector_errors + 1;
            end

            if (vector_errors != 0)
                total_errors = total_errors + vector_errors;
        end
    endtask

    always @(posedge clk) begin
        if (uut.perm_start)
            p12_count = p12_count + 1;

        if (digest_block_valid) begin
            if (case5_mode)
                $display("DIGEST,count=%0d,block=%0d,value=%h",
                         kat_count, digest_count + 1,
                         kat_word(digest_block_out));

            if (digest_count >= expected_digest_count) begin
                $display("FAIL Count %0d: extra digest block %h",
                         kat_count, kat_word(digest_block_out));
                vector_errors = vector_errors + 1;
            end else if (kat_word(digest_block_out) !== expected_words[digest_count]) begin
                $display("FAIL Count %0d block %0d: expected %h got %h",
                         kat_count, digest_count + 1,
                         expected_words[digest_count],
                         kat_word(digest_block_out));
                vector_errors = vector_errors + 1;
            end
            digest_count = digest_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        start = 1'b0;
        z_bits_len = 64'd0;
        custom_blocks_total = 16'd0;
        msg_blocks_total = 16'd0;
        out_blocks_total = 16'd8;
        custom_block_in = 64'd0;
        custom_block_valid = 1'b0;
        msg_block_in = 64'd0;
        msg_block_valid = 1'b0;
        digest_count = 0;
        expected_digest_count = 8;
        vector_errors = 0;
        total_errors = 0;
        p12_count = 0;
        case5_mode = 0;

        if ($test$plusargs("CASE5_ONLY")) begin
            case5_mode = 1;
            #20;
            reset = 1'b0;
            @(posedge clk);

            // Thesis case 5 / long streaming regression:
            // Z = "V2X", M = 4 raw 64-bit data blocks, output = 256 bits.
            kat_count = 5;
            custom_bytes = 3;
            message_bytes = 32;
            z_bits_len = 64'd24;
            custom_count = 1;
            message_count = 5;
            expected_digest_count = 4;

            custom_words[0] = 64'h0000000001583256;
            custom_words[1] = 64'd0;
            custom_words[2] = 64'd0;
            custom_words[3] = 64'd0;
            custom_words[4] = 64'd0;

            message_words[0] = 64'h8877665544332211;
            message_words[1] = 64'h00ffeeddccbbaa99;
            message_words[2] = 64'h0123456789abcdef;
            message_words[3] = 64'hfedcba9876543210;
            message_words[4] = 64'h0000000000000001;

            expected_words[0] = 64'h9e3bfbc01885b1bb;
            expected_words[1] = 64'h02842182cac48a1e;
            expected_words[2] = 64'h4d781391389a7a8f;
            expected_words[3] = 64'he72b2fd4a76ca99d;
            expected_words[4] = 64'h0000000000000000;
            expected_words[5] = 64'h0000000000000000;
            expected_words[6] = 64'h0000000000000000;
            expected_words[7] = 64'h0000000000000000;

            $display("CASE5_INFO,z_hex=563258,z_ascii=V2X,z_bytes=3,msg_bytes=32,out_bits=256");
            run_loaded_vector(256);
            if (total_errors == 0)
                $display("PASS: ASCON-CXOF128 case 5 matched expected digest.");
            else
                $display("FAIL: ASCON-CXOF128 case 5 had %0d errors.",
                         total_errors);
            $finish;
        end

        vector_path =
            "../../../../project_1.srcs/sim_1/new/cxof_kat_vectors.mem";
        if ($value$plusargs("KAT_FILE=%s", vector_path))
            $display("Using KAT vectors from %0s", vector_path);

        vector_file = $fopen(vector_path, "r");
        if (vector_file == 0) begin
            $display("FAIL: cannot open KAT vector file %0s", vector_path);
            $finish;
        end

        #20;
        reset = 1'b0;
        @(posedge clk);

        for (vector_index = 0; vector_index < VECTOR_COUNT;
             vector_index = vector_index + 1) begin
            fields_read = $fscanf(
                vector_file,
                "%d %d %d %d %d %h %h %h %h %h %d %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                kat_count,
                custom_bytes,
                message_bytes,
                z_bits_len,
                custom_count,
                custom_words[0], custom_words[1], custom_words[2],
                custom_words[3], custom_words[4],
                message_count,
                message_words[0], message_words[1], message_words[2],
                message_words[3], message_words[4],
                expected_words[0], expected_words[1], expected_words[2],
                expected_words[3], expected_words[4], expected_words[5],
                expected_words[6], expected_words[7]
            );

            if (fields_read != 24) begin
                $display("FAIL: parsed %0d fields for vector index %0d",
                         fields_read, vector_index);
                $finish;
            end

            custom_blocks_total = custom_count;
            msg_blocks_total = message_count;
            out_blocks_total = 16'd8;
            digest_count = 0;
            expected_digest_count = 8;
            vector_errors = 0;
            p12_count = 0;

            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            start_cycle = $time / 10;
            @(negedge clk);
            start = 1'b0;

            for (i = 0; i < custom_count; i = i + 1)
                send_custom_block(custom_words[i]);

            for (i = 0; i < message_count; i = i + 1)
                send_message_block(message_words[i]);

            wait (done);
            done_cycle = $time / 10;
            operation_cycles = done_cycle - start_cycle;
            if (message_bytes == 0)
                throughput_mbps = 0.0;
            else
                throughput_mbps =
                    (800.0 * message_bytes) / operation_cycles;

            $display(
                "PERF,count=%0d,z_bytes=%0d,msg_bytes=%0d,out_bits=512,start_cycle=%0d,done_cycle=%0d,cycles=%0d,throughput_mbps=%0.6f",
                kat_count, custom_bytes, message_bytes,
                start_cycle, done_cycle, operation_cycles,
                throughput_mbps
            );
            @(posedge clk);

            if (digest_count != 8) begin
                $display("FAIL Count %0d: expected 8 digest blocks, got %0d",
                         kat_count, digest_count);
                vector_errors = vector_errors + 1;
            end

            if (vector_errors != 0)
                total_errors = total_errors + vector_errors;
            else if ((kat_count % 100) == 0)
                $display("PASS through Count %0d", kat_count);

            @(posedge clk);
        end

        $fclose(vector_file);
        $display("Completed %0d ASCON-CXOF128 KAT vectors.", VECTOR_COUNT);
        $display("Total errors: %0d", total_errors);
        if (total_errors == 0)
            $display("PASS: complete ASCON-CXOF128 KAT sweep matched.");
        else
            $display("FAIL: complete ASCON-CXOF128 KAT sweep had %0d errors.",
                     total_errors);
        $finish;
    end

    initial begin
        #20000000;
        $display("TIMEOUT at Count %0d after %0d vectors.",
                 kat_count, vector_index);
        $display("state=%0d busy=%b done=%b custom_ready=%b msg_ready=%b",
                 uut.state, busy, done, custom_block_ready, msg_block_ready);
        $display("custom_remaining=%0d msg_remaining=%0d digest_count=%0d",
                 uut.custom_remaining, uut.msg_remaining, digest_count);
        $finish;
    end

endmodule
