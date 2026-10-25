# Próbka głosu do klonowania (OmniVoice)

Nagraj 5–15 s czystej mowy (jeden głos, bez muzyki w tle), zapisz tutaj jako
`moj_glos.wav` i wpisz jej **dokładny** transkrypt do `moj_glos.txt`.
Potem wpisz w `config/mac.omnivoice.clone.yaml`:

```yaml
      omnivoice_ref_audio: ref/moj_glos.wav
      omnivoice_ref_text: "…dokładnie to, co mówisz w próbce…"
```

Nagranie z mikrofonu (macOS, w terminalu):

```bash
sox -d -r 24000 -c 1 -b 16 ref/moj_glos.wav trim 0 10
```

albo QuickTime Player → Nowe nagranie audio → eksport jako WAV.

Ważne:
- transkrypt musi pasować do dźwięku po wycięciu ciszy — najlepiej krótkie
  zdanie wypowiedziane płynnie (np. „Cześć! To jest próbka głosu do klonowania."),
- pliki `.wav`/`.txt` w tym katalogu są w `.gitignore` — nigdy nie commituj
  nagrania swojego (ani czyjegoś) głosu do repo.
