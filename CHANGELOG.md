# Änderungen – querencia-session

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionen
nach [SemVer](https://semver.org/lang/de/) mit Vorabkennung.

## [0.1.0~alpha1] – unveröffentlicht

Erster portabler Stand (QREL-01).

### Hinzugefügt
- `querencia-session --check` (Diagnose ohne Start) und `--version`.
- Optionale Einstellungen `~/.config/querencia/session.conf` und
  `/etc/querencia/session.conf` (`LABWC=`, `PANEL=`, `DESKTOP=`), wörtlich
  gelesen, nie als Shell ausgeführt.
- Tastatur und Sprache aus `/etc/default/keyboard` bzw.
  `/etc/default/locale`, wenn die Anmeldung sie nicht setzt.
- `x-querencia-mimeapps.list`: Querencia Files als Ordnerprogramm, nur in der
  Querencia-Sitzung.
- Testsuite `tests/run.sh` (läuft ohne Sitzung, startet nie labwc).
- Beispiele für greetd (tuigreet, ReGreet), nicht aktiviert.

### Geändert (gegenüber dem Entwicklungsstarter in `herkunft/`)
- labwc aus `PATH` (Mindestversion 0.9.4) statt fest `~/opt/labwc-0.9.8`.
- Programme aus `/usr/bin` statt aus Cargo-`target`-Verzeichnissen.
- Konfiguration aus `/etc/querencia/labwc` bzw. `~/.config/querencia/labwc`
  statt aus der Runtime-Kopie.
- `environment` setzt weder Sprache noch Tastaturbelegung.
- Druck-Taste startet `/usr/libexec/querencia/querencia-screenshot-start`.
