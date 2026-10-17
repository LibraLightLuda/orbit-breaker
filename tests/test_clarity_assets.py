import importlib.util
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('clarify_assets', Path(__file__).parents[1] / 'art_source/clarify_assets.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


class ClarityAssets(unittest.TestCase):
    def test_empty_object_is_rejected(self):
        with self.assertRaises(ValueError):
            art.clarify(Image.new('RGBA', (128, 128)), 'objects', 'xp')

    def test_asymmetric_body_keeps_pivot_and_alpha_padding(self):
        image = Image.new('RGBA', (512, 512))
        ImageDraw.Draw(image).rectangle((280, 180, 360, 300), fill='white')
        result = art.clarify(image, 'objects', 'core')
        box = result.getchannel('A').getbbox()
        self.assertGreater(box[0], 256)
        self.assertLess(box[2], 512)
        self.assertEqual(result.getpixel((0, 0))[3], 0)

    def test_pickup_visible_body_increases_without_texture_upscale(self):
        image = Image.new('RGBA', (512, 512))
        ImageDraw.Draw(image).polygon([(256,124),(349,256),(256,388),(163,256)], fill='cyan')
        result = art.clarify(image, 'objects', 'xp')
        self.assertEqual(result.size, image.size)
        original = image.getchannel('A').getbbox()
        box = result.getchannel('A').getbbox()
        self.assertGreater(box[3]-box[1], original[3]-original[1])
        self.assertLess(abs((box[0]+box[2])/2-256), 2)

    def test_light_keeps_soft_alpha_and_heal_has_unique_core(self):
        image = Image.new('RGBA', (512, 512))
        ImageDraw.Draw(image).ellipse((163,124,349,388), fill=(70,180,160,180))
        fx = art.clarify(image, 'fx', 'thrust')
        self.assertTrue(0 < fx.getpixel((256,256))[3] < 180)
        self.assertNotEqual(art.clarify(image, 'objects', 'heal').tobytes(), art.clarify(image, 'objects', 'xp').tobytes())


if __name__ == '__main__':
    unittest.main()
