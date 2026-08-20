# C 语言模块

C 程序设计作业的判分题库。平台总览与 trace 用法见
[根目录 README](../../README.md)，本文只讲 C 特有的部分。

> **作答方式**：模板就是作答文件（如 `problems/p01_class_stat/class_stat.c`），
> 直接在其中 `TODO` 区补全实现即可，请勿改动文件名；
> `func` 题请勿改函数签名（见同名 `.h`）。`test/` 与子 Makefile 请勿改动。


## 用法

以下命令在**本目录**（`langs/c/`）下敲：

```bash
make sim      # 判分本模块全部题目
make style    # 只做风格检查
make list     # 列出题目
make clean    # 清理判分产物
make artifacts                  # 编出本模块要随作业发放的判分件（出题人）
make -C problems/p01_class_stat sim    # 只判某一题
```

从别处指过来也一样，把 `-C` 换成完整路径即可：

```bash
make -C langs/c sim                        # 在仓库根目录判本模块
make -C langs/c/problems/p01_class_stat sim       # 在仓库根目录判某一题
```

另外，平台根目录的 `make sim-langs` 一次判全部语言的题库，`make sim` 则视作答区
有没有周自动选范围（详见根 [README](../../README.md)）。

> 本目录判的是**题库自己**（模板 + 判分资源同在一处，用于出题人自测）。
> 学生的作业在 [`work/`](../../work/README.md)，那边只有作答文件。


## 工具链

需要 `gcc`（含 asan/ubsan 运行库）。判分编译命令：

```
gcc -std=c11 -O1 -g -Wall -Wextra -fsanitize=address,undefined ...
```

可在题目子 Makefile 里覆盖：`CSTD`、`WARN`、`SAN`、`TIMEOUT`（默认 5s）、
`LEAKCHECK`（默认 0）、`STYLE_ARGS`。


## 题型

子 Makefile 里的 `MODE` 决定判分方式：

| MODE | 学生写什么 | 判分方式 | main |
|---|---|---|---|
| `func` | 按 `.h` 实现若干函数 | 学生侧链 `test/harness.o`（黄金模型编在里面），逐样例比对 | **禁止**自带 |
| `io` | 完整程序，读 stdin 写 stdout | `judge/run_io.sh` 把 `test/cases/*.in` 喂进去比对 `*.ans` | **必须**有 |
| `session` | 完整交互程序 | 检查器现场从输入算期望，仓库里没有 `.ans` | **必须**有 |
| `blackbox` | 指令集模拟器，`fopen` 读 argv 镜像 | `judge/run_blackbox.sh` 调 `test/spec.py` 对拍终态 | **必须**有 |

`func` 的黄金模型源码在教师分支的 `test/harness.c`；学生 `git pull` 拿到的是
`make release` 编好的 `.o`。出题、每周发布见 [AUTHORING.md](AUTHORING.md)。

`func` 模式能穷举上万组、精确定位到哪个函数哪组输入错，是默认选择；
`io` 模式用来练标准输入输出与复杂度（大数据组会卡掉 O(n²) 解法）。

io 模式的比较规则由 `run_io.sh` 统一实现：忽略行尾空白与末尾空行，其余逐字符相同。


## 内存与未定义行为（RE）

所有题目都用 `-fsanitize=address,undefined` 编译。数组越界、use-after-free、
整数溢出、未初始化读等在传统 OJ 上"碰巧过了"的写法，这里直接判 RE 并给出出错行号。
**这是本模块相对在线 OJ 的主要价值**：把 C 最容易踩的坑当场指出来。

指令集模拟器（`blackbox`，以及 week5 这种 `func` 模拟器）会关掉
`signed-integer-overflow` 与 `shift` 两项 UBSan：32 位环绕加法是对的，
不该判 RE。ASan 与其余 UBSan 保留。题目 Makefile 用 `SAN_EXTRA` 控制。

内存泄漏默认不判（`LEAKCHECK=0`），需要时在子 Makefile 里设 `LEAKCHECK=1`。

`func` 模式的 harness 用 `malloc` **精确分配**传给学生函数的缓冲区，越界一格即被抓到。


## SE 判罚详情

学生解只允许**标准 C + 白名单头文件 + 自己实现的算法**。风格检查先剥离注释与
字符串/字符字面量再匹配，所以 `printf("system(")` 或注释里的关键词不会误伤。

**禁止**：
- **进程/信号控制**：`system popen fork exec* execve posix_spawn dlopen signal raise setjmp longjmp atexit abort _exit _Exit exit quick_exit syscall`
  （不允许学生解创建进程或劫持控制流）；
