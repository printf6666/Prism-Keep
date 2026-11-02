"""抠出炎拳角色立绘。
流程：裁边 → 内圈泛洪去背景 → 清除浅灰小杂质 → 只保留最大连通块（角色本体）→ 裁包围盒。
"""
from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\14027\.zcode\cli\image-cache\session_24f0806d113bbaf6dadbc6ae21aea56d\image-0109436c6e8693ae6b060d195c1351d4.png")
OUT = Path(r"D:\Prism-Keep\assets\hero_flame_fist.png")

img = Image.open(SRC).convert("RGBA")
img = img.crop((3, 3, img.width - 3, img.height - 3))   # 去掉外圈暗红描边
w, h = img.size
px = img.load()


def is_bg(p):
    r, g, b, a = p
    if a == 0:
        return False
    mx, mn = max(r, g, b), min(r, g, b)
    return mx >= 190 and (mx - mn) <= 24   # 浅灰/白、低饱和


def components():
    """返回 [(像素列表, 均色)]，按面积从大到小。"""
    seen = [[False] * w for _ in range(h)]
    out = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] == 0:
                continue
            comp = []
            dq = deque([(sx, sy)])
            seen[sy][sx] = True
            while dq:
                x, y = dq.popleft()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                        seen[ny][nx] = True
                        dq.append((nx, ny))
            out.append(comp)
    out.sort(key=len, reverse=True)
    return out


# 1) 从四边泛洪去背景
seen = [[False] * w for _ in range(h)]
q = deque()
for x in range(w):
    q.append((x, 0))
    q.append((x, h - 1))
for y in range(h):
    q.append((0, y))
    q.append((w - 1, y))
while q:
    x, y = q.popleft()
    if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
        continue
    seen[y][x] = True
    if not is_bg(px[x, y]):
        continue
    px[x, y] = (0, 0, 0, 0)
    q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

# 2) 清掉浅灰小杂质（顶部 UI 块 / 虚线等）
comps = components()
for comp in comps:
    if len(comp) > 2500:
        continue
    rs = gs = bs = 0
    for (x, y) in comp:
        r, g, b, _ = px[x, y]
        rs += r
        gs += g
        bs += b
    n = len(comp)
    mr, mg, mb = rs / n, gs / n, bs / n
    if max(mr, mg, mb) > 130 and (max(mr, mg, mb) - min(mr, mg, mb)) < 32:
        for (x, y) in comp:
            px[x, y] = (0, 0, 0, 0)

# 3) 只保留最大连通块（角色本体），边框残留一并清掉
comps = components()
if comps:
    keep = set(comps[0])
    print("character pixels:", len(keep), "/", w * h)
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0 and (x, y) not in keep:
                px[x, y] = (0, 0, 0, 0)

# 4) 清掉两处灰色模糊遮挡残留（只清低饱和像素，保住深色裙摆）
def desaturate_region(x0, y0, x1, y1, sat_max=45):
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if max(r, g, b) - min(r, g, b) <= sat_max:
                px[x, y] = (0, 0, 0, 0)


desaturate_region(370, 215, w, h)     # 右下模糊块
desaturate_region(0, 258, 95, h)      # 左下模糊块

# 5) 裁成人物胸像构图（头部居中），再按 alpha 收紧
img = img.crop((150, 0, 400, 278))
bbox = img.getbbox()
print("bbox", bbox)
img = img.crop(bbox)
print("cropped", img.size)
img.save(OUT)
print("saved", OUT)