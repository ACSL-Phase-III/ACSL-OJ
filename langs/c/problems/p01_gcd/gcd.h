// p01_gcd 接口声明（判分端提供，请勿改动本文件）
#ifndef GCD_H
#define GCD_H

// 返回 a 与 b 的最大公约数（保证 a >= 1 且 b >= 1）
int gcd(int a, int b);

// 返回 a 与 b 的最小公倍数（保证 a >= 1 且 b >= 1，结果可能超过 int 范围）
long long lcm(int a, int b);

#endif
