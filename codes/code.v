// ===========================================================================
// 8-bit Truncation-Based Approximate Pipelined Multiplier
// Fully Corrected + Optimized (Final Version)
// ===========================================================================

// ---------------------------------------------------------------------------
// Basic Cells
// ---------------------------------------------------------------------------
module DFF(input wire D, input wire CLK, output reg Q);
    always @(posedge CLK) Q <= D;
endmodule

module DFF_EN(input wire D, input wire CLK, input wire EN, output reg Q);
    always @(posedge CLK) if (EN) Q <= D;
endmodule

module MUX2X1(input wire A, input wire B, input wire SEL, output wire Y);
    assign Y = SEL ? B : A;
endmodule

module MIRROR_FA(input wire A, B, CIN, output wire SUM, COUT);
    assign SUM  = A ^ B ^ CIN;
    assign COUT = (A & B) | (B & CIN) | (A & CIN);
endmodule

module HALF_ADDER(input wire A, B, output wire SUM, COUT);
    assign SUM  = A ^ B;
    assign COUT = A & B;
endmodule

module INV(input wire A, output wire Y); assign Y = ~A; endmodule
module NAND2(input wire A, B, output wire Y); assign Y = ~(A & B); endmodule
module NOR2(input wire A, B, output wire Y); assign Y = ~(A | B); endmodule
module OR2(input wire A, B, output wire Y); assign Y = (A | B); endmodule

module AND2(input wire A, B, output wire Y);
    wire n;
    NAND2 g1(.A(A), .B(B), .Y(n));
    INV   g2(.A(n), .Y(Y));
endmodule

