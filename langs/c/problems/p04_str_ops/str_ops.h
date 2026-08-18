// p04_str_ops 接口声明（判分端提供，请勿改动本文件）
#ifndef STR_OPS_H
#define STR_OPS_H

// 返回 s 的长度（不含结尾 '\0'）。不得调用 strlen。
int my_strlen(const char *s);

// 原地删除 s 中所有出现在 set 中的字符，其余字符保持相对顺序前移，
// 结果必须以 '\0' 结尾；返回删除后的字符串长度。
// set 为普通以 '\0' 结尾的字符串（可能为空串，此时什么都不删）。
int squeeze(char *s, const char *set);

// 只考虑 s 中的字母与数字，忽略字母大小写，判断这些字符构成的序列是否回文。
// 是回文返回 1，否则返回 0；空串或不含字母数字视为回文（返回 1）。
int is_palin(const char *s);

#endif
