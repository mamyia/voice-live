# voice-live

Demo: **push-to-talk → lokalny whisper.cpp → LLM przez Twój router (9router).**

Mikrofon i transkrypcja są 100% lokalne (na Twoim Macu, Metal). "Myślenie" (model)
idzie do zdalnego API — na tym samym protokole co OpenAI `/v1/chat/completions`.

## Co robi

1. Nagrywa 6 s z mikrofonu (push-to-talk).
2. `whisper-cli` transkrybuje po polsku — lokalnie.
3. Tekst idzie do modelu `daily` na `https://9router.kaizen.beer/v1`.
4. Odpowiedź wraca do terminala, historia konwersacji jest utrzymywana.

## Instalacja (macOS, M1/M2 — sprawdzone na 16 GB)

```bash
git clone https://github.com/mamyia/voice-live && cd voice-live

# whisper.cpp (daje binarkę whisper-cli)
brew install whisper-cpp

# model whisper small (wielojęzyczny, ~475 MB) -> models/ggml-small.bin
mkdir -p models
curl -L -o models/ggml-small.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin

# python (wszystko z katalogu głównego repo)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# token do routera (plik .env jest w .gitignore)
echo 'ROUTER_API_KEY=twoj-prawdziwy-token' > .env
```

## Uruchomienie

```bash
python czat.py        # pętla: nagrywa 6 s -> transkrybuje -> pyta model -> odpowiada
python czat.py 10     # dłuższe nagrania (10 s)
```

Każdy Enter = kolejna "tura" rozmowy. Ctrl+C kończy.

## Zmienne środowiskowe

| Zmienna | Domyślnie | Opis |
|---|---|---|
| `ROUTER_BASE` | `https://9router.kaizen.beer/v1` | bazowy URL API |
| `ROUTER_API_KEY` | — | **wymagany** |
| `ROUTER_MODEL` | `daily` | nazwa modelu u routera |
| `WHISPER_BIN` | `whisper-cli` | ścieżka do binarki |
| `WHISPER_MODEL` | `models/ggml-small.bin` | plik modelu whisper |
| `WHISPER_LANG` | `pl` | język transkrypcji |

## Rozszerzenia (pomysły)

- streaming odpowiedzi z routera (SSE)
- TTS odpowiedzi (Piper po polsku) — "prawdziwy" live
- wyciszenie ciszy (VAD) zamiast stałych 6 s

## Licencja

MIT