- **文件/环境访问**：`fopen freopen fdopen creat openat open read write chmod remove unlink rename rmdir opendir mmap getenv putenv setenv`
  （只能用参数或 stdin 取数据，不得读写文件绕过判分；`blackbox` 只额外放开 `fopen`）；
- **不安全函数**：`gets strcpy strcat sprintf vsprintf alloca`（缓冲区溢出风险，用带长度的版本）；
- `goto`、内联汇编（`asm` / `__asm__`）、`constructor` / `destructor` 属性；
- 白名单外的头文件。默认白名单：
  `stdio.h stdlib.h string.h math.h limits.h stdbool.h stddef.h stdint.h ctype.h assert.h`
  （`func` 模式自动追加本题的 `<模块名>.h`）；
- `main`：`func` 模式禁止自带，`io` / `session` / `blackbox` 必须有；
- 各题用 `STYLE_ARGS := --ban=...` 追加的禁止项。

`open`/`read`/`write`/`syscall` 按标识符禁止。头文件白名单**不是**系统调用防火墙：
`extern long write(int, const void *, unsigned long);` 不需要 `<unistd.h>`。

### 为什么禁这些：判罚是怎么防伪造的

`func` 模式里学生解与判分端 harness 被编进**同一个可执行文件**，共享 stdout。
最直接的作弊是 `printf("JUDGE-COUNT: 1\nJUDGE: PASS\n"); exit(0);` —— 抢在 harness
之前给出结论。禁 `exit` 之类的黑名单挡不住（`_Exit` / `quick_exit` / `longjmp` 都能绕），
光给协议行加签名也挡不住：同进程意味着 harness 藏不住秘密，nonce 走 argv 能从
`/proc/self/cmdline` 读到，走环境变量能用 `extern char **environ;` 遍历到，
再不然直接翻内存。实测一个 `__attribute__((destructor))` 在 `main` 返回后补一行
带正确签名的 `JUDGE: PASS`，就让全错的解拿到了 AC。

所以真正起作用的是**换通道**，三层叠起来：

1. **通道隔离**（主防线）：判分协议走 fd 3 → `build/proto.log`，学生解的 `printf`
   只能到 stdout → `build/run.log`（仅用于给学生看诊断、匹配 sanitizer 报告）。
   `verdict.sh` 只认 `proto.log` 里的结论；通道为空即 RE，绝不回头去读 `run.log`。
2. **一行判罚**：`proto.log` 里出现两行 `JUDGE:` 一律判 RE。这样"抢在 harness 前面"
   和"在 harness 后面补一行"两种顺序都赢不了。
3. **风格检查**（补充层）：`write`/`open`/`syscall`/`exit`/`constructor`/`destructor`
   按标识符禁止，学生解拿不到往 fd 3 写再提前结束的手段。头文件白名单单独不够。

上面禁 `fdopen`/`environ` 的用意就在这里 —— 它们与"自己写算法"这个训练目标毫无关系，
出现即视为在试探判分环境。三层互不依赖：把风格检查整个停掉，攻击仍然只能拿到 WA / RE。


## 题目清单

| 题号 | 内容 | 模式 | 测试规模 | 额外禁止 |
|---|---|---|---|---|
| p01_class_stat | 班级成绩统计器（输入校验 + 总分/平均/及格 + 班级评价） | session | 9 组固定 + 6 组随机 | — |
| week2_problem1 | 班级成绩统计器（同 p01，边界样例加到 17 组） | session | 17 组固定 + 6 组随机 | — |
| week3_problem1 | 成绩排序与名次（竞赛排名 + 并列最高分） | session | 15 组固定 + 6 组随机 | — |
| week5_problem1 | sEMU（sISA 模拟器） | func | 4 组镜像 + 4 组随机 | — |
| week5_problem2 | miniEMU（minirv 模拟器） | func | 9 组镜像 + 长测 + 随机 | — |

学生侧发放 `test/check` 与 `test/gen`（CI / `make artifacts` 编出）。`check.c` 只留在教师分支。


## 新增题目

### func 模式（推荐）

1. 建 `problems/<pid>/`，写子 Makefile：

   ```make
   PID    := p05_matrix
   MODULE := matrix
   MODE   := func
   STYLE_ARGS := --ban=qsort     # 可选：本题额外禁止项
   TIMEOUT    := 5               # 可选：覆盖默认时限
   LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
   include $(LANGDIR)/lang.mk
   ```

2. 写 `<模块名>.h`（接口声明，注明输入范围与边界约定）与 `<模块名>.c`（签名 + `TODO` 空区）；
3. 写 `test/harness.c`，遵守判分协议：
   - 题目 Makefile 写 `HARNESS_NAME := harness.o`，学生拿不到黄金模型源码；
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
