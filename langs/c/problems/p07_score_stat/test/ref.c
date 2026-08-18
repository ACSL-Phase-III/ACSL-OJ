// p07_score_stat 判分端参考解（只用于生成 *.ans，不参与学生判分编译）
// 用计数排序（成绩值域 0..100）实现，O(n + 101)。
#include <stdio.h>

int main(void)
{
    static int cnt[101];
    int n;
    if (scanf("%d", &n) != 1)
        return 1;

    long long sum = 0;
    int mx = -1, mn = 101;
    for (int i = 0; i < n; i++) {
        int v;
        if (scanf("%d", &v) != 1)
            return 1;
        cnt[v]++;
        sum += v;
        if (v > mx) mx = v;
        if (v < mn) mn = v;
    }

    printf("%d %d\n", mx, mn);
    printf("%.2f\n", (double)sum / (double)n);

    int first = 1;
    for (int v = 100; v >= 0; v--) {
        for (int k = 0; k < cnt[v]; k++) {
            printf("%s%d", first ? "" : " ", v);
            first = 0;
        }
    }
    printf("\n");
    return 0;
}
