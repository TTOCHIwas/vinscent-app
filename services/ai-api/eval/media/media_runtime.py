"""Offline codecs, Silero VAD and Vosk recognition for synthetic evaluation."""

import base64
import hashlib
import io
import json
from pathlib import Path
import sys
import wave

MAX_BYTES = 20 * 1024 * 1024
MAX_SAMPLES = 16_000 * 15
VAD_SHA256 = "1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3"


def binary(value):
    if not isinstance(value, str) or len(value) > MAX_BYTES * 4 // 3 + 8:
        raise ValueError()
    data = base64.b64decode(value, validate=True)
    if not 0 < len(data) <= MAX_BYTES:
        raise ValueError()
    return data


def decoded_image(data):
    from PIL import Image

    raw = binary(data["bytes"])
    expected = {"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}[data["mimeType"]]
    with Image.open(io.BytesIO(raw)) as image:
        if image.format != expected or getattr(image, "n_frames", 1) != 1:
            raise ValueError()
        if min(image.size) < 1 or max(image.size) > 4096 or image.width * image.height > 16_000_000:
            raise ValueError()
        image.verify()
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        output = io.BytesIO()
        image.convert("RGB").save(output, format="PNG")
        ocr = image.convert("L")
        ocr = ocr.point(lambda value: 0 if value < 245 else 255)
        if max(ocr.size) <= 2048:
            ocr = ocr.resize((ocr.width * 2, ocr.height * 2))
        enhanced = io.BytesIO()
        ocr.save(enhanced, format="PNG")
        return {"pngBase64": base64.b64encode(output.getvalue()).decode("ascii"),
                "ocrPngBase64": base64.b64encode(enhanced.getvalue()).decode("ascii"),
                "width": image.width, "height": image.height}


def decoded_audio(data):
    import av
    import numpy as np

    raw = binary(data["bytes"])
    format_name = {"audio/wav": "wav", "audio/mp4": "mov", "audio/mpeg": "mp3"}[data["mimeType"]]
    chunks = []
    count = 0
    with av.open(io.BytesIO(raw), format=format_name, options={"err_detect": "explode", "protocol_whitelist": "pipe"}) as container:
        if len(container.streams.audio) != 1 or len(container.streams.video) != 0:
            raise ValueError()
        stream = container.streams.audio[0]
        if not 8000 <= stream.codec_context.sample_rate <= 96000 or len(stream.codec_context.layout.channels) > 2:
            raise ValueError()
        declared = float(stream.duration * stream.time_base) if stream.duration else None
        if declared is not None and declared > 15.1:
            raise ValueError()
        resampler = av.AudioResampler(format="s16", layout="mono", rate=16000)
        for frame in container.decode(stream):
            for converted in resampler.resample(frame):
                pcm = converted.to_ndarray().flatten()
                count += len(pcm)
                if count > MAX_SAMPLES + 1024:
                    raise ValueError()
                chunks.append(pcm)
        for converted in resampler.resample(None):
            pcm = converted.to_ndarray().flatten()
            count += len(pcm)
            if count > MAX_SAMPLES + 1024:
                raise ValueError()
            chunks.append(pcm)
    if not chunks or count < 160 or (declared is not None and count / 16000 < declared - 0.15):
        raise ValueError()
    samples = np.concatenate(chunks).astype("<i2")
    if format_name == "mov" and declared is not None and 0 < declared <= 15:
        target = round(declared * 16000)
        if 0 <= count - target <= 1024:
            samples = samples[:target]
            count = len(samples)
    if count > MAX_SAMPLES:
        raise ValueError()
    pcm = samples.tobytes()
    output = io.BytesIO()
    with wave.open(output, "wb") as writer:
        writer.setparams((1, 2, 16000, count, "NONE", "not compressed"))
        writer.writeframes(pcm)
    return {"wavBase64": base64.b64encode(output.getvalue()).decode("ascii"),
            "sampleRate": 16000, "samples": count, "durationMs": round(count / 16)}


def read_pcm(data):
    with wave.open(io.BytesIO(binary(data["wavBase64"])), "rb") as reader:
        if (reader.getnchannels(), reader.getsampwidth(), reader.getframerate()) != (1, 2, 16000):
            raise ValueError()
        count = reader.getnframes()
        if not 0 < count <= MAX_SAMPLES:
            raise ValueError()
        pcm = reader.readframes(count)
        if len(pcm) != count * 2:
            raise ValueError()
        return pcm


def detect_speech(data, model_path):
    import numpy as np
    import onnxruntime as ort

    if hashlib.sha256(Path(model_path).read_bytes()).hexdigest() != VAD_SHA256:
        raise ValueError()
    audio = np.frombuffer(read_pcm(data), dtype="<i2").astype(np.float32) / 32768
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(model_path, sess_options=options, providers=["CPUExecutionProvider"])
    state = np.zeros((2, 1, 128), dtype=np.float32)
    context = np.zeros((1, 64), dtype=np.float32)
    probabilities = []
    longest = 0
    run = 0
    for offset in range(0, len(audio), 512):
        chunk = audio[offset:offset + 512]
        chunk = np.pad(chunk, (0, 512 - len(chunk))).reshape(1, -1)
        window = np.concatenate((context, chunk), axis=1)
        probability, state = session.run(None, {"input": window, "state": state, "sr": np.array(16000, dtype=np.int64)})
        p = float(probability.item())
        if not np.isfinite(p) or not 0 <= p <= 1:
            raise ValueError()
        probabilities.append(p)
        run = run + 1 if p >= 0.5 else 0
        longest = max(longest, run)
        context = window[:, -64:]
    speech_ms = min(len(audio) / 16, sum(p >= 0.5 for p in probabilities) * 32)
    return {"speechDetected": longest * 32 >= 250, "speechMs": round(speech_ms),
            "maximumProbability": max(probabilities), "model": "silero-vad-v6.2"}


def transcribe(data, model_path):
    from vosk import KaldiRecognizer, Model, SetLogLevel

    SetLogLevel(-1)
    recognizer = KaldiRecognizer(Model(model_path), 16000)
    recognizer.SetWords(True)
    pcm = read_pcm(data)
    outputs = []
    for offset in range(0, len(pcm), 8000):
        if recognizer.AcceptWaveform(pcm[offset:offset + 8000]):
            outputs.append(json.loads(recognizer.Result()))
    outputs.append(json.loads(recognizer.FinalResult()))
    words = [word for item in outputs for word in item.get("result", [])]
    confidence = min((word["conf"] for word in words), default=0)
    return {"text": " ".join(item.get("text", "") for item in outputs).strip(),
            "language": "ko", "languageEvidence": "monolingual_model_not_detection",
            "confidence": confidence, "model": "vosk-model-small-ko-0.22"}


def encode_fixture(data):
    if data["kind"] == "image":
        from PIL import Image
        image = Image.open(io.BytesIO(binary(data["bytes"]))).convert("RGB")
        output = io.BytesIO()
        image.save(output, format=data["format"], quality=90)
    elif data.get("format") == "WAV":
        import numpy as np
        pcm = np.frombuffer(read_pcm({"wavBase64": data["bytes"]}), dtype="<i2").astype(np.float32)
        positions = np.arange(0, len(pcm), 1.25)
        pcm = np.interp(positions, np.arange(len(pcm)), pcm)
        rms = float(np.sqrt(np.mean(pcm * pcm)))
        pcm += np.random.default_rng(20261027).normal(0, rms / (10 ** (15 / 20)), len(pcm))
        pcm = np.clip(pcm, -32768, 32767).astype("<i2")
        output = io.BytesIO()
        with wave.open(output, "wb") as writer:
            writer.setparams((1, 2, 16000, len(pcm), "NONE", "not compressed"))
            writer.writeframes(pcm.tobytes())
    else:
        import av
        with wave.open(io.BytesIO(binary(data["bytes"])), "rb") as source:
            import numpy as np
            pcm = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2")
            output = io.BytesIO()
            with av.open(output, "w", format="mp4") as container:
                stream = container.add_stream("aac", rate=source.getframerate())
                stream.layout = "mono"
                frame = av.AudioFrame.from_ndarray(pcm.reshape(1, -1), format="s16", layout="mono")
                frame.sample_rate = source.getframerate()
                for packet in stream.encode(frame):
                    container.mux(packet)
                for packet in stream.encode(None):
                    container.mux(packet)
    return {"bytes": base64.b64encode(output.getvalue()).decode("ascii")}


def main():
    request = json.loads(sys.stdin.buffer.read(30 * 1024 * 1024))
    operation, data = request["operation"], request["data"]
    if operation == "decode_image":
        result = decoded_image(data)
    elif operation == "decode_audio":
        result = decoded_audio(data)
    elif operation == "vad":
        result = detect_speech(data, request["vadModel"])
    elif operation == "asr":
        result = transcribe(data, request["asrModel"])
    elif operation == "encode_fixture":
        result = encode_fixture(data)
    else:
        raise ValueError()
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print('{"error":"media_decode_or_recognition_failed"}')
        sys.exit(1)
