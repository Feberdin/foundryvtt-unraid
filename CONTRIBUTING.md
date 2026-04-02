# Contributing

## Zweck

Diese Datei erklaert, wie Aenderungen an diesem Repo sicher und nachvollziehbar gemacht werden.

## Grundregeln

- Keine proprietaeren Foundry-Dateien committen.
- Keine Timed URLs, Lizenzschluessel oder produktiven Admin-Schluessel committen.
- Kleine, pruefbare Aenderungen bevorzugen.
- Vor Aenderungen an Startlogik oder Konfiguration immer die Tests ausfuehren.

## Lokaler Ablauf

```bash
cd /path/to/FoundryVTT
./tests/run-tests.sh
docker build -t feberdin/foundryvtt-unraid:local .
```

## Stil

- Shell-Skripte bleiben POSIX-nah und erklaeren heikle Stellen mit kurzen Kommentaren.
- JSON wird mit zwei Leerzeichen formatiert.
- Fehlermeldungen muessen klar sagen: was kaputt ist, warum das passiert und wie man es pruefen kann.

## Review-Checkliste fuer Aenderungen

- Build bleibt lizenzkonform.
- Startskript verschluckt keine Fehler still.
- Doku fuer Unraid bleibt aktuell.
- Tests decken Happy Path und mindestens einen Fehlerfall ab.
