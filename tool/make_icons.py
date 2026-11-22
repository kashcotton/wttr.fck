"""Generates every app icon + the social preview image.

    python3 tool/make_icons.py

Needs Pillow. Uses the bundled Google Sans Flex font.
"""
from PIL import Image, ImageDraw, ImageFont

FONT = 'assets/fonts/GoogleSansFlex.ttf'
BG = (31, 52, 77, 255)
FG = (244, 246, 248, 255)
SUN = (242, 165, 22, 255)

def font(size, weight=800):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight if a.get('name') == b'Weight' else a['default']
                                 for a in f.get_variation_axes()])
    except Exception:
        try:
            f.set_variation_by_name('Bold')
        except Exception:
            pass
    return f

def art(d, S, ox=0, oy=0, scale=1.0, text=True):
    def p(x, y):
        return (ox + x * S * scale, oy + y * S * scale)
    r = 0.13
    cx, cy = 0.66, 0.30
    d.ellipse([*p(cx - r, cy - r), *p(cx + r, cy + r)], fill=SUN)
    d.ellipse([*p(0.20, 0.30), *p(0.50, 0.60)], fill=FG)
    d.ellipse([*p(0.40, 0.24), *p(0.74, 0.58)], fill=FG)
    d.rounded_rectangle([*p(0.14, 0.44), *p(0.84, 0.62)], radius=int(0.09 * S * scale), fill=FG)
    if text:
        f = font(int(0.19 * S * scale))
        t = 'wttr.fck'
        tw = d.textlength(t, font=f)
        d.text((ox + (S * scale - tw) / 2, oy + 0.665 * S * scale), t, font=f, fill=FG)

def icon(n, shape='rounded', text=True, safe=1.0):
    S = n * 4
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if shape == 'rounded':
        d.rounded_rectangle((0, 0, S - 1, S - 1), radius=int(S * 0.23), fill=BG)
    else:
        d.rectangle((0, 0, S, S), fill=BG)
    off = S * (1 - safe) / 2
    art(d, S, off, off, safe, text)
    return im.resize((n, n), Image.LANCZOS)

WIDGET_ICONS = {
    'ic_w_sun': 0xf02ae, 'ic_w_moon': 0xe42f, 'ic_w_partly': 0xf02aa,
    'ic_w_partly_night': 0xf0008, 'ic_w_cloud': 0xf650, 'ic_w_fog': 0xf0505,
    'ic_w_drizzle': 0xf7bc, 'ic_w_rain': 0xf03b4, 'ic_w_snow': 0xf516,
    'ic_w_storm': 0xf0823, 'ic_refresh': 0xf00e9, 'ic_near_me': 0xf8f8,
}

def widget_icons():
    import os
    from fontTools.ttLib import TTFont
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    root = os.environ.get('FLUTTER_ROOT', os.path.expanduser('~/flutter'))
    f = TTFont(f'{root}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
    asc, desc = f['hhea'].ascent, f['hhea'].descent
    cmap, gs = f.getBestCmap(), f.getGlyphSet()
    for name, cp in WIDGET_ICONS.items():
        g = gs[cmap[cp]]
        pen = SVGPathPen(gs)

        g.draw(TransformPen(pen, (1, 0, 0, -1, 0, asc)))
        with open(f'android/app/src/main/res/drawable/{name}.xml', 'w') as out:
            out.write(f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="{g.width}" android:viewportHeight="{asc - desc}">
  <path android:fillColor="#FFFFFFFF" android:pathData="{pen.getCommands()}"/>
</vector>
''')

def main():
    for name, n in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        icon(n, 'square').save(f'android/app/src/main/res/mipmap-{name}/ic_launcher.png')
    icon(256).save('windows/runner/resources/app_icon.ico',
                   sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    icon(512).save('assets/icon.png')
    icon(192).save('web/icons/Icon-192.png')
    icon(512).save('web/icons/Icon-512.png')

    icon(192, 'square', safe=0.78).save('web/icons/Icon-maskable-192.png')
    icon(512, 'square', safe=0.78).save('web/icons/Icon-maskable-512.png')
    icon(64, text=False).save('web/favicon.png')

    W, H = 1200, 630
    og = Image.new('RGBA', (W, H), BG)
    d = ImageDraw.Draw(og)
    art(d, 420, 70, 70, 1.0, text=False)
    d.text((520, 190), 'wttr.fck', font=font(118), fill=FG)
    d.text((524, 340), "It's fucking raining.", font=font(48, 600), fill=SUN)
    d.text((524, 410), 'Free weather. Zero chill.', font=font(40, 400), fill=FG)
    og.convert('RGB').save('web/og.png')
    widget_icons()

if __name__ == '__main__':
    main()
