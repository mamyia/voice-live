#!/usr/bin/env bash
# Serwer mowy (speech-to-speech) na CachyOS + Radeon RX 9070 XT (ROCm).
# Uruchom: bash pc/setup-cachyos.sh   (z katalogu voice-live, bez sudo)
set -euo pipefail

ROCM_INDEX="${ROCM_INDEX:-https://download.pytorch.org/whl/rocm7.1}"
DEST="${DEST:-$HOME/speech-to-speech}"
PY="${PY:-3.12}"

command -v uv >/dev/null || { echo "Brak uv: sudo pacman -S uv"; exit 1; }
id -nG | tr ' ' '\n' | grep -qx render || echo "UWAGA: dodaj się do grup: sudo usermod -aG render,video \$USER (i zaloguj ponownie)"

[ -d "$DEST/.git" ] || git clone --depth 1 https://github.com/huggingface/speech-to-speech "$DEST"
cd "$DEST"
uv venv --python "$PY" .venv
source .venv/bin/activate

# 1) PyTorch w wersji ROCm (to on daje GPU AMD; w PyTorch ROCm urządzenie nazywa się "cuda")
uv pip install --index-url "$ROCM_INDEX" torch torchaudio

# 2) zależności projektu BEZ torch i bez faster-qwen3-tts (wheel CUDA, niepotrzebny przy OmniVoice)
python - <<'PY' > /tmp/s2s-reqs.txt
import tomllib, re
d = tomllib.load(open("pyproject.toml", "rb"))["project"]["dependencies"]
skip = re.compile(r"^(torch|torchaudio|faster-qwen3-tts|mlx|miniaudio|sounddevice==)", re.I)
for r in d:
    if "Darwin'" in r and "!=" not in r:
        continue
    if skip.match(r):
        continue
    print(r.split(";")[0].strip())
PY
uv pip install -r /tmp/s2s-reqs.txt
uv pip install --no-deps -e .
uv pip install omnivoice

echo; python - <<'PY'
import torch
print("torch", torch.__version__, "| HIP", torch.version.hip, "| GPU dostępne:", torch.cuda.is_available())
if torch.cuda.is_available(): print("GPU:", torch.cuda.get_device_name(0))
PY
echo "Dalej: cp $(dirs -l 2>/dev/null | cut -d' ' -f1)/config/pc.omnivoice.yaml $DEST/pc.yaml, wpisz adres+klucz, a potem:"
echo "  cd $DEST && source .venv/bin/activate && speech-to-speech serve -f pc.yaml --name pc"
