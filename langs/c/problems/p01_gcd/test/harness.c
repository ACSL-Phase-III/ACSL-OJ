// p01_gcd 判分 harness：穷举 a(1..120) x b(1..120) = 14400 组
// 黄金模型刻意与 RTL/学生写法不同：gcd 用"逐个下降试除"暴力求解（O(min(a,b))），
// lcm 用"从 max 开始逐个累加找首个公倍数"，避免抄参考实现。
#include <stdio.h>
#include "../gcd.h"

#define LIMIT 120

static int gold_gcd(int a, int b)
{
    int m = (a < b) ? a : b;
    for (int d = m; d >= 1; d--)
        if (a % d == 0 && b % d == 0)
            return d;
    return 1;
}

static long long gold_lcm(int a, int b)
{
    int big = (a > b) ? a : b;
    int small = (a > b) ? b : a;
    for (long long k = big; ; k += big)
        if (k % small == 0)
            return k;
}

int main(void)
{
    int err = 0;
    int n = 0;

    for (int a = 1; a <= LIMIT; a++) {
        for (int b = 1; b <= LIMIT; b++) {
            n++;

            int wg = gold_gcd(a, b);
            int gg = gcd(a, b);
            if (gg != wg) {
                err++;
                if (err == 1)
                    printf("JUDGE-MISMATCH: in=gcd(%d,%d) got=%d want=%d\n", a, b, gg, wg);
                continue;
            }

            long long wl = gold_lcm(a, b);
            long long gl = lcm(a, b);
            if (gl != wl) {
                err++;
                if (err == 1)
                    printf("JUDGE-MISMATCH: in=lcm(%d,%d) got=%lld want=%lld\n", a, b, gl, wl);
            }
        }
    }

    printf("JUDGE-COUNT: %d\n", n);
    if (err == 0)
        printf("JUDGE: PASS\n");
    else
        printf("JUDGE: FAIL %d\n", err);
    return 0;
}
