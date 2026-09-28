import json
import sys
import wave
from pathlib import Path

import numpy as np
import piper
from piper import PiperVoice
from piper.config import SynthesisConfig

# Work around a bug in piper-tts 1.8.0's macOS espeak-ng binding: any path
# containing "/piper/" as a component gets mangled to a baked-in CI path.
# A short symlink whose name avoids that substring sidesteps it entirely.
def resolve_espeak_data_dir(real_data_dir: Path, link_dir: Path) -> str:
    real_data_dir = real_data_dir.resolve()
    link_dir.mkdir(parents=True, exist_ok=True)
    link_path = link_dir / "espk"
    if link_path.is_symlink() or link_path.exists():
        if link_path.resolve() != real_data_dir:
            link_path.unlink()
            link_path.symlink_to(real_data_dir)
    else:
        link_path.symlink_to(real_data_dir)
    return str(link_path)


def raise_pitch_at_question_end(
    audio: np.ndarray,
    sample_rate: int,
    tail_ms: float = 260,
    pitch_factor: float = 1.18,
    crossfade_ms: float = 15,
) -> np.ndarray:
    """
    Piper's acoustic model doesn't expose a pitch/intonation control, and its
    learned prosody for question marks isn't reliably a rise. This forces
    one: the final `tail_ms` of the clip is resampled to fewer samples
    (played back at the same rate, that raises pitch and slightly shortens
    the tail -- both consistent with a natural rising question lilt), then
    crossfaded back against the unshifted head to avoid a click at the seam.
    """
    audio = audio.astype(np.float64)
    total_samples = len(audio)
    tail_len = min(int(sample_rate * tail_ms / 1000), total_samples // 2)
    if tail_len < int(sample_rate * 0.05):
        return audio.astype(np.int16)

    head = audio[: total_samples - tail_len]
    tail = audio[total_samples - tail_len :]

    new_tail_len = max(1, int(len(tail) / pitch_factor))
    source_positions = np.linspace(0, len(tail) - 1, new_tail_len)
    shifted_tail = np.interp(source_positions, np.arange(len(tail)), tail)

    crossfade_len = min(int(sample_rate * crossfade_ms / 1000), len(head), len(shifted_tail))
    if crossfade_len > 0:
        fade_out = np.linspace(1, 0, crossfade_len)
        fade_in = np.linspace(0, 1, crossfade_len)
        head = head.copy()
        head[-crossfade_len:] = (
            head[-crossfade_len:] * fade_out + shifted_tail[:crossfade_len] * fade_in
        )
        shifted_tail = shifted_tail[crossfade_len:]

    result = np.concatenate([head, shifted_tail])
    return np.clip(result, -32768, 32767).astype(np.int16)


def main() -> None:
    model_path = Path(sys.argv[1])
    config_path = Path(sys.argv[2])
    output_wav_path = Path(sys.argv[3])
    cache_dir = Path(sys.argv[4])

    # stdin is a JSON payload describing one or more text segments to
    # synthesize back-to-back, each with its own delivery parameters, plus
    # a silence gap between them (used for comedic timing before a
    # punchline). Loading the model once and running multiple short
    # inferences is much cheaper than spawning this process per segment.
    payload = json.loads(sys.stdin.read())
    segments = payload["segments"]
    pause_ms = payload.get("pause_ms", 0)

    espeak_data_dir = Path(piper.__file__).parent / "espeak-ng-data"
    espeak_data_dir_arg = resolve_espeak_data_dir(espeak_data_dir, cache_dir)

    voice = PiperVoice.load(
        model_path,
        config_path=config_path,
        espeak_data_dir=espeak_data_dir_arg,
    )

    sample_rate = voice.config.sample_rate
    sample_width = 2
    sample_channels = 1
    silence_frame_count = int(sample_rate * pause_ms / 1000)
    silence_bytes = b"\x00" * (silence_frame_count * sample_width * sample_channels)

    all_audio = bytearray()
    for index, segment in enumerate(segments):
        syn_config = SynthesisConfig(
            length_scale=segment.get("length_scale"),
            noise_scale=segment.get("noise_scale"),
            noise_w_scale=segment.get("noise_w_scale"),
        )
        segment_audio = bytearray()
        for chunk in voice.synthesize(segment["text"], syn_config=syn_config):
            segment_audio.extend(chunk.audio_int16_bytes)

        if segment["text"].rstrip().endswith("?"):
            samples = np.frombuffer(bytes(segment_audio), dtype=np.int16)
            samples = raise_pitch_at_question_end(samples, sample_rate)
            segment_audio = bytearray(samples.tobytes())

        all_audio.extend(segment_audio)

        if index < len(segments) - 1:
            all_audio.extend(silence_bytes)

    with wave.open(str(output_wav_path), "wb") as wav_file:
        wav_file.setframerate(sample_rate)
        wav_file.setsampwidth(sample_width)
        wav_file.setnchannels(sample_channels)
        wav_file.writeframes(bytes(all_audio))


if __name__ == "__main__":
    main()