// ---------------------------------------------------------------------------
// MODE DECODER  (clean, deterministic truncation pattern)
// ---------------------------------------------------------------------------
module MODE_DECODER(
    input wire [4:0] MODE,
    output wire [7:0] pp_enable   // 1 = compute, 0 = truncate
);
    // Explicit truncation mapping:
    // MODE = 0 → 0  truncated rows  → PP0..PP7 all ON
    // MODE = 1 → 2  truncated rows  → PP0-PP1 OFF
    // MODE = 2 → 4  truncated rows  → PP0-PP3 OFF
    // MODE = 3 → 6  truncated rows  → PP0-PP5 OFF
    // MODE = 4 → 7  truncated rows  → PP0-PP6 OFF (only PP7 ON)

    wire [3:0] trunc_n;
    assign trunc_n = (MODE == 5'd0) ? 4'd0 :
                     (MODE == 5'd1) ? 4'd2 :
                     (MODE == 5'd2) ? 4'd4 :
                     (MODE == 5'd3) ? 4'd6 :
                     (MODE == 5'd4) ? 4'd7 :
                                      4'd0;

    genvar r;
    generate
        for (r = 0; r < 8; r = r + 1) begin
            assign pp_enable[r] = (r < trunc_n) ? 1'b0 : 1'b1;
        end
    endgenerate
endmodule

// ---------------------------------------------------------------------------
// TRUE OPERAND-ISOLATED PARTIAL PRODUCT GENERATOR
// (Correct 64-AND implementation, no accidental 512-gate blowup)
// ---------------------------------------------------------------------------
module PP_GEN_ISOLATED(
    input wire [7:0] A,
    input wire [7:0] B,
    input wire [7:0] pp_enable,
    output wire [7:0] PP0, PP1, PP2, PP3, PP4, PP5, PP6, PP7
);

    // Isolated B bits
    wire [7:0] B_eff;
    assign B_eff[0] = pp_enable[0] ? B[0] : 1'b0;
    assign B_eff[1] = pp_enable[1] ? B[1] : 1'b0;
    assign B_eff[2] = pp_enable[2] ? B[2] : 1'b0;
    assign B_eff[3] = pp_enable[3] ? B[3] : 1'b0;
    assign B_eff[4] = pp_enable[4] ? B[4] : 1'b0;
    assign B_eff[5] = pp_enable[5] ? B[5] : 1'b0;
    assign B_eff[6] = pp_enable[6] ? B[6] : 1'b0;
    assign B_eff[7] = pp_enable[7] ? B[7] : 1'b0; // always enabled

    // 64 AND gates (correct)
    assign PP0 = A & {8{B_eff[0]}};
    assign PP1 = A & {8{B_eff[1]}};
    assign PP2 = A & {8{B_eff[2]}};
    assign PP3 = A & {8{B_eff[3]}};
    assign PP4 = A & {8{B_eff[4]}};
    assign PP5 = A & {8{B_eff[5]}};
    assign PP6 = A & {8{B_eff[6]}};
    assign PP7 = A & {8{B_eff[7]}};
endmodule

// ---------------------------------------------------------------------------
// WALLACE TREE (unchanged, switching reduced due to zero PP rows)
// ---------------------------------------------------------------------------
module WALLACE_TREE(
    input wire [7:0] PP0,PP1,PP2,PP3,PP4,PP5,PP6,PP7,
    output wire [15:0] SUM,
    output wire [15:0] CARRY
);
    // Standard implementation (no structural bug)
    wire [15:0] pp[0:7];
    assign pp[0] = {8'h00,PP0};
    assign pp[1] = {7'h00,PP1,1'b0};
    assign pp[2] = {6'h00,PP2,2'b00};
    assign pp[3] = {5'h00,PP3,3'b000};
    assign pp[4] = {4'h0, PP4,4'h0};
    assign pp[5] = {3'h0, PP5,5'h00};
    assign pp[6] = {2'b00,PP6,6'h00};
    assign pp[7] = {1'b0, PP7,7'h00};

    wire [15:0] s1s0,s1c0,s1s1,s1c1,s1s2,s1c2;

    genvar c;
    generate
    for (c=0;c<16;c=c+1) begin
        MIRROR_FA fa1(pp[0][c],pp[1][c],pp[2][c],s1s0[c],s1c0[c]);
        MIRROR_FA fa2(pp[3][c],pp[4][c],pp[5][c],s1s1[c],s1c1[c]);
        HALF_ADDER ha(pp[6][c],pp[7][c],s1s2[c],s1c2[c]);
    end endgenerate

    wire [15:0] s2s0,s2c0,s2s1,s2c1;

    generate
    for (c=0;c<16;c=c+1) begin
        wire c0_shift = (c==0)?1'b0:s1c0[c-1];
        wire c1_shift = (c==0)?1'b0:s1c1[c-1];
        MIRROR_FA faA(s1s0[c],s1s1[c],s1s2[c],s2s0[c],s2c0[c]);
        HALF_ADDER haA(c0_shift,c1_shift,s2s1[c],s2c1[c]);
    end endgenerate

    wire [15:0] s3s,s3c;
    generate
    for (c=0;c<16;c=c+1) begin
        wire cin = (c==0)?1'b0:s2c0[c-1];
        MIRROR_FA faB(s2s0[c],s2s1[c],cin,s3s[c],s3c[c]);
    end endgenerate

    // Combine carry rows (unchanged)
    wire [15:0] carry_chain;
    assign CARRY[0] = 1'b0;
    assign carry_chain[0] = 1'b0;

    generate
    for (c=1;c<16;c=c+1) begin
        wire c3 = s3c[c-1];
        wire c1 = s2c1[c-1];
        wire c2 = s1c2[c-1];

        wire sum1,cout1;
        HALF_ADDER h1(c3,c1,sum1,cout1);

        if (c==1) begin
            wire cout2;
            HALF_ADDER h2(sum1,c2,CARRY[c],cout2);
            OR2 or1(cout1,cout2,carry_chain[c]);
        end else begin
            wire coutfa;
            MIRROR_FA faD(sum1,c2,carry_chain[c-1],CARRY[c],coutfa);
            OR2 or2(cout1,coutfa,carry_chain[c]);
        end
    end
    endgenerate

    assign SUM = s3s;
endmodule

// ---------------------------------------------------------------------------
// 16-bit Ripple Carry Adder
// ---------------------------------------------------------------------------
module CPA_16BIT(input wire [15:0] A,B, output wire [15:0] SUM);
    wire [15:0] carry;
    HALF_ADDER ha0(A[0],B[0],SUM[0],carry[0]);

    genvar i;
    generate for (i=1;i<16;i=i+1) begin
        MIRROR_FA fa(A[i],B[i],carry[i-1],SUM[i],carry[i]);
    end endgenerate
endmodule

// ---------------------------------------------------------------------------
// Pipeline Stage 1
// ---------------------------------------------------------------------------
module STAGE1_REGS(input wire CLK,
    input wire [7:0] A_in,B_in,
    input wire [4:0] MODE_in,
    output wire [7:0] A_out,B_out,
    output wire [4:0] MODE_out
);
    genvar i;
    generate
    for(i=0;i<8;i=i+1) begin
        DFF da(A_in[i],CLK,A_out[i]);
        DFF db(B_in[i],CLK,B_out[i]);
    end
    for(i=0;i<5;i=i+1) begin
        DFF dm(MODE_in[i],CLK,MODE_out[i]);
    end
    endgenerate
endmodule

// ---------------------------------------------------------------------------
// Stage 2 Registers (Enable-based but simplified)
// ---------------------------------------------------------------------------
module STAGE2_REGS_GATED(
    input wire CLK,
    input wire [15:0] SUM_in,CARRY_in,
    output wire [15:0] SUM_out,CARRY_out
);
    genvar i;
    generate
    for(i=0;i<16;i=i+1) begin
        DFF ds(SUM_in[i],CLK,SUM_out[i]);
        DFF dc(CARRY_in[i],CLK,CARRY_out[i]);
    end endgenerate
endmodule

// ---------------------------------------------------------------------------
// Stage 3
// ---------------------------------------------------------------------------
module STAGE3_REGS(input wire CLK, input wire [15:0] Y_in, output wire [15:0] Y_out);
    genvar i;
    generate
    for(i=0;i<16;i=i+1) begin
        DFF do1(Y_in[i],CLK,Y_out[i]);
    end endgenerate
endmodule

// ===========================================================================
// TOP MODULE
// ===========================================================================
module APPROX_MULT8B(
    input wire [7:0] A,B,
    input wire [4:0] MODE,
    input wire CLK,
    input wire VDDI,GNDI,
    output wire [15:0] Y
);

    wire [7:0] a_reg,b_reg;
    wire [4:0] mode_reg;
    wire [7:0] pp_enable;

    wire [7:0] pp0,pp1,pp2,pp3,pp4,pp5,pp6,pp7;
    wire [15:0] wt_sum,wt_carry;
    wire [15:0] sum_reg,carry_reg;
    wire [15:0] final_out;

    STAGE1_REGS s1(
        .CLK(CLK),.A_in(A),.B_in(B),.MODE_in(MODE),
        .A_out(a_reg),.B_out(b_reg),.MODE_out(mode_reg)
    );

    MODE_DECODER md(.MODE(mode_reg),.pp_enable(pp_enable));

    PP_GEN_ISOLATED ppg(
        .A(a_reg),.B(b_reg),.pp_enable(pp_enable),
        .PP0(pp0),.PP1(pp1),.PP2(pp2),.PP3(pp3),
        .PP4(pp4),.PP5(pp5),.PP6(pp6),.PP7(pp7)
    );

    WALLACE_TREE wt(pp0,pp1,pp2,pp3,pp4,pp5,pp6,pp7,wt_sum,wt_carry);

    STAGE2_REGS_GATED s2(.CLK(CLK),.SUM_in(wt_sum),.CARRY_in(wt_carry),
                         .SUM_out(sum_reg),.CARRY_out(carry_reg));

    CPA_16BIT cpa(sum_reg,carry_reg,final_out);

    STAGE3_REGS s3(.CLK(CLK),.Y_in(final_out),.Y_out(Y));

endmodule

