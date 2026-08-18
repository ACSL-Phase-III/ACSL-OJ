// p04_str_ops 判分 harness：边界样例 + 确定性随机样例（固定种子 LCG，可复现）
// 黄金模型刻意与学生写法不同：squeeze 用"另开缓冲区 + strchr 查表"重建，
// is_palin 用"先抽取归一化副本再首尾比"，而学生被要求原地压缩 / 双指针。
//
// 传给学生函数的字符串都用 malloc 精确分配（len+1），少写 '\0' 或多写一格都会被 ASan 抓到。
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "../str_ops.h"

#define MAXL 48

static unsigned long long rng = 20260816ULL;

static int rnd(int lo, int hi)
{
    rng = rng * 6364136223846793005ULL + 1442695040888963407ULL;
    return lo + (int)((rng >> 33) % (unsigned long long)(hi - lo + 1));
}

static int err = 0, ntest = 0;

// 转义不可见字符，便于放进 JUDGE-MISMATCH 单行输出。
static void esc(char *buf, size_t cap, const char *s)
{
    size_t off = 0;
    for (const char *p = s; *p && off + 5 < cap; p++) {
        if (*p == '\n')      off += (size_t)snprintf(buf + off, cap - off, "\\n");
        else if (*p == '\t') off += (size_t)snprintf(buf + off, cap - off, "\\t");
        else if (*p == ' ')  off += (size_t)snprintf(buf + off, cap - off, "_");
        else                 buf[off++] = *p;
    }
    buf[off] = '\0';
}

static void case_all(const char *src, const char *set)
{
    size_t len = strlen(src);
    char gb[256], wb[256], sb[256];

    // ---- my_strlen ----
    ntest++;
    {
        char *s = malloc(len + 1);
        memcpy(s, src, len + 1);
        int g = my_strlen(s);
        if (g != (int)len) {
            err++;
            if (err == 1) {
                esc(sb, sizeof sb, src);
                printf("JUDGE-MISMATCH: in=my_strlen(\"%s\") got=%d want=%d\n", sb, g, (int)len);
            }
        }
        free(s);
    }

    // ---- squeeze（原地）----
    ntest++;
    {
        char *want = malloc(len + 1);
        size_t wn = 0;
        for (size_t i = 0; i < len; i++)
            if (set[0] == '\0' || strchr(set, src[i]) == NULL)
                want[wn++] = src[i];
        want[wn] = '\0';

        char *got = malloc(len + 1);
        memcpy(got, src, len + 1);
        int gn = squeeze(got, set);
        if (gn != (int)wn || strcmp(got, want) != 0) {
            err++;
            if (err == 1) {
                esc(sb, sizeof sb, src);
                esc(gb, sizeof gb, got);
                esc(wb, sizeof wb, want);
                printf("JUDGE-MISMATCH: in=squeeze(\"%s\",\"%s\") got=n=%d,\"%s\" want=n=%d,\"%s\"\n",
                       sb, set, gn, gb, (int)wn, wb);
            }
        }
        free(got);
        free(want);
    }

    // ---- is_palin ----
    ntest++;
    {
        char *norm = malloc(len + 1);
        size_t nn = 0;
        for (size_t i = 0; i < len; i++) {
            unsigned char c = (unsigned char)src[i];
            if (isalnum(c))
                norm[nn++] = (char)tolower(c);
        }
        norm[nn] = '\0';
        int w = 1;
        for (size_t i = 0; i < nn / 2; i++)
            if (norm[i] != norm[nn - 1 - i]) { w = 0; break; }
        free(norm);

        char *s = malloc(len + 1);
        memcpy(s, src, len + 1);
        int g = is_palin(s);
        if (g != w) {
            err++;
            if (err == 1) {
                esc(sb, sizeof sb, src);
                printf("JUDGE-MISMATCH: in=is_palin(\"%s\") got=%d want=%d\n", sb, g, w);
            }
        }
        free(s);
    }
}

int main(void)
{
    // ---- 边界样例 ----
    case_all("", "");                                    // 空串
    case_all("", "abc");                                 // 空串 + 非空 set
    case_all("abc", "");                                 // 空 set：什么都不删
    case_all("aaaa", "a");                               // 全删光
    case_all("a", "b");                                  // 单字符不删
    case_all("A man, a plan, a canal: Panama", " ,:");    // 经典回文（忽略标点大小写）
    case_all("No 'x' in Nixon", "'");                     // 含引号
    case_all("Was it a car or a cat I saw?", "?");
    case_all("hello", "l");                              // 非回文
    case_all("12321", "");                               // 纯数字回文
    case_all("1a2a1", "a");                              // 删完仍是回文
    case_all("!!! ??? ...", "!");                        // 不含字母数字 -> 视为回文
    case_all("Ab\tBa", "\t");                            // 含制表符

    // ---- 确定性随机样例 ----
    char s[MAXL + 1], set[8];
    const char *pool = "aabbAABB112 ,.!";
    int pooln = (int)strlen(pool);
    for (int t = 0; t < 4000; t++) {
        int n = rnd(0, MAXL);
        for (int i = 0; i < n; i++)
            s[i] = pool[rnd(0, pooln - 1)];
        s[n] = '\0';

        int m = rnd(0, 3);
        for (int i = 0; i < m; i++)
            set[i] = pool[rnd(0, pooln - 1)];
        set[m] = '\0';

        case_all(s, set);
    }

    printf("JUDGE-COUNT: %d\n", ntest);
    if (err == 0)
        printf("JUDGE: PASS\n");
    else
        printf("JUDGE: FAIL %d\n", err);
    return 0;
}
