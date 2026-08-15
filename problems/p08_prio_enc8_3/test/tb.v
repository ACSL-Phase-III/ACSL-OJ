// p08_prio_enc8_3 判分 testbench：穷举 i(0..255) = 256 组
// 黄金模型用"从高到低扫描最高位 1"的位扫描循环实现，与 RTL 的三目链不同。
`timescale 1ns/1ps
module tb_prio_enc8_3;

    logic [7:0] i;
    logic [2:0] y;

    integer err;
    integer i_t;
    integer gold;
    integer k;

    prio_enc8_3 dut(.i(i), .y(y));

    task automatic check(input [7:0] ti);
        i = ti;
        #1;
        gold = 0;
        begin : scan
            for (k = 7; k >= 0; k = k - 1)
                if (ti[k]) begin
                    gold = k;
                    disable scan;
                end
        end
        if (y !== gold[2:0]) begin
            err = err + 1;
            if (err == 1)
                $display("JUDGE-MISMATCH: in=i=%0d got=%0d want=%0d",
                         ti, y, gold);
        end
    endtask

    initial begin
        err = 0;
        for (i_t = 0; i_t < 256; i_t = i_t + 1)
            check(i_t[7:0]);

        $display("JUDGE-COUNT: 256");
        if (err == 0)
            $display("JUDGE: PASS");
        else
            $display("JUDGE: FAIL %0d", err);
        $finish;
    end

endmodule