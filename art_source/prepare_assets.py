"""Reproducible atlas slicing, alpha padding and authored SVG equipment diagrams."""
from pathlib import Path
from PIL import Image
import json, shutil, math
import hashlib
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'art_source/raw'; RAW.mkdir(exist_ok=True)
GEN=Path('C:/Users/home/.codex/generated_images/01a12d72-f600-79a3-b0d0-10fafc0fa128')
sources={
'ships/striker':'exec-4a8724a5-0404-4edb-8a76-8ab6c2bf7a24.png',
'ships/scout':'exec-83a022df-df03-4003-8691-93f9c78afa04.png',
'ships/bastion':'exec-6216478e-8ee9-487e-a8bb-2d10e39113cb.png',
'enemies/boss':'exec-8fd7ca24-62e8-438d-b8a4-963b30fbdc54.png',
'objects/planet':'exec-c9d68cf3-fc05-4034-bd1c-5f3333004599.png',
'world/ring':'exec-c5b47860-43b4-40b8-94b1-d12edcf0940d.png',
'world/storm':'exec-8f8b783f-e689-4e44-91cd-9622e0166554.png',
'world/forge':'exec-ff92cb0e-2ae0-4f71-827d-af49485dece7.png'}
def padded(im,size=512):
    im=im.convert('RGBA'); bounds=im.getchannel('A').point(lambda v:255 if v>32 else 0).getbbox()
    assert bounds, 'Empty alpha'
    im=im.crop(bounds); im.thumbnail((round(size*.90),round(size*.90)),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',(size,size)); out.alpha_composite(im,((size-im.width)//2,(size-im.height)//2)); return out
def preserve(src,dst):
    if dst.exists():
        assert hashlib.sha256(src.read_bytes()).digest()==hashlib.sha256(dst.read_bytes()).digest(), f'Source changed: {dst}'
    else: shutil.copy2(src,dst)
for key,name in sources.items():
    src=GEN/name; preserve(src,RAW/(key.replace('/','_')+'.png'))
    out=ROOT/'assets/art'/f'{key}.png'; out.parent.mkdir(parents=True,exist_ok=True)
    im=Image.open(src)
    if not key.startswith('world/'): im=padded(im)
    im.save(out,optimize=True)
sheet=GEN/'exec-68b66980-2616-45e1-8156-4027711a14c0.png'; preserve(sheet,RAW/'enemy-sheet.png')
im=Image.open(sheet)
for i,key in enumerate(['chaser','runner','tank','shooter','elite_assault','elite_artillery']):
    x=i%3; y=i//3
    cell=im.crop((round(x*im.width/3),y*im.height//2,round((x+1)*im.width/3),(y+1)*im.height//2))
    padded(cell,256).save(ROOT/'assets/art/enemies'/f'{key}.png',optimize=True)
# Each diagram describes a particular equipment mechanism; no generic shape fallback.
paths={
'power':'M22 17L30 12H35V52H30L22 47ZM42 17L34 12M42 17V47L34 52M29 23H35V41H29Z',
'speed':'M13 18H26V40L20 47L13 40ZM38 18H51V40L44 47L38 40M17 49L20 55L23 49M41 49L44 55L47 49',
'rapid':'M12 17H42L51 21L42 25H12ZM18 28H48L56 32L48 36H18ZM12 39H42L51 43L42 47H12',
'repair':'M27 23H37V28H43V38H37V43H27V38H21V28H27ZM15 21A23 23 0 1 1 12 42M11 15L15 21L22 20',
'heal':'M15 20L21 14H43L49 20V49H15ZM27 23H37V29H43V39H37V45H27V39H21V29H27Z',
'stun':'M21 13V51M43 13V51M13 21H51M13 43H51M28 28H36V36H28Z',
'emp':'M26 26L32 23L38 26V38L32 41L26 38ZM17 19A21 21 0 0 0 17 45M47 19A21 21 0 0 1 47 45M32 8V15M32 49V56M8 32H15M49 32H56',
'frenzy':'M35 10L18 34H29L25 54L47 27H35ZM10 19H19M45 45H55',
'insight':'M23 32L32 21L41 32L32 43ZM12 32L20 22M44 22L52 32L44 42M32 10V16M32 48V54',
'bounty':'M22 18L42 18L52 32L42 46H22L12 32ZM24 25H40L24 39H40M32 8V12M49 12L45 17M56 23L51 25',
'shield':'M15 15L32 10L49 15V34L42 45L32 53L22 45L15 34ZM23 22L32 19L41 22V33L32 43L23 33Z',
'haste':'M17 16A23 23 0 1 0 47 16M26 16L43 32L26 48ZM32 8V14',
'orbit':'M14 32A18 18 0 1 0 50 32A18 18 0 1 0 14 32M29 29H35V35H29M8 28H17V36H8M45 28H54V36H45M28 8H36V17H28',
'orbit_range':'M20 32A12 12 0 1 0 44 32A12 12 0 1 0 20 32M9 32H19M45 32H55M13 27L8 32L13 37M51 27L56 32L51 37',
'blade':'M18 46L27 32L20 19L44 11L36 29L49 42L28 53ZM25 43L37 31',
'frost':'M32 8V56M11 20L53 44M11 44L53 20M25 14L32 21L39 14M18 25L20 32L12 35M46 39L44 32L52 29M25 50L32 43L39 50',
'magnet':'M18 12V35A14 14 0 0 0 46 35V12H36V35A4 4 0 0 1 28 35V12ZM17 22H28M36 22H47M10 48L15 43M54 48L49 43M30 53H34',
'vitality':'M14 18L32 10L50 18L46 42L32 53L18 42ZM28 21H36V29H44V37H36V45H28V37H20V29H28Z',
'dash':'M17 22L44 32L17 42L23 32ZM4 25H14M4 39H14M47 24L57 32L47 40',
'missile':'M15 43L40 18L48 16L46 24L21 49ZM32 26L40 34M12 43L9 54L21 51M27 33L18 28L14 35M32 39L36 50L43 44',
'chain':'M12 19L26 29L38 18L51 38M8 14H17V24H8ZM22 25H32V35H22ZM34 13H44V23H34ZM46 33H56V43H46Z',
'pulse':'M28 28H36V36H28ZM22 19A17 17 0 1 0 42 19M16 11A27 27 0 1 0 48 11',
'focus_amp':'M15 13V46H24V13M40 13V46H49V13M26 32H38M32 22V42M27 8H37',
'focus_memory':'M17 17V38H24V17M40 17V38H47V17M20 47A18 18 0 0 0 50 39M14 42L20 47L27 45M28 25H36V33H28',
'scout_lance':'M10 32L49 16L42 32L49 48ZM36 32H56M50 26L56 32L50 38',
'scout_drive':'M10 26L27 32L10 38ZM32 26L42 32L32 38M46 26L56 32L46 38M8 15H28M8 49H28',
'guard_reserve':'M12 16L26 11L40 16V32L26 47L12 32ZM29 20L43 15L55 20V36L43 51L35 45',
'guard_pulse':'M12 16L26 11L40 16V32L26 47L12 32M44 24A14 14 0 0 1 44 43M51 17A23 23 0 0 1 51 50',
'restore':'M14 20H50V48H14ZM27 24H37V29H42V39H37V44H27V39H22V29H27ZM24 12H40V20',
'burst':'M28 28H36V36H28ZM10 32H21M43 32H54M32 10V21M32 43V54M16 16L23 23M41 41L48 48M16 48L23 41M41 23L48 16',
'fortune':'M12 18L28 12L44 18V36L28 46L12 36ZM35 35H45V41H51V51H45V57H35V51H29V41H35Z',
'superorbit':'M15 32A17 17 0 1 0 49 32A17 17 0 1 0 15 32M10 27H20V37H10ZM44 27H54V37H44ZM27 10H37V20H27ZM28 44H36V54H28Z',
'storm':'M8 18L23 30L37 13L55 30L41 48L25 40L10 52M18 26H28V36H18ZM36 43H46V53H36Z',
'salvo':'M12 43L25 30L30 29L29 34L16 47ZM25 32L38 19L43 18L42 23L29 36ZM38 45L51 32L56 31L55 36L42 49Z',
'rail':'M8 30H53V34H8ZM20 20V44M32 20V44M44 20V44M49 23L58 32L49 41',
'blizzard':'M32 8L52 20V44L32 56L12 44V20ZM32 17V47M19 24L45 40M19 40L45 24M26 19L32 25L38 19',
'nova':'M23 32A9 9 0 1 0 41 32A9 9 0 1 0 23 32M11 21A24 24 0 0 0 11 43M53 21A24 24 0 0 1 53 43M13 15L21 21M43 43L51 51M13 49L21 43M43 21L51 13',
'sentry':'M32 12L52 48H12ZM22 31H42V40H22ZM29 16H35V33H29M20 48V54M44 48V54',
'wake':'M37 22L55 32L37 42L42 32ZM6 23H16M21 23H31M6 32H20M25 32H35M6 41H16M21 41H31',
'citadel':'M12 20L32 10L52 20V44L32 54L12 44ZM22 25L32 20L42 25V39L32 44L22 39ZM4 27V37M60 27V37',
'ellipse':'M8 32C8 10 56 10 56 32C56 54 8 54 8 32ZM28 28H36V36H28M6 28H14V36H6M50 28H58V36H50',
'hatchet':'M17 50L42 14M26 23L35 9L54 18L47 36L36 29ZM12 44L22 51',
'minefield':'M24 24H40V40H24ZM32 12V24M32 40V52M12 32H24M40 32H52M16 16L24 24M40 40L48 48M16 48L24 40M40 24L48 16',
'core':'M20 20L32 12L44 20V44L32 52L20 44ZM27 24H37V40H27Z',
'drive':'M13 18H26V40L20 49L13 40ZM38 18H51V40L44 49L38 40M20 52V57M44 52V57',
'shell':'M12 21L32 10L52 21V43L32 54L12 43ZM21 26L32 20L43 26V38L32 44L21 38Z',
'lancer':'M8 32L49 15L41 32L49 49ZM30 32H58M19 19V45',
'battery':'M10 19H44L54 24L44 29H10ZM10 35H44L54 40L44 45H10M19 29V35M35 29V35',
'aegis':'M12 16L32 9L52 16V37L32 55L12 37ZM20 22L32 18L44 22V34L32 45L20 34M5 26V38M59 26V38',
'trinity':'M32 10L51 43H13ZM27 8H37V18H27ZM8 39H18V49H8ZM46 39H56V49H46ZM27 28H37V38H27Z',
'survive':'M16 16L32 10L48 16V36L32 51L16 36M25 20H39V39H25M32 22V30L37 34',
'outer':'M24 13A19 19 0 1 0 24 51M30 32H55M46 24L55 32L46 40',
'outer_kills':'M17 12A23 23 0 0 0 17 52M36 21A11 11 0 1 0 36 43A11 11 0 1 0 36 21M36 15V27M36 37V49M19 32H31M41 32H53',
'returns':'M23 10V54M9 23H48L42 17M55 41H16L22 47',
'dash_hits':'M8 24L30 32L8 40L13 32ZM38 18V27M38 37V46M43 32H55M31 22L34 25M31 42L34 39',
'overdrive':'M22 15L42 15L53 32L42 49H22L11 32ZM28 21H36V43H28M25 9V15M39 9V15',
'normal':'M19 20L32 12L45 20V44L32 52L19 44ZM28 25H36V39H28',
'relaxed':'M16 22L32 14L48 22V40L32 50L16 40M22 32L29 39L43 25',
'veteran':'M12 20L24 14L32 22L40 14L52 20V43L32 54L12 43M21 30L32 41L43 30',
'cataclysm':'M32 8L55 22L48 49L32 56L16 49L9 22ZM22 20L42 44M42 20L22 44',
'achievement':'M16 12H48V29L32 44L16 29ZM16 18H8V27L20 34M48 18H56V27L44 34M32 44V52M22 54H42',
}
fxsrc=GEN/'exec-85f0fb4a-e21c-4e6d-8fdb-c39f13da5d81.png'
preserve(fxsrc,RAW/'fx-sheet.png'); fx=Image.open(fxsrc)
(ROOT/'assets/art/fx').mkdir(exist_ok=True)
for i,key in enumerate(['spark','explosion','wave','thrust','black_hole','container']):
    x=i%3; y=i//3
    cell=fx.crop((round(x*fx.width/3)+2,y*fx.height//2+2,round((x+1)*fx.width/3)-2,(y+1)*fx.height//2-2))
    padded(cell,512 if key=='black_hole' else 256).save(ROOT/'assets/art/fx'/f'{key}.png',optimize=True)
ui=ROOT/'assets/art/ui'; ui.mkdir(exist_ok=True)
for key,d in paths.items():
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><defs><linearGradient id="metal" x2=".7" y2="1"><stop stop-color="#eef6ee"/><stop offset=".48" stop-color="#a7ced7"/><stop offset="1" stop-color="#59818e"/></linearGradient></defs><path d="{d}" fill="none" stroke="#06111b" stroke-width="6" stroke-linejoin="round"/><path d="{d}" fill="none" stroke="url(#metal)" stroke-width="2.8" stroke-linejoin="round" stroke-linecap="round"/><path d="M7 7H18M7 7V18M57 57H46M57 57V46" fill="none" stroke="#5a8894" stroke-width="1" opacity=".55"/></svg>'''
    (ui/f'{key}.svg').write_text(svg,encoding='utf-8')
assets={}
for group in ['ships','enemies','world','objects','ui','fx']:
    for p in sorted((ROOT/'assets/art'/group).glob('*')):
        if p.suffix in ['.png','.svg']: assets[f'{group}/{p.stem}']='res://'+p.relative_to(ROOT).as_posix()
gd='class_name ArtAssets\nextends RefCounted\n\nconst TEXTURES := {\n'+''.join(f'\t"{k}": preload("{v}"),\n' for k,v in assets.items())+'}\n'
gd+='''
static func texture(id: String) -> Texture2D:
	assert(TEXTURES.has(id), "Missing production art: " + id)
	return TEXTURES.get(id)

static func sprite(canvas: CanvasItem, id: String, at: Vector2, size: Vector2, angle: float = 0.0, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	if is_zero_approx(angle):
		canvas.draw_texture_rect(texture(id), Rect2(at - size * 0.5, size), false, tint)
		return
	var x := Vector2.from_angle(angle) * size.x * 0.5
	var y := x.orthogonal() * (size.y / size.x)
	# Keep the caller transform so repeated hulls can share a canvas batch.
	canvas.draw_primitive(PackedVector2Array([at-x-y, at+x-y, at+x+y, at-x+y]), PackedColorArray([tint]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), texture(id))

static func icon(canvas: CanvasItem, at: Vector2, id: String, color: Color, scale: float = 1.0) -> void:
	canvas.draw_texture_rect(texture("ui/" + id), Rect2(at - Vector2.ONE * 18 * scale, Vector2.ONE * 36 * scale), false, color)

static func container(canvas: CanvasItem, at: Vector2, grade: String, radius: float) -> void:
	canvas.draw_texture_rect(texture("fx/container"), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	var rank: int = ["C","B","A"].find(grade) + 1
	var color: Color = {"C":Color("72dce6"),"B":Color("a798ff"),"A":Color("ffd18a")}.get(grade,Color.WHITE)
	for side in 4:
		for segment in rank:
			var a := PI * 0.25 + side * PI * 0.5 + (segment - rank * 0.5) * 0.18
			canvas.draw_arc(at, radius, a, a + 0.12, 3, color, 2, true)

static func achievement_icon(id: String) -> String:
	if id in ["item_types","part_types","evolved"]: return {"item_types":"power","part_types":"trinity","evolved":"superorbit"}[id]
	if id.begins_with("ship_"): return "normal"
	if id.begins_with("sector_"): return "outer"
	if id.begins_with("hull_"): return id.trim_prefix("hull_")
	if TEXTURES.has("ui/" + id): return id
	var family: String = id.rsplit("_", true, 1)[0]
	return {"missions":"survive", "parts":"core", "items":"power", "items_a":"bounty", "items_risky":"outer", "runs":"normal", "kills":"rail", "wins":"achievement", "dashes":"dash", "overdrives":"overdrive", "returns":"returns", "elites":"focus_amp", "time":"survive", "combo":"chain", "evolved":"superorbit", "item_types":"power", "part_types":"trinity"}.get(family, "achievement")
'''
(ROOT/'scripts/art_assets.gd').write_text(gd,encoding='utf-8')
(ROOT/'art_source/asset-manifest.json').write_text(json.dumps(assets,indent=2),encoding='utf-8')
print(f'Prepared {len(assets)} production resources')
if '--clarity' in __import__('sys').argv:
    from clarify_assets import apply
    apply()
