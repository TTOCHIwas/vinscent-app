import base64
from pathlib import Path
import unittest
import io
import media_runtime as runtime

ROOT = Path(__file__).resolve().parents[1] / 'fixtures' / 'media-ko'


class DecoderTests(unittest.TestCase):
    def data(self, name, mime):
        return {'bytes': base64.b64encode((ROOT / name).read_bytes()).decode('ascii'), 'mimeType': mime}

    def test_app_image_formats_decode_pixels(self):
        for name, mime in [('image-normal-ko.jpg', 'image/jpeg'), ('image-threat-ko.webp', 'image/webp')]:
            with self.subTest(name=name):
                result = runtime.decoded_image(self.data(name, mime))
                self.assertEqual(result['width'], 640)
                self.assertEqual(result['height'], 480)
                self.assertGreater(len(result['pngBase64']), 0)

    def test_app_m4a_decodes_real_samples(self):
        result = runtime.decoded_audio(self.data('audio-normal-ko.m4a', 'audio/mp4'))
        self.assertEqual(result['sampleRate'], 16000)
        self.assertGreater(result['samples'], 0)
        self.assertLessEqual(result['durationMs'], 15000)

    def test_corrupt_app_formats_fail(self):
        for name, mime in [('codec-corrupt-m4a.m4a', 'audio/mp4'), ('codec-corrupt-jpeg.jpg', 'image/jpeg'),
                           ('codec-corrupt-webp.webp', 'image/webp')]:
            with self.subTest(name=name), self.assertRaises(Exception):
                method = runtime.decoded_audio if mime.startswith('audio') else runtime.decoded_image
                method(self.data(name, mime))

    def test_declared_mime_must_match_actual_image(self):
        with self.assertRaises(Exception):
            runtime.decoded_image(self.data('image-normal-ko.jpg', 'image/webp'))

    def test_empty_and_unsupported_inputs_fail(self):
        for data in [{'bytes': '', 'mimeType': 'image/png'}, self.data('image-unsupported.svg', 'image/svg+xml')]:
            with self.subTest(data=data['mimeType']), self.assertRaises(Exception):
                runtime.decoded_image(data)

    def test_noise_recipe_is_a_different_signal_from_clear_speech(self):
        self.assertNotEqual((ROOT / 'audio-noisy-threat-ko.wav').read_bytes(),
                            (ROOT / 'audio-threat-ko.wav').read_bytes())

    def aac(self, seconds):
        import av
        import numpy as np
        output = io.BytesIO()
        with av.open(output, 'w', format='mp4') as container:
            stream = container.add_stream('aac', rate=16000)
            stream.layout = 'mono'
            frame = av.AudioFrame.from_ndarray(np.zeros((1, int(seconds * 16000)), dtype=np.int16), format='s16', layout='mono')
            frame.sample_rate = 16000
            frame.pts = 0
            from fractions import Fraction
            frame.time_base = Fraction(1, 16000)
            for packet in stream.encode(frame):
                container.mux(packet)
            for packet in stream.encode(None):
                container.mux(packet)
        return {'bytes': base64.b64encode(output.getvalue()).decode('ascii'), 'mimeType': 'audio/mp4'}

    def test_fifteen_second_aac_padding_is_not_extra_speech(self):
        decoded = runtime.decoded_audio(self.aac(15))
        self.assertEqual(decoded['durationMs'], 15000)
        self.assertEqual(decoded['samples'], 240000)

    def test_actual_audio_over_fifteen_seconds_is_rejected(self):
        with self.assertRaises(ValueError):
            runtime.decoded_audio(self.aac(15.2))


if __name__ == '__main__':
    unittest.main()
