# -*- coding: utf-8 -*-
"""静境 PWA 图标生成：深空底 + 中央青白光球渐晕（CYBER-ZEN 深色，纯 PIL，无外部素材）。

用法: python tool/gen_icons.py   （在项目根执行，写入 web/icons/ 与 web/favicon.png）
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "web", "icons")

VOID_BLACK = (10, 10, 15)        # theme.dart voidBlack #0a0a0f
DEEP_SPACE = (18, 18, 26)        # deepSpace #12121a
NEBULA_CYAN = (103, 232, 249)    # nebulaCyan #67e8f9
NEON_GLOW = (0, 212, 255)        # neonGlow #00d4ff
STAR_WHITE = (240, 240, 255)     # starWhite #f0f0ff


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def make_icon(size: int, maskable: bool = False) -> Image.Image:
    """深空径向底 + 中央青白光球（高斯式渐晕）+ 外圈细环。"""
    # 超采样 4x 再缩小，渐晕平滑无锯齿
    s = size * 4
    img = Image.new("RGB", (s, s), VOID_BLACK)
    px = img.load()
    cx = cy = (s - 1) / 2.0
    # 光球核心半径（占短边比例）；maskable 留更多安全区（四周 10% 会被裁）
    core = (0.16 if not maskable else 0.13) * s
    halo = core * 1.9
    for y in range(s):
        dy2 = (y - cy) ** 2
        for x in range(s):
            d = math.sqrt((x - cx) ** 2 + dy2)
            # 背景：从中心 deepSpace 到边缘 voidBlack 的径向暗渐变
            bg = lerp(DEEP_SPACE, VOID_BLACK, min(1.0, d / (s * 0.55)))
            if d < halo:
                # 光球：核心 starWhite → 中段 neonGlow/cyan → 边缘融入背景
                if d < core:
                    t = d / core
                    col = lerp(STAR_WHITE, NEBULA_CYAN, t * t)
                else:
                    t = (d - core) / (halo - core)  # 0..1
                    col = lerp(NEBULA_CYAN, bg, t * t)
                px[x, y] = col
            else:
                px[x, y] = bg
    # 外圈细环（克制的青色描边，半径 0.42s；maskable 收进安全区）
    ring_r = (0.36 if not maskable else 0.31) * s
    ring_w = max(1, s // 96)
    d = ImageDraw.Draw(img)
    d.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=lerp(NEON_GLOW, VOID_BLACK, 0.35),
        width=ring_w,
    )
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ICONS, exist_ok=True)
    for size in (192, 512):
        make_icon(size).save(os.path.join(ICONS, "Icon-%d.png" % size))
        make_icon(size, maskable=True).save(
            os.path.join(ICONS, "Icon-maskable-%d.png" % size))
    # apple-touch-icon 180（iOS 惯例，不透明深空底）
    make_icon(180).save(os.path.join(ICONS, "Icon-180.png"))
    # favicon：PIL 直接产出多尺寸 .ico
    ico_sizes = [(16, 16), (32, 32), (48, 48)]
    make_icon(48).save(os.path.join(ROOT, "web", "favicon.png"))
    make_icon(48).save(
        os.path.join(ROOT, "web", "favicon.ico"),
        format="ICO", sizes=ico_sizes)
    print("icons written to", ICONS)


if __name__ == "__main__":
    main()
