// p04_cmp_eq4 判分 testbench：穷举 a(0..15) x b(0..15) = 256 组
// 黄金模型用（按位异或的归并结果取反）的思想，与 RTL 的 == 写法不同。
`timescale 1ns/1ps
module tb_cmp_eq4;

    logic [3:0] a;
    logic [3:0] b;
    logic       eq;

    integer err;
    integer i, j;
    logic       gold;

    cmp_eq4 dut(.a(a), .b(b), .eq(eq));

    task automatic check(input [3:0] ta, input [3:0] tb_);
        a = ta; b = tb_;
        #1;
        gold = ~|(ta ^ tb_);            // 用异或门 + 或非重建"相等"
        if (eq !== gold) begin
            err = err + 1;
            if (err == 1)
                $display("JUDGE-MISMATCH: in=a=%0d,b=%0d got=%b want=%b",
                         ta, tb_, eq, gold);
        end
    endtask

    initial begin
        err = 0;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                check(i[3:0], j[3:0]);

        $display("JUDGE-COUNT: 256");
        if (err == 0)
            $display("JUDGE: PASS");
        else
            $display("JUDGE: FAIL %0d", err);
        $finish;
    end

endmodule