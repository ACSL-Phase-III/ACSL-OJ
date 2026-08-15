// p10_decoder3_8 判分 testbench：穷举 a(0..7) = 8 组
// 黄金模型用移位实现 y = 1 << a，与 RTL 的最小项写法不同。
`timescale 1ns/1ps
module tb_decoder3_8;

    logic [2:0] a;
    logic [7:0] y;

    integer err;
    integer i_t;
    logic [7:0] gold;

    decoder3_8 dut(.a(a), .y(y));

    task automatic check(input [2:0] ta);
        a = ta;
        #1;
        gold = 8'h1 << ta;
        if (y !== gold) begin
            err = err + 1;
            if (err == 1)
                $display("JUDGE-MISMATCH: in=a=%0d got=%b want=%b",
                         ta, y, gold);
        end
    endtask

    initial begin
        err = 0;
        for (i_t = 0; i_t < 8; i_t = i_t + 1)
            check(i_t[2:0]);

        $display("JUDGE-COUNT: 8");
        if (err == 0)
            $display("JUDGE: PASS");
        else
            $display("JUDGE: FAIL %0d", err);
        $finish;
    end

endmodule