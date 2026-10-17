"""Bake readable silhouettes into existing art; no per-object runtime outline pass."""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'art_source/clarity-manifest.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def clarify(image, family, name):
    image = image.convert('RGBA')
    alpha = image.getchannel('A')
    if family == 'objects' and name in ['xp', 'heal', 'core', 'drive', 'shell', 'sentry', 'mine']:
        box = alpha.point(lambda a: 255 if a > 32 else 0).getbbox()
        if not box:
            raise ValueError('Empty solid object: ' + name)
        # Scale around the existing texture pivot, including asymmetric equipment.
        extent = max(image.width / 2 - box[0], box[2] - image.width / 2,
                     image.height / 2 - box[1], box[3] - image.height / 2)
        scale = min(image.size) * .43 / extent
        resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
        centered = Image.new('RGBA', image.size)
        centered.alpha_composite(resized, ((image.width - resized.width) // 2, (image.height - resized.height) // 2))
        image = centered
        alpha = image.getchannel('A')
    if family == 'fx' and name != 'container':
        image = ImageEnhance.Contrast(image).enhance(1.08)
        image.putalpha(alpha.point(lambda a: round(255 * (a / 255) ** 1.12)))
        return image
    image = ImageEnhance.Contrast(image).enhance(1.12)
    image = image.filter(ImageFilter.UnsharpMask(radius=3, percent=65, threshold=6))
    alpha = alpha.point(lambda a: round(255 * min(1, max(0, (a / 255 - .015) / .97)) ** .8))
    rim_width = 13 if image.width >= 512 else 7
    inner = ImageChops.subtract(alpha, alpha.filter(ImageFilter.MinFilter(rim_width)))
    light = Image.new('RGBA', image.size, (196, 228, 237, 0))
    light.putalpha(inner.point(lambda a: round(a * .65)))
    image.putalpha(alpha)
    image = Image.alpha_composite(image, light)
    shadow = Image.new('RGBA', image.size, (3, 9, 17, 0))
    shadow.putalpha(alpha.filter(ImageFilter.MaxFilter(23 if image.width >= 512 else 13)))
    image = Image.alpha_composite(shadow, image)
    if family == 'objects' and name == 'heal':
        draw = ImageDraw.Draw(image)
        cx, cy = image.width // 2, image.height // 2
        arm, half = round(image.width * .13), round(image.width * .045)
        points = [(cx-half, cy-arm), (cx+half, cy-arm), (cx+half, cy-half), (cx+arm, cy-half),
                  (cx+arm, cy+half), (cx+half, cy+half), (cx+half, cy+arm), (cx-half, cy+arm),
                  (cx-half, cy+half), (cx-arm, cy+half), (cx-arm, cy-half), (cx-half, cy-half)]
        draw.polygon(points, fill=(244, 255, 246, 255), outline=(3, 25, 16, 255), width=8)
    return image


def apply():
    previous = json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {}
    entries = {}
    for path in sorted((ROOT / 'assets/art').rglob('*')):
        if path.suffix not in ['.png', '.svg']:
            continue
        key = path.relative_to(ROOT / 'assets/art').with_suffix('').as_posix()
        before = digest(path)
        # shortcut: regenerate base art before changing this profile; hashes prevent cumulative processing.
        if previous.get(key, {}).get('output_sha256') == before:
            entries[key] = previous[key]
            continue
        family, name = key.split('/')
        entry = {'source_sha256': before, 'family': family}
        if path.suffix == '.png':
            with Image.open(path) as original:
                original = original.convert('RGBA')
                entry.update(size=list(original.size), source_alpha_bounds=original.getchannel('A').getbbox())
                if family != 'world':
                    result = clarify(original, family, name)
                    assert result.getchannel('A').getpixel((0, 0)) == 0, key
                    result.save(path, optimize=True)
                    entry['alpha_bounds'] = result.getchannel('A').getbbox()
                    entry['treatment'] = 'soft core separation' if family == 'fx' and name != 'container' else 'baked silhouette and material contrast'
                else:
                    entry['treatment'] = 'source retained; contrast separated in space shader'
        elif family == 'ui':
            source = path.read_text(encoding='utf-8')
            source = source.replace('stroke-width="6"', 'stroke-width="7.5"').replace('stroke-width="2.8"', 'stroke-width="3.8"').replace('opacity=".55"', 'opacity=".3"')
            source = source.replace('viewBox="0 0 64 64"', 'viewBox="-3 -3 70 70"')
            path.write_text(source, encoding='utf-8')
            entry['treatment'] = 'stronger diagram strokes and quieter corner marks'
        else:
            entry['treatment'] = 'projectile radius preserved; explicit core rim'
        entry['output_sha256'] = digest(path)
        entries[key] = entry
    MANIFEST.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Clarity coverage: {len(entries)} production textures')


if __name__ == '__main__':
    apply()
