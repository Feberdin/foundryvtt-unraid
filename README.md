# FoundryVTT Docker fuer Unraid

## Zweck

Dieses Repo baut ein kleines Docker-Image, das Foundry Virtual Tabletop auf Unraid sauber und nachvollziehbar startet, ohne proprietaere Foundry-Dateien ins Image einzubauen.

## Features

- Lizenzkonformes Image: Foundry wird erst beim ersten Start aus einer offiziellen Timed URL geladen.
- Sichere Defaults fuer Unraid: persistente Datenpfade, `UPnP` standardmaessig aus, klare Fehlermeldungen.
- Verstaendliche Betriebslogik: Startskript validiert Eingaben, schreibt nachvollziehbare Logs und startet Foundry als nicht-root Benutzer.
- Wartbare Konfiguration: Reverse Proxy, Hostname, Route Prefix und Port koennen per Umgebungsvariablen gesetzt werden.
- Lokale Tests: Die Kernlogik fuer `options.json` und den Bootstrap-Prozess ist mit Shell-Tests abgedeckt.
- Unraid-Template inklusive XML: Das Repo kann direkt als Vorlagen-Repository in Unraid eingebunden werden.
- GitHub Actions ready: Nach dem Push baut GitHub das Image automatisch und veroeffentlicht es nach GHCR.

## Annahmen

- Zielplattform ist Unraid mit Docker.
- Die Foundry-Daten sollen unter `/mnt/user/appdata/foundryvtt` liegen.
- Es wird die offizielle Foundry Node.js ZIP fuer Version 13 oder neuer verwendet.
- Die Lizenz bleibt bei dir. Der Schluessel wird nicht in dieses Repo geschrieben.
- Fuer den ersten Start braucht Foundry Internetzugriff, damit du die Lizenz im Browser aktivieren und die EULA bestaetigen kannst.

## Dateibaum

```text
.
├── CONTRIBUTING.md
├── Dockerfile
├── README.md
├── ca_profile.xml
├── docker
│   ├── entrypoint.sh
│   ├── healthcheck.sh
│   └── render-options.mjs
├── docs
│   └── unraid-setup.md
├── foundryvtt-unraid.xml
├── images
│   └── foundryvtt-unraid.svg
└── tests
    ├── entrypoint.test.sh
    ├── render-options.test.sh
    └── run-tests.sh
```

## Quickstart

### 1. Image lokal bauen

```bash
cd /path/to/FoundryVTT
docker build -t feberdin/foundryvtt-unraid:local .
./tests/run-tests.sh
```

### 2. Frische Foundry Timed URL erzeugen

