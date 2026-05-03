# Unraid Setup

## Zweck

Diese Anleitung beschreibt, wie du das Image auf Unraid ohne Compose in wenigen, nachvollziehbaren Schritten einrichtest.

## Variante A: Lokales Image im Unraid-Terminal bauen

```bash
cd /path/to/FoundryVTT
docker build -t feberdin/foundryvtt-unraid:local .
```

Das Repo muss dafuer auf dem Unraid-Host oder in einem erreichbaren Build-Kontext liegen.

## Variante B: Image erst extern bauen und dann in Unraid nutzen

Falls du das Image spaeter in eine Registry pushen willst, kannst du in Unraid einfach das fertige Image referenzieren. Fuer den ersten Test reicht aber Variante A.

## Container in Unraid anlegen

1. `Docker` oeffnen.
2. `Add Container` waehlen.
3. Namen z. B. `foundryvtt` setzen.
4. Repository auf `feberdin/foundryvtt-unraid:local` setzen.
5. Netzwerktyp zunaechst auf `bridge` lassen.
6. Port-Mapping `30000` Host -> `30000` Container anlegen.
7. Path `/mnt/user/appdata/foundryvtt` -> `/data/foundryvtt` anlegen.
8. Diese Variablen anlegen:

| Name | Wert |
| --- | --- |
| `FOUNDRY_RELEASE_URL` | frische Timed URL aus dem Foundry-Portal |
| `FOUNDRY_ADMIN_KEY` | eigener starker Setup-Key |
| `FOUNDRY_COMPATIBILITY_MODE` | `auto` oder bewusst `v13` fuer Foundry 13.351 |
| `PUID` | `99` |
| `PGID` | `100` |
| `LOG_LEVEL` | `info` |

## Reverse Proxy optional

Wenn du spaeter ueber Nginx Proxy Manager, Traefik oder einen anderen Reverse Proxy gehst, sind diese Werte oft sinnvoll:

| Name | Beispiel |
| --- | --- |
| `FOUNDRY_HOSTNAME` | `vtt.example.de` |
| `FOUNDRY_PROXY_SSL` | `true` |
| `FOUNDRY_PROXY_PORT` | `443` |
| `FOUNDRY_ROUTE_PREFIX` | `foundry` nur wenn du nicht auf Domain-Root hostest |

## Start und Erstkonfiguration

1. Container starten.
2. Logs pruefen, bis `Foundry` gestartet ist.
3. Im Browser `http://<unraid-ip>:30000` oeffnen.
4. Lizenzschluessel im Websetup eingeben.
5. EULA bestaetigen.
6. Administrator-Key pruefen.

Wichtig:

- Fuer dieses Setup bitte im Foundry-Portal die `Node.js`-Downloadvariante waehlen.
- Das aktuelle Repo unterstuetzt Foundry `13.x` ueber `FOUNDRY_COMPATIBILITY_MODE=v13` und Foundry `14+` ueber `auto` oder `v14`.

## Typische Unraid-Fallen

- Das Appdata-Volume fehlt: Dann wird Foundry bei jedem Neustart neu installiert.
- Die Timed URL ist alt: Dann scheitert der Download schon vor dem Start.
- Der Kompatibilitaetsmodus ist falsch: Dann startet Foundry mit der unpassenden Node-Version nicht.
- Falscher Proxy-Port oder fehlender Hostname: Dann erzeugt Foundry falsche Einladungslinks.
- Rechteproblem im Appdata-Ordner: Dann kann Foundry `Config`, `Data` oder `Logs` nicht schreiben.

## Gezielter Downgrade auf Foundry 13.351

1. Backup von `/mnt/user/appdata/foundryvtt/userdata` erstellen.
2. Neue `Node.js`-Timed-URL fuer `13.351` im Foundry-Portal erzeugen.
3. Im Unraid-Template setzen:
   - `Compatibility Mode` = `v13`
   - `Reinstall / Downgrade App Files` = `true`
   - `Foundry Timed URL` = deine frische `13.351` URL
4. Container starten.
5. Nach erfolgreichem Start `Reinstall / Downgrade App Files` wieder auf `false` setzen.
