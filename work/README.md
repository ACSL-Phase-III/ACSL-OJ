# 作答区

**这里是你的地盘。** 每周一个目录，里面只有你的作答文件。

判分资源（harness / testbench / 测试数据 / 检查器 / 契约头文件）一律留在
`../langs/<语言>/problems/<题号>/`，判分时由平台自己指过去。于是：

- `git pull` 拿到新题不会碰到你写的代码 —— 两边根本不在同一个目录；
- 老师改题、改数据、改判据，你这边零操作即生效；
- 作答区里翻不到答案，它从来没被拷进来过。

## 三条命令

```console
$ make take         # 取下本周全部题目的模板（已经写过的文件绝不覆盖）
$ make sim          # 判分
$ make status       # 看每题的状态与最近一次判罚
```

在哪个目录跑决定判分范围，其余完全一样：

| 位置 | 范围 |
|---|---|
| 仓库根目录 | 全部周 |
| `work/` | 全部周 |
| `work/week1/` | 只判 week1 |
| `work/week1/p01_class_stat/` | 只判这一题 |

判分只认最后那行判罚（`AC` / `WA` / `CE` / `SE` / `TLE` / `RE`），
判罚表见[平台 README](../README.md#判罚表)。

## 两种周布局

`make take` 取下来长什么样，取决于那一周的 `Makefile` 里 `STAGED` 写的是几。

**平铺**（题量少，默认）：

```
work/week1/
├── Makefile
└── p01_class_stat/
    ├── Makefile     取模板时生成
    └── class_stat.c ← 你写这个
```

**分拣**（题量大的周，比如 Verilog 一周好几组）：

```
work/week5/problem/
├── Makefile
├── problem_set/     还没过的
│   ├── p03_adder4/
│   └── p04_cmp_eq4/
└── done/            第一道题 AC 后自动出现，通过的题移进来
    └── p10_decoder3_8/
```

刚 `make take` 完是没有 `done/` 的 —— 它由平台在第一道题 AC 时现建，
所以新克隆的仓库里看不到它很正常，不用自己去建。

分拣布局在 `problem/` 目录下跑 `make sim` 会把待做区的题**全部**判一遍，
AC 的自动移进 `done/`。多出来的三个命令：

```console
$ make verify              # 重判 done/ 里的题（回归检查，不移动任何东西）
$ make reopen PID=p03_adder4   # 把一题从 done/ 挪回待做区继续改
$ make status              # 哪些待做、哪些已过
```

这三条在仓库根目录和 `work/` 下也能敲，`reopen` 会自己找到那一题归档在哪一周：

```console
$ make reopen PID=p03_adder4      # 在根目录或 work/ 下同样有效
```

`make verify` 与 `make sim` 的退出码规则不同，值得留意：`sim` 判出 `WA` 也退 0
（判罚是结果，不是故障），而 `verify` 只要有题回归失败就退非 0 —— 它存在的意义
就是回答「我已经过的题还过不过」，这个答案要能被脚本读到。

自动归档默认只在分拣布局开启。平铺布局下 AC 不移动东西 —— 因为 C 的 session 题
每次判分是**现场随机生成数据**的，一次 AC 只说明这组数据过了，移走会让人误以为
万事大吉。想改哪边都只是在周 Makefile 里写一行 `AUTODONE := 1` 或 `0`。

## 常见情况

**改到一半想重新取一份模板。** `make take` 不会覆盖已存在的作答文件，
它会打印"保留 …（已存在，未覆盖）"。真要退回模板，先自己把那个文件删掉或改名。

**`make take` 说"work/ 下没有发现任何一周"。** 一周是由它自己的 `Makefile`
定义的，平台不另存一份周名清单 —— 那个文件被删掉就没有记录了。从 git 取回：

```console
$ git status work/          # 先确认是不是真被删了
$ git checkout -- work/
```

**`make sim` 说"待做区没有题目"。** 还没取模板，先 `make take`。

**想复现某一次随机失败。** C 的 session 题每次现场生成随机数据，判分日志里会打印
用到的种子。照着跑即可重放：

```console
$ make sim SEED=12345
```

## 给老师：加一周

新建一周不必手写 Makefile：

```console
$ make new-week WEEK=week2 PROBLEMS='p12_foo p13_bar'
$ make new-week WEEK=week6 PROBLEMS='p03_adder4 p04_cmp_eq4' STAGED=1
```

题号必须已经在 `langs/*/problems/` 里。建好后学生还看不到 —— 要 `make release`
再 `git push public main`（学生快照进公开仓；源码只进私有 DEV），
学生 `git pull && make take` 才取得到。
完整流程见仓库根目录 [USAGE.md](../USAGE.md) 和
[`langs/c/AUTHORING.md`](../langs/c/AUTHORING.md)。

也可以自己写 `work/<周名>/Makefile`：声明周名与题号，就被自动发现 ——
平台按内容认（`include` 了 `week.mk` 的目录就是一周），不必登记到别处。

平铺：

```make
WEEK     := week1
PROBLEMS := p01_class_stat
STAGED   := 0
WORK := ../../core
include $(WORK)/week.mk
```

分拣（注意目录叫 `problem/`，所以 `WEEK` **必须**显式写，否则周名会变成 `problem`）：

```make
WEEK     := week5
PROBLEMS := p03_adder4 p04_cmp_eq4 p08_prio_enc8_3 p10_decoder3_8 p13_seg_hex
STAGED   := 1
WORK := ../../../core     # 比平铺多一层，因为本文件在 work/<周>/problem/
include $(WORK)/week.mk
```

（`WORK` 指向 `core/`，层数按本文件所在深度数。照抄现成的那两个 Makefile 最省事。）

题号必须是 `langs/*/problems/` 里已有的目录名（`make -C .. langs` 看各语言题数）。
一周可以混语言 —— 题号自己带着语言信息，平台按题号找到题库目录。

出题（新增题目、session 模式、只发放编译好的判分件）见
[`langs/c/AUTHORING.md`](../langs/c/AUTHORING.md)。