1. Melde dich bei [foundryvtt.com](https://foundryvtt.com/article/installation/) mit deinem Lizenzkonto an.
2. Oeffne die Download-Seite deiner Lizenz.
3. Waehle `Version: Recommended` oder bewusst eine andere Version.
4. Waehle `Operating System: Node.js`.
5. Klicke auf `Timed URL`.

Wichtig: Die URL laeuft laut Foundry nach ungefaehr 5 Minuten ab. Generiere sie also erst direkt vor dem ersten Start oder einem Update.

### 3. Container manuell testen

```bash
docker run --rm \
  --name foundryvtt \
  -p 30000:30000 \
  -e FOUNDRY_RELEASE_URL="PASTE_FRESH_TIMED_URL_HERE" \
  -e FOUNDRY_ADMIN_KEY="CHANGE_ME_TO_A_STRONG_SETUP_PASSWORD" \
  -e PUID=99 \
  -e PGID=100 \
  -v /mnt/user/appdata/foundryvtt:/data/foundryvtt \
  feberdin/foundryvtt-unraid:local
```

Danach oeffnest du im Browser:

- lokal: `http://<unraid-ip>:30000`
- bei Reverse Proxy spaeter: deine externe URL

Beim ersten Aufruf gibst du deinen Foundry-Lizenzschluessel direkt im Foundry-Websetup ein. Er wird nicht ueber Docker gesetzt.

## Wichtige Umgebungsvariablen

| Variable | Standard | Zweck |
| --- | --- | --- |
| `FOUNDRY_RELEASE_URL` | leer | Pflicht beim ersten Start oder bei erzwungener Neuinstallation. Frische Timed URL zur Node.js ZIP. |
| `FOUNDRY_ADMIN_KEY` | leer | Optional. Setzt beim ersten Start den Zugriffsschluessel fuer das Setup-Menue. |
| `FOUNDRY_PORT` | `30000` | Interner Foundry-Port. |
| `FOUNDRY_HOSTNAME` | leer | Externer Hostname, der in Einladungslinks genutzt wird. |
| `FOUNDRY_ROUTE_PREFIX` | leer | Optionaler URL-Praefix wie `foundry`. |
| `FOUNDRY_PROXY_SSL` | `false` | Auf `true`, wenn ein Reverse Proxy extern HTTPS terminiert. |
| `FOUNDRY_PROXY_PORT` | leer | Externer Proxy-Port, z. B. `443`. |
| `FOUNDRY_UPNP` | `false` | Sichere Voreinstellung fuer Serverbetrieb auf Unraid. |
| `FOUNDRY_WORLD` | leer | Optional. Startet direkt eine bestimmte Welt. |
| `FOUNDRY_FORCE_REINSTALL` | `false` | Nur fuer Updates oder Reparaturen. Loescht den App-Ordner und entpackt Foundry neu. |
| `PUID` / `PGID` | `99` / `100` | Benutzer- und Gruppen-ID fuer Unraid-Appdata. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error`. Steuert die Logs des Startskripts. |

## Empfohlenes Unraid-Setup

Die kurze Variante findest du in [docs/unraid-setup.md](/Users/joachim.stiegler/FoundryVTT/docs/unraid-setup.md).

Kurzfassung:

1. Image bauen oder in deine Registry pushen.
2. In Unraid `Add Container` waehlen.
3. Port `30000` nach `30000/tcp` mappen.
4. Volume `/mnt/user/appdata/foundryvtt` nach `/data/foundryvtt` mappen.
5. Frische `FOUNDRY_RELEASE_URL` als Env setzen.
6. Optional `FOUNDRY_ADMIN_KEY`, `FOUNDRY_HOSTNAME`, `FOUNDRY_PROXY_SSL=true`, `FOUNDRY_PROXY_PORT=443` setzen.
7. Container starten und Websetup abschliessen.

## Unraid XML-Vorlage

Dieses Repo enthaelt eine direkte Unraid-Vorlage in [foundryvtt-unraid.xml](/Users/joachim.stiegler/FoundryVTT/foundryvtt-unraid.xml). Sobald das Repo auf GitHub liegt, kannst du es in Unraid als Template-Repository hinterlegen.

Beispiel fuer spaeter:

1. In Unraid `Docker` oeffnen.
2. `Docker Repositories` oeffnen.
3. Die GitHub-Repo-URL eintragen, z. B. `https://github.com/Feberdin/foundryvtt-unraid`.
4. Speichern.
5. Danach unter `Add Container` die Vorlage `Feberdin-FoundryVTT` auswaehlen.

## Updates

Vor jedem Foundry-Core-Update bitte zuerst ein Backup deines User-Data-Verzeichnisses erstellen:

```bash
rsync -a /mnt/user/appdata/foundryvtt/userdata/ /mnt/user/backups/foundryvtt-userdata/
```

Update-Ablauf:

1. Frische Timed URL fuer die gewuenschte Node.js-Version erzeugen.
2. `FOUNDRY_FORCE_REINSTALL=true` setzen.
3. `FOUNDRY_RELEASE_URL` auf die neue Timed URL setzen.
4. Container starten und die Logs beobachten.
5. Nach erfolgreichem Start `FOUNDRY_FORCE_REINSTALL` wieder auf `false` setzen.

Hinweis: Foundry migriert Weltdaten bei groesseren Versionsspruengen. Ein Rueckweg ist dann oft nur per Backup moeglich.

## Troubleshooting

### Fehler: Timed URL ist abgelaufen

Symptom:

- Im Log erscheint ein Download-Fehler direkt beim Start.

Fix:

1. Neue Timed URL in Foundry erzeugen.
2. Container mit der neuen URL erneut starten.

### Fehler: Browser erreicht `http://<unraid-ip>:30000` nicht

Pruefen:

1. Laeuft der Container?
2. Ist der Port `30000/tcp` in Unraid gemappt?
3. Nutzt du `bridge` oder `host` wie geplant?
4. Blockiert ein Router oder Reverse Proxy den Zugriff?

### Fehler: Schreibrechte auf `/data/foundryvtt`

Symptom:

- Im Log erscheinen Meldungen zu `permission denied`.

Fix:

1. Eigentumer des Appdata-Pfads auf deine Unraid-IDs pruefen.
2. `PUID` und `PGID` mit dem Zielpfad abgleichen.
3. Testweise leeres Verzeichnis verwenden, um Rechteprobleme sauber einzugrenzen.

## Logs und Debugging

- Normale Logs: `docker logs -f foundryvtt`
- Mehr Details: `LOG_LEVEL=debug`
- Healthcheck: prueft lokal `http://127.0.0.1:<port>/`
- Wichtige Konfigurationsdatei: `/mnt/user/appdata/foundryvtt/userdata/Config/options.json`

Typische Debug-Dateien in den persistenten Daten:

- `userdata/Config/options.json`
- `userdata/Logs/`
- `userdata/Data/worlds/`

## Security-Hinweise

- Hinterlege weder Lizenzschluessel noch Timed URL in Git.
- Ein eigener `FOUNDRY_ADMIN_KEY` ist dringend empfohlen.
- Fuer externen Zugriff ist ein Reverse Proxy oder sauber konfiguriertes Port Forwarding besser als wilde Freigaben.
- Laut Foundry-Lizenz darf pro Lizenz nur eine fuer andere Benutzer erreichbare Instanz gleichzeitig betrieben werden.

## Lizenz-Hinweis

Dieses Repo enthaelt nur eigenes Glue-Code-Material. Foundry Virtual Tabletop selbst bleibt proprietaere Software von Foundry Gaming, LLC und muss von dir mit eigener Lizenz bezogen werden.
