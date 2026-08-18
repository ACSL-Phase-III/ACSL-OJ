// p03_adder4 判分 testbench：穷举 a(0..15) x b(0..15) x cin(0..1) = 512 组
// 黄金模型用 5 位整数算术 {cout,sum} = a+b+cin，与 RTL 写法不同，避免复制 ref 表达式。
`timescale 1ns/1ps
module tb_adder4;

    logic [3:0] a;
    logic [3:0] b;
    logic       cin;
    logic [3:0] sum;
    logic       cout;

    integer err;
    integer i, j;
    integer k;
    integer gold;

    adder4 dut(.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

    task automatic check(input [3:0] ta, input [3:0] tb_, input tcin);
        a = ta; b = tb_; cin = tcin;
        #1;
        gold = ta + tb_ + tcin;
        if ({cout, sum} !== gold[4:0]) begin
            err = err + 1;
            if (err == 1)
                $display("JUDGE-MISMATCH: in=a=%0d,b=%0d,cin=%0d got=%b want=%b",
                         ta, tb_, tcin, {cout, sum}, gold[4:0]);
        end
    endtask

    initial begin
        err = 0;
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                for (k = 0; k < 2; k = k + 1)
                    check(i[3:0], j[3:0], k[0]);

        $display("JUDGE-COUNT: 512");
        if (err == 0)
            $display("JUDGE: PASS");
        else
            $display("JUDGE: FAIL %0d", err);
        $finish;
    end

endmodule