# voice-live

Dwie rzeczy w jednym repo:

1. **`czat.py`** — demo push-to-talk: nagrywa 6 s z mikrofonu → lokalny `whisper.cpp` → LLM przez Twój router (9router) → odpowiedź czytana głosem (`edge-tts` Zosia, zapas `say`).
2. **Konfiguracja serwera mowy** [`speech-to-speech`](https://github.com/huggingface/speech-to-speech) (HF) na Macu — STT + TTS w jednym, dostępny z sieci przez WireGuard. To jest ta, którą używa Conduit jako „własny serwer głosowy".

## Szybki start — serwer mowy (speech-to-speech)

Dla Conduita (Hermes na iOS) serwer mowy musi być osiągalny z komputera, na którym
działa Hermes — u nas przez WireGuard (`10.250.0.3`), nie z LAN-u.

### 1. Instalacja

```bash
git clone https://github.com/huggingface/speech-to-speech
cd speech-to-speech
uv venv --python 3.12
uv pip install -e .            # + opcjonalnie: "speech-to-speech[omnivoice]" albo "[supertonic]"
```

Pierwsze uruchomienie pobiera kilka GB modeli (kilka minut); kolejne starty ~40 s.

### 2. Konfiguracja

Skopiuj szablon z tego repo do `speech-to-speech/mac.yaml` i wypełnij 2 miejsca
(„ADRES_Z_CONDUITA" / „KLUCZ_Z_CONDUITA") — bierzesz je z Conduita:
**Settings → Voice → Private voice → Your speech server speaks too** (włącz to,
pojawią się „Model address" i „Key"). Tych dwóch wartości nie wysyłaj do nikogo.

Szablony w `config/`:

| Plik | Co ustawia | Kiedy |
|---|---|---|
| `config/mac.supertonic.yaml` | TTS = Supertonic 3, głos `F1`/`M1`, język `pl` | najstabilniejszy i najlżejszy, ale neutralny brzmienie |
| `config/mac.omnivoice.design.yaml` | TTS = OmniVoice, głos projektowany (`female, young adult`), `mps` | **najładniejszy polski głos**, zalecany start |
| `config/mac.omnivoice.clone.yaml` | TTS = OmniVoice, klonowanie z `ref/pl_kobieta.wav` + `ref/pl_kobieta.txt` | Twój własny głos / głosem kogoś (za zgodą) |

### 3. Uruchomienie

```bash
cd speech-to-speech
source .venv/bin/activate
speech-to-speech serve -f mac.yaml --name mac
# w mac.yaml: runtime.server.host: 0.0.0.0, port: 8765
```

Serwer wystawia `ws://<IP-Maca>:8765/v1/realtime` (OpenAI Realtime protocol).
W Conduicie ustaw **Your speech server** na `ws://10.250.0.3:8765/v1/realtime`.
Test z kontenera Hermesa:

```bash
curl -s -i -N \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  --max-time 5 http://10.250.0.3:8765/v1/realtime | head -1
# powinno być: HTTP/1.1 101 Switching Protocols
```

### 4. Zanim wystawisz poza localhost

- serwer nie ma autoryzacji → zostaw go w LAN albo w WireGuard; na MacBooku testuj
  ręcznie i po teście wyłącz przez Ctrl+C;
- docelowo na **Mac mini / Mac Studio** jako usługę `launchd` — gotowy plik:
  [`launchd/pl.domowik.speech-to-speech.plist`](launchd/pl.domowik.speech-to-speech.plist)
  (KeepAlive, uruchamia po starcie systemu, logi w `~/Library/Logs/speech-to-speech.log`).
  Adres i klucz bierze z `EnvironmentVariables` (`CONDUIT_URL`, `CONDUIT_KEY`),
  więc nic nie musisz trzymać w pliku YAML.

```bash
mkdir -p ~/Library/LaunchAgents
cp launchd/pl.domowik.speech-to-speech.plist ~/Library/LaunchAgents/
# w pliku zamień /Users/mamiya/speech-to-speech na swoją ścieżkę
launchctl load ~/Library/LaunchAgents/pl.domowik.speech-to-speech.plist
launchctl list | grep speech-to-speech   # status PID
```

### 5. Numery słownie

STT i TTS dają najczystszy polski, gdy model nie czyta cyfr dosłownie.
Dodaj do promptu systemowego Hermesa zasadę:

> „Liczby, kwoty, daty i numery telefonów zapisuj słownie po polsku, np.
> `1249,99 zł` jako `tysiąc dwieście czterdzieści dziewięć złotych
> dziewięćdziesiąt dziewięć groszy`, `9:45` jako `dziewiąta czterdzieści pięć`."

## Demo terminalowe (`czat.py`)

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

python czat.py        # pętla: nagrywa 6 s -> transkrybuje -> pyta model -> odpowiada
python czat.py 10     # dłuższe nagrania (10 s)
```

Każdy Enter = kolejna „tura" rozmowy. Ctrl+C kończy.

### Głos odpowiedzi

Odpowiedzi czyta neuronowy głos Microsoftu przez `edge-tts` (**pl-PL-ZofiaNeural**, bez klucza,
wymaga internetu). Odtwarza `afplay` (macOS). Gdy edge-tts zawiedzie, skrypt spada na
wbudowane `say`. Męski głos: `TTS_VOICE=pl-PL-MarekNeural`. Wyłączenie: `TTS=0 python czat.py`.

### Zmienne środowiskowe

| Zmienna | Domyślnie | Opis |
|---|---|---|
| `ROUTER_BASE` | `https://9router.kaizen.beer/v1` | bazowy URL API |
| `ROUTER_API_KEY` | — | **wymagany** |
| `ROUTER_MODEL` | `daily` | nazwa modelu u routera |
| `WHISPER_BIN` | `whisper-cli` | ścieżka do binarki |
| `WHISPER_MODEL` | `models/ggml-small.bin` | plik modelu whisper |
| `WHISPER_LANG` | `pl` | język transkrypcji |
| `TTS` | `1` | `0` wyłącza czytanie odpowiedzi |
| `TTS_VOICE` | `pl-PL-ZofiaNeural` | głos edge-tts (`edge-tts --list-voices`) |
| `TTS_RATE_PCT` | `+0%` | tempo edge-tts, np. `+10%` |
| `TTS_RATE` | `190` | tempo zapasowego `say` |

## Jak wybraliśmy TTS (wyniki)

Test 6 polskich lektorów (2 × Supertonic 3, 2 × OmniVoice, 2 × edge-tts) na tym samym
zdaniu — próbki w [`samples/`](samples/), tekst w [`samples/tekst.txt`](samples/tekst.txt).
Automatyczna ocena (Whisper large-v3-turbo → WER) i odsłuch:

| Próbka | Model | WER (proza) | Uwagi |
|---|---|---|---|
| `A` | Supertonic 3, F1 (lokalnie, ONNX) | 0% | stabilny, RTF ~0,8 na 3-rdzeniowym CPU, mały wachlarz intonacji |
| `B` | Supertonic 3, M1 (lokalnie, ONNX) | 0% | j.w. |
| `C` | OmniVoice, F (lokalnie, voice design) | 0% | najprzyjemniejsza intonacja, ma wbudowany śmiech/oddech |
| `D` | OmniVoice, M (lokalnie, voice design) | 0% | j.w. |
| `E` | edge-tts, Zofia (chmura MS) | 0% | dobry punkt odniesienia |
| `F` | edge-tts, Marek (chmura MS) | 0% | j.w. |

**Werdykt: OmniVoice** (najładniejszy polski głos, `speech-to-speech[omnivoice]`),
**Supertonic 3 jako zapas** (`speech-to-speech[supertonic]`). edge-tts pozostał jako
kontrola i głos demo terminalowego. Słabsi w polskich testach: XTTS v2 (akcent,
licencja niekomercyjna), Piper (brzmi jak nawigacja), Chatterbox (bełkot na cyfrach,
słaba polska wymowa w 23 językach), Fish S2 Pro (miesza angielski z polskim),
MMS TTS (robotyczny).

## Licencja

MIT
