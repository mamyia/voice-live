#!/usr/bin/env python3
"""push-to-talk demo: nagrywa z mikrofonu, transkrybuję whisper-cli, pyta model przez 9router."""
import os
import subprocess
import sys
import time
import wave

import requests

# --- konfiguracja (środowisko nadpisuje) ---
ROUTER_BASE = os.environ.get("ROUTER_BASE", "https://9router.kaizen.beer/v1")
ROUTER_API_KEY = os.environ.get("ROUTER_API_KEY", "").strip()
if not ROUTER_API_KEY or ROUTER_API_KEY.startswith("sk-..."):
    sys.exit("Ustaw prawdziwy token: export ROUTER_API_KEY=\"...\"")
MODEL = os.environ.get("ROUTER_MODEL", "daily")
WHISPER_BIN = os.environ.get("WHISPER_BIN", "whisper-cli")
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "models/ggml-small.bin")
WHISPER_LANG = os.environ.get("WHISPER_LANG", "pl")

SYSTEM_PROMPT = "Jesteś pomocnym asystentem. Odpowiadaj zwięźle po polsku."

HISTORY = [{"role": "system", "content": SYSTEM_PROMPT}]


def nagrywaj(secs=6.0, rate=16000):
    """Nagrywaj secs sekund z domyślnego mikrofonu do pliku tmp.wav (16-bit mono)."""
    import sounddevice as sd  # lokalny import: tylko na maszynie z mikrofonem
    print(f"🎙️  Nagrywam {secs:.0f}s... mów teraz.")
    audio = sd.rec(int(secs * rate), samplerate=rate, channels=1, dtype="int16")
    sd.wait()
    with wave.open("tmp.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(audio.tobytes())


def transkrybuj(path="tmp.wav"):
    """whisper-cli -> czysty tekst."""
    out = subprocess.run(
        [WHISPER_BIN, "-m", WHISPER_MODEL, "-l", WHISPER_LANG, "-nt", "-f", path],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        sys.exit(f"whisper-cli failed: {out.stderr}")
    text = out.stdout.strip()
    # whisper zwraca znaczniki typu [MUZYKA], (cisza) dla braku mowy
    if text.startswith(("[", "(")) and text.endswith(("]", ")")):
        return ""
    return text


def zapytaj(text):
    r = requests.post(
        f"{ROUTER_BASE}/chat/completions",
        headers={"Authorization": f"Bearer {ROUTER_API_KEY}"},
        json={"model": MODEL, "messages": HISTORY + [{"role": "user", "content": text}]},
        timeout=120,
    )
    if not r.ok:
        raise requests.HTTPError(f"{r.status_code}: {r.text[:300]}")
    odp = r.json()["choices"][0]["message"]["content"].strip()
    HISTORY.append({"role": "user", "content": text})
    HISTORY.append({"role": "assistant", "content": odp})
    return odp


def main():
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
    while True:
        try:
            nagrywaj(secs)
        except KeyboardInterrupt:
            break
        try:
            text = transkrybuj()
        except KeyboardInterrupt:
            break
        if not text:
            print("(cisza — nic nie usłyszałem)")
            continue
        print(f"Ty: {text}")
        try:
            print(f"AI: {zapytaj(text)}\n")
        except requests.RequestException as e:
            print(f"❌ 9router: {e}\n")


if __name__ == "__main__":
    main()
