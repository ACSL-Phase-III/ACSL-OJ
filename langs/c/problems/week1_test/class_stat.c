// p01_class_stat 班级成绩统计器（C 语言应用·一）
//
// 你要自己写 main，从标准输入读数据、往标准输出打结果。
//
// 【输入】
//   先读学生人数 n（1 <= n <= 100），再读成绩，直到凑齐 n 个有效成绩。
//   成绩是整数。有效范围是 0～100（含两端）。
//
// 【输入校验】
//   若某个数不在 0～100，立刻提示：
//       成绩无效，请重新输入
//   这个数不计入统计，也不消耗人数：继续读下一个数，当作这一次的成绩。
//
// 【输出】（凑齐 n 个有效成绩之后）
//   总分: <总和>
//   平均分: <总和 / n>
//   及格人数: <成绩 >= 60 的人数>
//   不及格人数: <其余>
//   最高分: <最大有效成绩>
//   最低分: <最小有效成绩>
//   班级评价：<评价>
//
//   班级评价按整体平均分（用原值比较，不要拿四舍五入后的打印值去分档）：
//       >= 85  优秀
//       >= 70  良好
//       >= 60  一般
//       <  60  需努力
//
// 【样例输入】
//   6
//   78 92 -5 55 63 88 95
//
// 【样例输出】
//   成绩无效，请重新输入
//
//   总分: 471
//   平均分: 78.5
//   及格人数: 5
//   不及格人数: 1
//   最高分: 95
//   最低分: 55
//   班级评价：良好
//
// 【关于格式】
//   代码格式不作要求，判分只看功能。下面这些差异一律不算错：
//     - 冒号用全角"："或半角":"，冒号两侧有无空格
//     - 行尾多一个句号
//     - 额外的提示语、空行（判分器会跳过）
//     平均分写成 78.5 或 78.50 都可以。
//   但数字必须对，评价必须对，无效成绩的提示必须出现，统计行的先后顺序按上面。
//
// 【提示】
//   用循环读入即可。读到无效成绩时打印提示，不要把它写进数组，也不要把计数器加一。
//   n 最多 100。判分开了 AddressSanitizer，数组开小了会直接判 RE。
#include <stdio.h>

// ===== TODO: 在此完成你的设计 =====
#include <stdio.h>

int main() {
    int n;
    scanf("%d", &n);
    
    double scores[1000];
    int count = 0;
    
    // 读取成绩，进行输入校验
    while (count < n) {
        double score;
        scanf("%lf", &score);
        
        // 输入校验
        if (score < 0 || score > 100) {
            printf("成绩无效，请重新输入\n");
            continue;
        }
        
        scores[count] = score;
        count++;
    }
    
    // 计算统计信息
    double total = 0;
    double max_score = scores[0];
    double min_score = scores[0];
    int pass_count = 0;
    int fail_count = 0;
    
    for (int i = 0; i < count; i++) {
        total += scores[i];
        
        if (scores[i] >= 60) {
            pass_count++;
        } else {
            fail_count++;
        }
        
        if (scores[i] > max_score) {
            max_score = scores[i];
        }
        if (scores[i] < min_score) {
            min_score = scores[i];
        }
    }
    
    double average = total / count;
    
    // 输出结果
    if (total == (int)total) {
        printf("总分: %d\n", (int)total);
    } else {
        printf("总分: %.1f\n", total);
    }
    
    if (average == (int)average) {
        printf("平均分: %d\n", (int)average);
    } else {
        printf("平均分: %.1f\n", average);
    }
    
    printf("及格人数: %d\n", pass_count);
    printf("不及格人数: %d\n", fail_count);
    
    if (max_score == (int)max_score) {
        printf("最高分: %d\n", (int)max_score);
    } else {
        printf("最高分: %.1f\n", max_score);
    }
    
    if (min_score == (int)min_score) {
        printf("最低分: %d\n", (int)min_score);
    } else {
        printf("最低分: %.1f\n", min_score);
    }
    
    // 班级评价
    if (average >= 85) {
        printf("班级评价：优秀\n");
    } else if (average >= 70) {
        printf("班级评价：良好\n");
    } else if (average >= 60) {
        printf("班级评价：一般\n");
    } else {
        printf("班级评价：需努力\n");
    }
    
    return 0;
}
// ===== END =====
