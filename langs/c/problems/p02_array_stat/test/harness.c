// p02_array_stat 判分 harness：边界样例 + 确定性随机样例（固定种子 LCG，可复现）
// 黄金模型刻意与学生写法不同：second_max 用"排序副本后倒序扫描"，
// reverse / remove_val 用"另开缓冲区重建"，而学生要求原地双指针完成。
//
// 所有传给学生函数的数组都用 malloc 精确分配，越界一格即被 ASan 抓到（判 RE）。
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../array_stat.h"

#define MAXN 64

static unsigned long long rng = 20260815ULL;

static int rnd(int lo, int hi)
{
    rng = rng * 6364136223846793005ULL + 1442695040888963407ULL;
    return lo + (int)((rng >> 33) % (unsigned long long)(hi - lo + 1));
}

static int cmp_int(const void *x, const void *y)
{
    int a = *(const int *)x, b = *(const int *)y;
    return (a > b) - (a < b);
}

static int gold_second_max(const int *a, int n)
{
    int *c = malloc((size_t)n * sizeof(int));
    memcpy(c, a, (size_t)n * sizeof(int));
    qsort(c, (size_t)n, sizeof(int), cmp_int);
    int mx = c[n - 1], res = mx;
    for (int i = n - 2; i >= 0; i--)
        if (c[i] != mx) { res = c[i]; break; }
    free(c);
    return res;
}

// 把 a[0..n-1] 拼成单行文本，便于放进 JUDGE-MISMATCH。
static void fmt(char *buf, size_t cap, const int *a, int n)
{
    size_t off = 0;
    off += (size_t)snprintf(buf + off, cap - off, "[");
    for (int i = 0; i < n && off + 16 < cap; i++)
        off += (size_t)snprintf(buf + off, cap - off, "%s%d", i ? "," : "", a[i]);
    snprintf(buf + off, cap - off, "]");
}

static int err = 0, ntest = 0;

// 用一个精确大小的堆缓冲区跑学生函数，再与黄金结果比对。
static void case_all(const int *src, int n, int val)
{
    char gb[512], wb[512];
    int *want = malloc((size_t)(n ? n : 1) * sizeof(int));
    int *got;

    // ---- second_max（仅在 n>=2 且存在两个不同值时有定义）----
    if (n >= 2) {
        int distinct = 0;
        for (int i = 1; i < n; i++)
            if (src[i] != src[0]) { distinct = 1; break; }
        if (distinct) {
            ntest++;
            got = malloc((size_t)n * sizeof(int));
            memcpy(got, src, (size_t)n * sizeof(int));
            int g = second_max(got, n);
            int w = gold_second_max(src, n);
            if (g != w) {
                err++;
                if (err == 1) {
                    fmt(gb, sizeof gb, src, n);
                    printf("JUDGE-MISMATCH: in=second_max(%s,%d) got=%d want=%d\n", gb, n, g, w);
                }
            }
            free(got);
        }
    }

    // ---- reverse（原地）----
    ntest++;
    for (int i = 0; i < n; i++)
        want[i] = src[n - 1 - i];
    got = malloc((size_t)(n ? n : 1) * sizeof(int));
    memcpy(got, src, (size_t)n * sizeof(int));
    reverse(got, n);
    if (n > 0 && memcmp(got, want, (size_t)n * sizeof(int)) != 0) {
        err++;
        if (err == 1) {
            fmt(gb, sizeof gb, got, n);
            fmt(wb, sizeof wb, want, n);
            printf("JUDGE-MISMATCH: in=reverse(n=%d) got=%s want=%s\n", n, gb, wb);
        }
    }
    free(got);

    // ---- remove_val（原地，返回剩余个数）----
    ntest++;
    int wn = 0;
    for (int i = 0; i < n; i++)
        if (src[i] != val)
            want[wn++] = src[i];
    got = malloc((size_t)(n ? n : 1) * sizeof(int));
    memcpy(got, src, (size_t)n * sizeof(int));
    int gn = remove_val(got, n, val);
    if (gn != wn || (wn > 0 && memcmp(got, want, (size_t)wn * sizeof(int)) != 0)) {
        err++;
        if (err == 1) {
            fmt(gb, sizeof gb, got, gn > 0 && gn <= n ? gn : 0);
            fmt(wb, sizeof wb, want, wn);
            printf("JUDGE-MISMATCH: in=remove_val(n=%d,val=%d) got=n=%d,%s want=n=%d,%s\n",
                   n, val, gn, gb, wn, wb);
        }
    }
    free(got);

    free(want);
}

int main(void)
{
    // ---- 边界样例 ----
    int e0[1] = {0};
    case_all(e0, 0, 7);                                  // 空数组
    int e1[1] = {5};
    case_all(e1, 1, 5);                                  // 单元素，且恰好被删
    case_all(e1, 1, 9);                                  // 单元素，不被删
    int e2[4] = {3, 3, 3, 3};
    case_all(e2, 4, 3);                                  // 全同且全删
    int e3[5] = {1, 2, 2, 2, 2};
    case_all(e3, 5, 2);                                  // 次大在重复值中
    int e4[6] = {-9, -1, -1, -7, 0, -1};
    case_all(e4, 6, -1);                                 // 含负数
    int e5[3] = {2147483647, 2147483647, -2147483648};
    case_all(e5, 3, 0);                                  // int 边界值

    // ---- 确定性随机样例 ----
    int a[MAXN];
    for (int t = 0; t < 3000; t++) {
        int n = rnd(0, MAXN);
        int span = rnd(1, 30);                           // 小值域制造大量重复
        for (int i = 0; i < n; i++)
            a[i] = rnd(-span, span);
        case_all(a, n, rnd(-span, span));
    }

    printf("JUDGE-COUNT: %d\n", ntest);
    if (err == 0)
        printf("JUDGE: PASS\n");
    else
        printf("JUDGE: FAIL %d\n", err);
    return 0;
}
