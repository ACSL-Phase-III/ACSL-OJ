# C 语言模块

C 程序设计作业的判分题库。平台总览与 trace 用法见
[根目录 README](../../README.md)，本文只讲 C 特有的部分。

> **作答方式**：模板就是作答文件（如 `problems/p01_gcd/gcd.c`），
> 直接在其中 `TODO` 区补全实现即可，请勿改动文件名与函数签名（见同名 `.h`）；
> `test/` 与子 Makefile 请勿改动。


## 用法

```bash
make sim      # 判分本模块全部题目
make style    # 只做风格检查
make list     # 列出题目
make clean    # 清理判分产物
make -C problems/p01_gcd sim    # 只判某一题
```

也可从平台根目录 `make sim` 一次判全部语言。


## 工具链

需要 `gcc`（含 asan/ubsan 运行库）。判分编译命令：

```
gcc -std=c11 -O1 -g -Wall -Wextra -fsanitize=address,undefined ...
```

可在题目子 Makefile 里覆盖：`CSTD`、`WARN`、`SAN`、`TIMEOUT`（默认 5s）、
`LEAKCHECK`（默认 0）、`STYLE_ARGS`。


## 两种题型

子 Makefile 里的 `MODE` 决定判分方式：

| MODE | 学生写什么 | 判分方式 | main |
|---|---|---|---|
| `func` | 按 `.h` 实现若干函数 | 判分端 `test/harness.c` 里的黄金模型逐样例调用比对 | **禁止**自带 |
| `io` | 完整程序，读 stdin 写 stdout | `judge/run_io.sh` 把 `test/cases/*.in` 喂进去比对 `*.ans` | **必须**有 |

`func` 模式能穷举上万组、精确定位到哪个函数哪组输入错，是默认选择；
`io` 模式用来练标准输入输出与复杂度（大数据组会卡掉 O(n²) 解法）。

io 模式的比较规则由 `run_io.sh` 统一实现：忽略行尾空白与末尾空行，其余逐字符相同。


## 内存与未定义行为（RE）

所有题目都用 `-fsanitize=address,undefined` 编译。数组越界、use-after-free、
整数溢出、未初始化读等在传统 OJ 上"碰巧过了"的写法，这里直接判 RE 并给出出错行号。
**这是本模块相对在线 OJ 的主要价值**：把 C 最容易踩的坑当场指出来。

内存泄漏默认不判（`LEAKCHECK=0`），需要时在子 Makefile 里设 `LEAKCHECK=1`。

`func` 模式的 harness 用 `malloc` **精确分配**传给学生函数的缓冲区，越界一格即被抓到。


## SE 判罚详情

学生解只允许**标准 C + 白名单头文件 + 自己实现的算法**。风格检查先剥离注释与
字符串/字符字面量再匹配，所以 `printf("system(")` 或注释里的关键词不会误伤。

**禁止**：
- **进程/信号控制**：`system popen fork exec* posix_spawn dlopen signal raise setjmp longjmp atexit abort _exit`
  （不允许学生解创建进程或劫持控制流）；
- **文件/环境访问**：`fopen freopen fdopen creat openat remove unlink rename rmdir opendir mmap getenv putenv setenv`
  （只能用参数或 stdin 取数据，不得读写文件绕过判分）；
- **不安全函数**：`gets strcpy strcat sprintf vsprintf alloca`（缓冲区溢出风险，用带长度的版本）；
- `goto`、内联汇编（`asm` / `__asm__`）；
- 白名单外的头文件。默认白名单：
  `stdio.h stdlib.h string.h math.h limits.h stdbool.h stddef.h stdint.h ctype.h assert.h`
  （`func` 模式自动追加本题的 `<模块名>.h`）；
- `main`：`func` 模式禁止自带，`io` 模式必须有；
- 各题用 `STYLE_ARGS := --ban=...` 追加的禁止项。

`open`/`read`/`write` 这类裸系统调用不单独列入禁止名单——它们需要 `<fcntl.h>` /
`<unistd.h>`，已被头文件白名单拦住，重复禁止反而会误伤学生自己命名的 `read` 之类函数。


## 题目清单

| 题号 | 内容 | 模式 | 测试规模 | 额外禁止 |
|---|---|---|---|---|
| p01_gcd | 辗转相除求 gcd / lcm（考 lcm 先除后乘防溢出） | func | 14400 | — |
| p02_array_stat | 次大值、原地反转、原地删除 | func | 8924 | `malloc` `qsort` 等 |
| p04_str_ops | 自己数长度、原地压缩、忽略大小写回文 | func | 12039 | `strlen` `malloc` 等 |
| p07_score_stat | 成绩统计 + 降序输出（n=1e5 卡冒泡） | io | 14 | — |

额外禁止项是为了逼出目标算法：p02 要求原地双指针故禁 `malloc`/`qsort`，
p04 要求自己数长度故禁 `strlen`。


## 新增题目

### func 模式（推荐）

1. 建 `problems/<pid>/`，写子 Makefile：

   ```make
   PID    := p05_matrix
   MODULE := matrix
   MODE   := func
   STYLE_ARGS := --ban=qsort     # 可选：本题额外禁止项
   TIMEOUT    := 5               # 可选：覆盖默认时限
   LANG := ../..
   include $(LANG)/lang.mk
   ```

2. 写 `<模块名>.h`（接口声明，注明输入范围与边界约定）与 `<模块名>.c`（签名 + `TODO` 空区）；
3. 写 `test/harness.c`，遵守判分协议：
   - **黄金模型用与学生不同的思路实现**（学生写 O(n) 双指针，黄金就用排序副本或暴力），
     避免照抄参考实现；
   - 传给学生函数的缓冲区用 `malloc` 精确分配；
   - 边界样例（空、单元素、全同、极值、负数）+ 固定种子 LCG 随机样例（可复现）；
   - 打印首个失配 `JUDGE-MISMATCH: in=... got=... want=...`；
   - 输出 `JUDGE-COUNT: N`；
   - **最后一行且仅一行**：`JUDGE: PASS` 或 `JUDGE: FAIL <n>`。

### io 模式

1. 子 Makefile 里写 `MODE := io`（并按需设 `TIMEOUT`）；
2. 在模板 `.c` 的注释里写清输入输出格式与样例；
3. 写 `test/ref.c` 参考解与 `test/gen.sh` 数据生成脚本，`bash test/gen.sh` 产出
   `test/cases/*.in` 与 `*.ans`；数据要含最小规模、退化分布与卡复杂度的大规模组。
