import copy
import unittest

from PIL import Image
from compare_bil39_purchase_cta import compare_frame


class CheckoutComparisonTest(unittest.TestCase):
    def setUp(self):
        self.image = Image.new('RGBA', (390, 844), (1, 2, 3, 255))
        self.geometry = {'capture_size': [390, 844], 'cta_bounds': [20, 776, 370, 832],
                         'glyph_bounds': [337, 794, 357, 814],
                         'feature_arrow_bounds': [45, 570, 64, 589]}

    def check(self, image, geometry=None):
        return compare_frame(image, self.image, geometry or self.geometry, self.geometry)

    def test_identical_is_accepted(self):
        self.check(self.image)

    def test_only_separate_reviewed_chevron_decoration_is_accepted(self):
        candidate = self.image.copy(); candidate.putpixel((38, 563), (4, 5, 6, 255))
        self.check(candidate)

    def test_every_checkout_and_halo_mutation_is_rejected(self):
        for point in [(30, 780), (340, 800), (10, 760), (375, 840), (200, 755)]:
            with self.subTest(point=point):
                candidate = self.image.copy(); candidate.putpixel(point, (4, 5, 6, 255))
                with self.assertRaises(ValueError): self.check(candidate)

    def test_alpha_only_mutation_is_rejected(self):
        candidate = self.image.copy(); candidate.putpixel((340, 800), (1, 2, 3, 200))
        with self.assertRaises(ValueError): self.check(candidate)

    def test_unrelated_page_mutation_is_rejected(self):
        candidate = self.image.copy(); candidate.putpixel((100, 100), (4, 5, 6, 255))
        with self.assertRaises(ValueError): self.check(candidate)

    def test_each_geometry_change_is_rejected(self):
        for key in self.geometry:
            with self.subTest(key=key):
                geometry = copy.deepcopy(self.geometry); geometry[key][0] += 1
                with self.assertRaises(ValueError): self.check(self.image, geometry)

    def test_exception_cannot_cover_checkout(self):
        geometry = copy.deepcopy(self.geometry)
        geometry['feature_arrow_bounds'] = [337, 794, 357, 814]
        with self.assertRaises(ValueError):
            compare_frame(self.image, self.image, geometry, geometry)


if __name__ == '__main__':
    unittest.main()
