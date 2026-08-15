// p13_seg_hex 判分 testbench：穷举 d(0..15) = 16 组
// 黄金模型用真值表 case 逐项给出，与 RTL 的三目链写法不同。
`timescale 1ns/1ps
module tb_seg_hex;

    logic [3:0] d;
    logic [6:0] seg;

    integer err;
    integer i_t;
    logic [6:0] gold;

    seg_hex dut(.d(d), .seg(seg));

    task automatic check(input [3:0] td);
        d = td;
        #1;
        case (td)
            4'd0:  gold = 7'b111_1110;
            4'd1:  gold = 7'b011_0000;
            4'd2:  gold = 7'b110_1101;
            4'd3:  gold = 7'b111_1001;
            4'd4:  gold = 7'b011_0011;
            4'd5:  gold = 7'b101_1011;
            4'd6:  gold = 7'b101_1111;
            4'd7:  gold = 7'b111_0000;
            4'd8:  gold = 7'b111_1111;
            4'd9:  gold = 7'b111_1011;
            4'ha:  gold = 7'b111_0111;
            4'hb:  gold = 7'b001_1111;
            4'hc:  gold = 7'b100_1110;
            4'hd:  gold = 7'b011_1101;
            4'he:  gold = 7'b100_1111;
            default: gold = 7'b100_0111;
        endcase
        if (seg !== gold) begin
            err = err + 1;
            if (err == 1)
                $display("JUDGE-MISMATCH: in=d=%0d got=%b want=%b",
                         td, seg, gold);
        end
    endtask

    initial begin
        err = 0;
        for (i_t = 0; i_t < 16; i_t = i_t + 1)
            check(i_t[3:0]);

        $display("JUDGE-COUNT: 16");
        if (err == 0)
            $display("JUDGE: PASS");
        else
            $display("JUDGE: FAIL %0d", err);
        $finish;
    end

endmodule