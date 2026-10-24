# Änderungen – querencia-session

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionen
nach [SemVer](https://semver.org/lang/de/) mit Vorabkennung.

## [0.1.0~alpha10] – unveröffentlicht

### Hinzugefügt
- Software-OpenGL bei zink auf NVK (QD-169), übernommen aus dem
  Entwicklungsstarter (querencia-runtime `session/grafik-1`): Hat ein
  Render-Knoten den Kerneltreiber `nouveau`, fragt `querencia-session` vor
  labwc im Hintergrund den OpenGL-Renderer ab (`querencia-sitzung
  --grafik-pruefen`, sonst `eglinfo -B -p surfaceless -a gles`) und wartet
  höchstens 2 s darauf, nie auf den Prozess selbst. Meldet er zink auf NVK
  oder nouveau, bekommen die Programme der Sitzung
  `LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
  GALLIUM_DRIVER=llvmpipe`: über `autostart` (`QUERENCIA_GRAFIK_UMGEBUNG`)
  und in der Aktivierungsumgebung von systemd und D-Bus, mit Rücknahme am
  Ende. labwc selbst bekommt sie nicht; Vulkan bleibt unberührt. Andere
  Treiber: keine Prüfung, nichts gesetzt.
- `~/.config/querencia/grafik.ini`, `[Grafik] Software-OpenGL =
  automatisch|an|aus`, übersteuert die Prüfung.
- `querencia-session --grafik-pruefen`: zeigt die Entscheidung, ohne etwas
  zu starten oder zu ändern. Eine Zeile „Grafik: …“ in `sitzung-start.log`.
- `docs/sitzung-grafik.md`.
- Tests mit Attrappen für Render-Knoten, `eglinfo` und `querencia-sitzung`:
  zink/NVK, andere Treiber, zwei Karten, Hänger über die Zeitgrenze,
  `grafik.ini`, Autostart, ganze Starts (labwc ohne, Panel mit den
  Variablen).

### Geändert
- `autostart` (Conffile): exportiert genau die drei Namen aus
  `QUERENCIA_GRAFIK_UMGEBUNG`.
- `x-querencia-mimeapps.list`, CHANGELOG 0.1.0~alpha9: Der Kommentar zu den
  Files-Startern nennt keine Frist mehr.

## [0.1.0~alpha9] – unveröffentlicht

### Geändert
- `x-querencia-mimeapps.list`: Ordner öffnen mit `org.querencia.Dateien.desktop`
  (Querencia Dateien löst Querencia Files als Ordnerprogramm ab, Migration M2,
  Welle C). Den Übergang der Starter von Files regelt das Paket
  querencia-files bzw. querencia-dateien; die Benutzer-`mimeapps.list`
  gewinnt weiterhin. Übernommen aus dem Packaging-Patch 0002
  (querencia-session 0.1.0~alpha8-2).
- `rc.xml`: Der Kommentar zu Super+F/Alt+F11 nennt kein bestimmtes
  Dateiprogramm mehr; die Tastenbelegung ist unverändert.
- Tests prüfen die Ordnerzuordnung auf `org.querencia.Dateien.desktop`.

## [0.1.0~alpha8] – unveröffentlicht

### Geändert
- `rc.xml`: Super+D ruft das Panel unter seinem neuen Namen
  `org.querencia.Panel` (Pfad `/org/querencia/Panel`, ab Panel 0.2.4) auf.
  Neuere Panels antworten auch noch unter dem alten Namen.
- `x-querencia-mimeapps.list`: Ordner öffnen mit `org.querencia.Files.desktop`
  (neue Kennung von Querencia Files); der alte Starter
  `io.github.lgse.Strata.desktop` bleibt nur als unsichtbare Brücke und nennt
  keine MIME-Typen mehr.
- Tests prüfen Busname und Pfad von Super+D und die Ordnerzuordnung.

## [0.1.0~alpha7] – unveröffentlicht

### Hinzugefügt
- `autostart`: Das Panel startet unter seiner Überwachung
  (`querencia-panel --ueberwacht`), wenn es das kann (`--faehigkeiten` nennt
  „ueberwacht“, ab Panel 0.2.3). Stürzt das Panel ab, startet die Überwachung
  es neu, höchstens dreimal in zehn Minuten. Ein älteres Panel startet wie
  bisher. Der Block ist gleich der labwc-Vorgabe von querencia-runtime.
- Tests: Das Fake-Panel beantwortet `--faehigkeiten`; geprüft werden der Start
  unter Überwachung und der Start eines älteren Panels ohne sie.
- `rc.xml`: Super+D „Arbeitsfläche anzeigen“ über das Panel (D-Bus
  `org.querencia.Panel.ArbeitsflaecheUmschalten`, QD-078, Runtime main
  dce66e3, G2-AL); braucht `gdbus` (libglib2.0-bin).

## [0.1.0~alpha6] – unveröffentlicht

### Hinzugefügt
- `rc.xml`: Super+F und Alt+F11 schalten Vollbild für das aktive Fenster um
  (QD-065, Runtime main 548483c, G2-AK).

## [0.1.0~alpha5] – unveröffentlicht

### Geändert
- `x-querencia-portals.conf`: `default=gtk` und
  `org.freedesktop.impl.portal.Secret=gnome-keyring` statt `default=gtk;*`
  (QD-077): mit `*` zog xdg-desktop-portal auf Ubuntu Desktop auch
  xdg-desktop-portal-gnome heran, das außerhalb von GNOME rund zwei Minuten
  hängt.

## [0.1.0~alpha4] – unveröffentlicht

Sauberer Sitzungsstart und Benutzerkopie wie auf der Entwicklungs-VM (Runtime
g2ai b10aedb = Starter 2.1, live seit 20.10.2026 14:25; Benutzerkopie G2-AG;
labwc-Vorgabe main 1068113; G2-F3).

### Hinzugefügt
- Benutzerkopie `~/.config/querencia/labwc` mit Abgleich gegen
  `/etc/querencia/labwc` (`.vorgabe/`, `--labwc-konfig-abgleichen`, alter Weg
  über `~/.config/querencia/labwc-alter-weg`); `QE_LABWC_VORGABE` für
  Querencia Einstellungen (QD-063).
- Vor dem Start und nach dem Ende: Reste einer früheren Sitzung beenden,
  `xdg-desktop-portal(-gtk)` stoppen (`reset-failed` davor und danach),
  Sprache und Desktop für systemd und D-Bus setzen und wieder zurücknehmen
  (QD-062, QD-064).
- `autostart`: wartet höchstens 1,5 s auf das Settings-Portal, sonst starten
  die GTK-Programme mit `GDK_DEBUG=no-portals`.
- `/usr/share/xdg-desktop-portal/x-querencia-portals.conf` (`default=gtk;*`).
- Logs mit fünf Generationen, eigene Zeilen mit Uhrzeit in
  `sitzung-start.log`.

### Geändert
- `environment`: `GSK_DEBUG=full-redraw` gegen Zeichenreste von GTK 4.22
  (QD-070).
- Eine vollständige Benutzerkonfiguration ersetzt die Vorgabe nicht mehr
  als Ganzes; vorhandene Dateien bleiben beim ersten Abgleich erhalten.

## [0.1.0~alpha3] – unveröffentlicht

labwc-Vorgabe wie auf der Entwicklungs-VM (Runtime main 4557927, live seit
20.10.2026 11:28; G2-F2).

### Geändert
- `rc.xml`: Symbolthema Querencia statt gnome-human (ohne Rückfall, wenn
  das Thema fehlt: das Paket hängt deshalb von querencia-symbole ab);
  Schriften DejaVu Sans 10, Fenstertitel und Menüüberschrift fett;
  `iconPriority="client"` für Einstellungen, Editor und Systemmonitor.
- `environment`: Zeiger DMZ-White 24 (`XCURSOR_THEME`, `XCURSOR_SIZE`).
- `x-querencia-mimeapps.list`: PDF mit Querencia Dokumente
  (`application/pdf`).

## [0.1.0~alpha2] – unveröffentlicht

Live-Stand der Entwicklungs-VM vom 20.10.2026, portabel (G2-F).

### Hinzugefügt
- autostart startet, wenn installiert: polkit-Agent und Leerlaufsperre
  (`querencia-sitzung`), Benachrichtigungsdienst
  (`querencia-benachrichtigungen`), gespeicherte Bildschirmanordnung
  (`querencia-einstellungen --bildschirm-anwenden`); `--check` zeigt sie an.
- rc.xml: Alt+Druck (Fensteraufnahme), Strg+Alt+L (sperren),
  Strg+Alt+Entf (Sitzungsdialog), Super+? (Tastenkürzel), Fensterregeln für
  Sitzungs- und polkit-Dialog, Alt+Tab-Liste, Theme Querencia-Klassisch mit
  Symbolthema gnome-human.
- `querencia-screenshot-start` reicht `--screen`, `--window`, `--area`
  weiter, andere Optionen lehnt es ab.
- `x-querencia-mimeapps.list`: Texte → Querencia Editor, Bilder →
  Querencia Bilder (nur in der Querencia-Sitzung).

### Nicht übernommen
- Benutzerkopie der labwc-Konfiguration mit Abgleich
  (`session/labwc-benutzer-0.1` der Runtime): folgt als eigener Schritt.

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
