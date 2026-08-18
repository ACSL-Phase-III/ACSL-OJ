// p02_array_stat 接口声明（判分端提供，请勿改动本文件）
#ifndef ARRAY_STAT_H
#define ARRAY_STAT_H

// 返回 a[0..n-1] 中的第二大值（严格次大：值相同的元素只算一个）。
// 保证 n >= 2，且数组中至少存在两个不同的值。
int second_max(const int *a, int n);

// 原地反转 a[0..n-1]。保证 n >= 0。
void reverse(int *a, int n);

// 把 a[0..n-1] 中所有等于 val 的元素删除，其余元素保持原有相对顺序前移，
// 返回删除后剩余的元素个数。保证 n >= 0。
int remove_val(int *a, int n, int val);

#endif
