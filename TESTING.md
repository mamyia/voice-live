# Jak przetestować nową konfigurację TTS (Mac)

Stan na 2026-10-25. Wszystko poniżej jest do zrobienia na Twoim Macu,
w katalogu `speech-to-speech` (klon HF, nie to repo).

## 1. Walidacja pliku YAML (bez uruchamiania serwera)

```bash
cd speech-to-speech
source .venv/bin/activate
python - <<'EOF'
from speech_to_speech.config import load_config, validate_config, resolve_config, ConfigurationError
try:
    doc = load_config("mac.yaml")
    validate_config(doc)
    cfg = resolve_config(doc, names=["mac"])
    print("OK; pipelines:", len(cfg.pipelines))
except ConfigurationError as e:
    print("ConfigurationError:", e)
EOF
```

Najczęstsze przyczyny (sprawdzone przez testy walidatora):

- `{env: NAZWA}` bez ustawionej zmiennej → „Required environment reference is missing" (też przy braku CONDUIT_KEY przy ustawionym URL);
- backtyki ` ` ` ` lub `@` przed adresem/kluczem → „Invalid YAML" (cały plik);
- klucz zaczynający się od `*`, `!`, `>` albo z `: ` w środku → „Anchors / tags / Invalid YAML";
- tab zamiast spacji we wcięciu → „Invalid YAML";
- literówka w polu (np. `responses_api_key` zamiast `responses_api_api_key`) → „Unknown field";
- klucz z samych cyfr — OK bez cudzysłowu tylko w `{env: ...}`; wprost → cudzysłów.

## 2. Kolejność testów TTS

1. **OmniVoice (design)** — `cp config/mac.omnivoice.design.yaml mac.yaml`, wypełnij adres+klucz, uruchom:
   `speech-to-speech serve -f mac.yaml --name mac` → przetestuj z Conduit (Test connection, potem Local Live).
2. Jeśli OmniVoice z jakiegoś powodu nie ruszy na MPS — **Supertonic 3**:
   `cp config/mac.supertonic.yaml mac.yaml`, instalacja `uv pip install "speech-to-speech[supertonic]"`, restart.
3. Klonowanie głosu — dopiero, gdy OmniVoice działa w trybie design (zamień blok
   TTS na `config/mac.omnivoice.clone.yaml` + nagraj `ref/moj_glos.wav`).

## 3. Co obserwować w logu serwera

- „Loading OmniVoice … on mps" — czy naprawdę użył MPS;
- „ASSISTANT: …" + TTFA (time to first audio) — docelowo < 2 s dla zdania;
- jeśli słyszysz angielski akcent → `omnivoice_language: Polish` nie zadziałało, sprawdź pisownię;
- jeśli cisza po odpowiedzi → sprawdź, czy `stream_batch_sentences: 1` jest ustawione.

## 4. launchd (Mac mini / Studio)

1. Popraw ścieżki w `launchd/pl.domowik.speech-to-speech.plist` (ścieżka do venv, katalogu i logów).
2. `CONDUIT_URL` i `CONDUIT_KEY` w `EnvironmentVariables` — z Conduita (jak wyżej).
3. `cp ~/voice-live/launchd/pl.domowik.speech-to-speech.plist ~/Library/LaunchAgents/`
4. `launchctl load ~/Library/LaunchAgents/pl.domowik.speech-to-speech.plist`
5. Sprawdź: `launchctl list | grep speech-to-speech` (druga kolumna = PID; 0 = wystartował, `-` = nie).
6. Logi: `tail -f ~/Library/Logs/speech-to-speech.log`.

## 5. Wskazówki do numerów i dat

STT czyta poprawnie wszystko, ale TTS czyta cyfry dosłownie. W promptcie systemowym
Hermesa dodaj zasadę: „Liczby, kwoty, daty i numery zapisuj słownie po polsku".
Zanim to zrobisz, w `config/mac.supertonic.yaml` (Supertonic) liczby poprawi zwykły
normalizer; w OmniVoice — tylko gdy masz `omnivoice[tn]` (WeTextProcessing), na
macOS wymagane `conda install -c conda-forge pynini` (bez tego cyfry czyta
słowo-po-słowie po angielsku).

## PC: CachyOS + Radeon RX 9070 XT (ROCm)

```bash
bash pc/setup-cachyos.sh          # venv + PyTorch ROCm 7.1 + speech-to-speech + omnivoice
cp config/pc.supertonic.yaml ~/speech-to-speech/pc.yaml   # wpisz adres+klucz z Conduita
cd ~/speech-to-speech && source .venv/bin/activate
speech-to-speech serve -f pc.yaml --name pc
```

Usługa: `systemd/speech-to-speech.service` (instrukcja w nagłówku pliku).
Nieprzetestowane na sprzęcie (autor nie ma dostępu do GPU AMD) — skrypt kończy się
wypisaniem `torch.cuda.is_available()`; musi być `True`.
