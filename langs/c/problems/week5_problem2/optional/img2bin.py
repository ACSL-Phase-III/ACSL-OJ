#!/usr/bin/env python3
"""
图片转 .bin 工具 —— 用于 minirvEMU 模拟器

直接将任意照片/图片写入 vga.bin 的 0x4AF00 偏移，生成完整可运行文件。
请将此脚本与 vga.bin 放在同一个目录下运行。

依赖：Python 3 + Pillow (pip3 install Pillow)

用法：
  python3 img2bin.py 你的照片.jpg                     # 默认生成 vga_custom.bin
  python3 img2bin.py 你的照片.jpg -o my_vga.bin       # 指定输出文件名
  python3 img2bin.py 你的照片.jpg --stretch           # 强制拉伸（不保持比例）
"""

import argparse
import os
import struct
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("缺少 Pillow 库，请执行: pip3 install Pillow")

# 图像参数
IMG_W = 256
IMG_H = 256
IMG_BYTES = IMG_W * IMG_H * 4  # 262144

# vga.bin 中图像数据的固定偏移
VGA_IMAGE_OFFSET = 0x4AF00
VGA_FILE_SIZE = 569088  # 完整的 vga.bin 应为 569088 字节

# 脚本和 bin 文件所在的同级目录
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_VGA_SRC = os.path.join(BASE_DIR, "vga.bin")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="图片 → minirvEMU 兼容的 .bin 转换器 (直接修改 vga.bin)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("image", help="输入图片路径（支持 jpg/png/bmp 等）")
    parser.add_argument("-o", "--output", default="vga_custom.bin", help="输出 .bin 文件名 (默认: vga_custom.bin)")
    parser.add_argument("--stretch", action="store_true", help="强制拉伸到 256x256（不保持宽高比），默认居中裁剪")
    return parser.parse_args()


def resize_and_extract_pixels(img: Image.Image, stretch: bool):
    """将图片处理为 256×256 并返回 [B, G, R, 0x00] 字节列表。"""
    w, h = img.size

    if stretch:
        resized = img.resize((IMG_W, IMG_H), Image.LANCZOS)
    else:
        target_aspect = IMG_W / IMG_H
        src_aspect = w / h
        if src_aspect > target_aspect:
            new_w = int(h * target_aspect)
            left = (w - new_w) // 2
            cropped = img.crop((left, 0, left + new_w, h))
        else:
            new_h = int(w / target_aspect)
            top = (h - new_h) // 2
            cropped = img.crop((0, top, w, top + new_h))
        resized = cropped.resize((IMG_W, IMG_H), Image.LANCZOS)

    if resized.mode == "RGBA":
        bg = Image.new("RGBA", resized.size, (255, 255, 255, 255))
        bg.paste(resized, (0, 0), resized)
        resized = bg.convert("RGB")
    elif resized.mode != "RGB":
        resized = resized.convert("RGB")

    pixels = resized.load()
    raw = bytearray()
    for y in range(IMG_H):
        for x in range(IMG_W):
            r, g, b = pixels[x, y]
            raw += struct.pack("BBBB", b, g, r, 0x00)

    return bytes(raw)


def main():
    args = parse_args()

    # 1. 处理图片
    if not os.path.isfile(args.image):
        sys.exit(f"错误: 找不到图片文件 '{args.image}'")
    img = Image.open(args.image)
    pixel_data = resize_and_extract_pixels(img, args.stretch)
    img.close()

    # 2. 读取 vga.bin 模板
    if not os.path.isfile(DEFAULT_VGA_SRC):
        sys.exit(f"错误: 找不到 vga.bin 模板文件 '{DEFAULT_VGA_SRC}'")
    with open(DEFAULT_VGA_SRC, "rb") as f:
        vga_data = bytearray(f.read())

    if len(vga_data) != VGA_FILE_SIZE:
        print(f"警告: vga.bin 大小 {len(vga_data)} ≠ 期望 {VGA_FILE_SIZE}，仍将尝试写入。")

    # 3. 写入图像数据
    needed = VGA_IMAGE_OFFSET + IMG_BYTES
    if len(vga_data) < needed:
        vga_data.extend(b"\x00" * (needed - len(vga_data)))

    vga_data[VGA_IMAGE_OFFSET : VGA_IMAGE_OFFSET + IMG_BYTES] = pixel_data

    # 4. 保存输出文件
    out_path = os.path.join(BASE_DIR, args.output)
    with open(out_path, "wb") as f:
        f.write(vga_data)

    print(f"✅ 已将图像写入 vga.bin 的 0x{VGA_IMAGE_OFFSET:05X} 偏移")
    print(f"   输出文件: {out_path}  ({len(vga_data)} 字节)")
    print(f"   运行模拟器时，请将 {args.output} 重命名为 vga.bin 供其读取")


if __name__ == "__main__":
    main()