import sys
import wave
from pathlib import Path

import piper
from piper import PiperVoice

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


def main() -> None:
    model_path = Path(sys.argv[1])
    config_path = Path(sys.argv[2])
    output_wav_path = Path(sys.argv[3])
    cache_dir = Path(sys.argv[4])
    text = sys.stdin.read()

    espeak_data_dir = Path(piper.__file__).parent / "espeak-ng-data"
    espeak_data_dir_arg = resolve_espeak_data_dir(espeak_data_dir, cache_dir)

    voice = PiperVoice.load(
        model_path,
        config_path=config_path,
        espeak_data_dir=espeak_data_dir_arg,
    )

    with wave.open(str(output_wav_path), "wb") as wav_file:
        voice.synthesize_wav(text, wav_file)


if __name__ == "__main__":
    main()
