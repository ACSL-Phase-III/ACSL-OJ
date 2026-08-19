#!/usr/bin/env python3
# core/judge/session.py —— 会话型题目的检查器辅助库（语言无关）
#
# 给出题人用：题目的 test/check.py 引入本模块，只需描述"输出里应当出现哪些语义关键行"，
# 归一化、按序匹配、协议输出都由本模块负责。
#
# 判分协议（core/judge/verdict.sh 只认这几行）：
#     JUDGE-MISMATCH: in=... got=... want=...
#     JUDGE-COUNT: <N>
#     JUDGE: PASS | JUDGE: FAIL <n>
#
# 为什么要归一化：讲义自己三周的输出格式就不统一（`总分: 471` 与 `总分：265`、
# `班级评价：优秀` 与 `班级评价：优秀。`），且明写"代码格式不作要求，只要实现功能即可"。
# 所以判分只认语义关键行：提示语、重复菜单、空行一律不参与比对。

import os
import re
import sys

# 全角 -> 半角。只做标点，不动数字与字母（学生不会用全角数字，动了反而掩盖真错误）。
_FULL2HALF = {
    ord("："): ":", ord("，"): ",", ord("。"): ".", ord("；"): ";",
    ord("！"): "!", ord("？"): "?", ord("（"): "(", ord("）"): ")",
    ord("、"): ",", ord("　"): " ", ord("％"): "%", ord("－"): "-",
}


def normalize_line(s):
    """单行归一化：全角标点、空白、冒号两侧空格、行尾句号一律抹平。"""
    s = s.translate(_FULL2HALF)
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\s*:\s*", ":", s)      # "总分: 471" 与 "总分：471" 归一
    return s.rstrip(". !").strip()      # 行尾句号/叹号可选


def normalize(text):
    """整段输出归一化成非空行列表。"""
    return [n for n in (normalize_line(x) for x in text.splitlines()) if n]


def kv(label, value):
    """构造一条 "标签:值" 的期望行（自身也走归一化，写全角半角都行）。"""
    return normalize_line("%s:%s" % (label, value))


class Checker:
    """按序子序列匹配器。

    语义：期望行必须在学生输出里**按给定顺序**出现，中间夹多少提示语、
    重复菜单、空行都不管。这样"要求打印提示语"与"示例输出没有提示语"
    这个讲义内部的矛盾就不会冤判任何一方。
    """

    def __init__(self, out_text, label=None):
        self.lines = normalize(out_text)
        self.cursor = 0
        self.count = 0
        self.fail = 0
        self.first = None
        # 样例名由运行器通过环境变量传入，check.py 无需关心
        self.label = label or os.environ.get("CASE", "会话")

    # ---------------- 内部 ----------------
    def _context(self):
        seg = self.lines[self.cursor:self.cursor + 6]
        return ("~".join(seg) if seg else "(输出已结束)")[:200]

    def _record_fail(self, want_desc, hint=""):
        self.fail += 1
        if self.first is None:
            self.first = (want_desc + hint, self._context())

    def _scan(self, pred, want_desc):
        self.count += 1
        for i in range(self.cursor, len(self.lines)):
            if pred(self.lines[i]):
                self.cursor = i + 1
                return True
        # 没找到：区分"根本没有"和"顺序不对"，后者的提示完全不同
        for i in range(0, self.cursor):
            if pred(self.lines[i]):
                self._record_fail(want_desc, "（该行出现了，但顺序早于预期）")
                return False
        self._record_fail(want_desc)
        return False

    # ---------------- 出题人用的断言 ----------------
    def expect(self, want, **_):
        """期望出现一行与 want 完全相同（归一化后）的输出。"""
        w = normalize_line(want)
        return self._scan(lambda ln: ln == w, w)

    def expect_kv(self, label, value):
        """期望出现 "标签:值"，如 expect_kv("总分", 471)。"""
        return self.expect(kv(label, value))

    def expect_re(self, pattern, desc=None):
        """期望出现一行匹配正则 pattern 的输出（正则作用于归一化后的行）。"""
        rx = re.compile(pattern)
        return self._scan(lambda ln: rx.search(ln) is not None,
                          desc or ("匹配 /%s/" % pattern))

    def expect_seq(self, wants):
        """一串期望行，按序匹配。"""
        for w in wants:
            self.expect(w)

    def forbid(self, pattern, desc=None):
        """反向断言：整段输出里都不该出现匹配 pattern 的行。"""
        self.count += 1
        rx = re.compile(pattern)
        for ln in self.lines:
            if rx.search(ln):
                self.fail += 1
                if self.first is None:
                    self.first = ("不应出现 " + (desc or "/%s/" % pattern),
                                  ln[:200])
                return False
        return True

    # ---------------- 收尾 ----------------
    def finish(self):
        """输出判分协议。必须在 check.py 末尾调用一次。"""
        if self.first is not None:
            want, got = self.first
            print("JUDGE-MISMATCH: in=%s got=%s want=%s" % (self.label, got, want))
        print("JUDGE-COUNT: %d" % self.count)
        print("JUDGE: PASS" if self.fail == 0 else "JUDGE: FAIL %d" % self.fail)
        return 0


def load(argv=None):
    """读取 check.py 的两个参数：<输入文件> <学生 stdout 文件>，返回两段文本。"""
    a = argv if argv is not None else sys.argv[1:]
    if len(a) < 2:
        sys.stderr.write("usage: check.py <input_file> <student_stdout_file>\n")
        sys.exit(2)
    with open(a[0], encoding="utf-8") as f:
        src = f.read()
    with open(a[1], encoding="utf-8", errors="replace") as f:
        out = f.read()
    return src, out
