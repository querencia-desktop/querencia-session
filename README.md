# Querencia Session

Sitzungsstart von [Querencia Desktop](https://querencialinux.org)
– einer klassischen Desktopumgebung im GNOME-2-Stil für Wayland (labwc, Rust,
GTK 4): der Starter `querencia-session`, die labwc-Konfiguration der Sitzung und
die Wayland-Sitzungsdatei für Anmeldebildschirme.
Installiert wird es zusammen mit Querencia Desktop aus der APT-Quelle;
Anleitung auf <https://querencialinux.org>.

*English summary:* Session start of Querencia Desktop: the `querencia-session`
launcher, the labwc configuration of the session and the Wayland session file
for login screens. Alpha software; documentation is in German.

> **Alpha (0.1.0~alpha10, Tag `session/alpha10`; bei zink auf NVK
> Software-OpenGL für die Programme der Sitzung).** Geprüft mit `tests/run.sh`;
> als Debian-Paket `querencia-session` Teil von Alpha 1 bis Alpha 3. Keine
> Sicherheits- oder Datenverlustgarantie.

## Was installiert wird

| Datei | Zweck |
|---|---|
| `/usr/bin/querencia-session` | Starter: prüft die Umgebung, startet labwc `-C <Konfiguration>`, räumt nach dem Ende auf |
| `/etc/querencia/labwc/{rc.xml,environment,autostart}` | Sitzungskonfiguration (Conffiles) |
| `/usr/libexec/querencia/querencia-screenshot-start` | Start von Querencia Screenshot über die Druck-Taste |
| `/usr/share/wayland-sessions/querencia.desktop` | Eintrag „Querencia Desktop“ für Anmeldebildschirme |
| `/usr/share/applications/x-querencia-mimeapps.list` | Standardprogramme nur für die Querencia-Sitzung |
| `/usr/share/xdg-desktop-portal/x-querencia-portals.conf` | Portale der Sitzung über xdg-desktop-portal-gtk |

Nichts wird in Home-Verzeichnisse geschrieben, kein Anmeldebildschirm wird
aktiviert. Zur Laufzeit legt der Starter `~/.local/state/querencia/` an
(Logs mit fünf Generationen, `sitzung-start.log`, PID-Einträge) und hält die
Benutzerkopie `~/.config/querencia/labwc/` mit der Vorgabe aus
`/etc/querencia/labwc/` abgeglichen: fehlende Dateien kommen dazu,
unveränderte folgen der neuen Vorgabe, geänderte bleiben (die neue Vorgabe
liegt dann als `<datei>.vorgabe-neu` daneben). Mit der Datei
`~/.config/querencia/labwc-alter-weg` liest labwc die Vorgabe direkt.

## Ablauf

```
Anmeldebildschirm / Konsole
  └─ querencia-session            beendet Reste einer früheren Sitzung; prüft: keine andere
     │                            Sitzung, logind-Sitz, labwc ≥ 0.9.4, Vorgabe, querencia-panel;
     │                            prüft bei nouveau im Hintergrund den OpenGL-Renderer;
     │                            setzt Tastatur/Sprache, gleicht die Benutzerkopie ab, gibt
     │                            Sprache und Desktop (bei zink auf NVK Software-OpenGL) an
     │                            systemd/D-Bus, stoppt die Portale
     └─ labwc -C ~/.config/querencia/labwc   (alter Weg: /etc/querencia/labwc)
        └─ autostart  ─ wartet höchstens 1,5 s auf das Settings-Portal
                      ─ querencia-polkit-agent         Passwortdialog für polkit (optional)
                      ─ querencia-einstellungen        gespeicherte Bildschirmanordnung (optional)
                      ─ querencia-desktop              Hintergrund, Symbole (optional)
                      ─ querencia-panel                oberes und unteres Panel
                      ─ querencia-benachrichtigungen   Benachrichtigungen (optional)
                      ─ querencia-sitzung --leerlauf   Leerlaufsperre (optional)
```

Abmelden: Menü „System → Abmelden …“ (Panel, `labwc --exit`) oder
`querencia-session --exit` aus einer anderen Shell desselben Benutzers.
Nach dem Ende von labwc stoppt der Starter die Portale wieder und setzt die
Aktivierungsumgebung zurück, damit eine sofortige Neuanmeldung frische
Portale bekommt.

Mit dem freien NVIDIA-Treiber (nouveau, OpenGL als zink auf NVK) bekommen
die Programme der Sitzung Software-OpenGL (llvmpipe), labwc selbst nicht;
Einstellung `~/.config/querencia/grafik.ini`, Diagnose
`querencia-session --grafik-pruefen`. Siehe
[docs/sitzung-grafik.md](docs/sitzung-grafik.md).

## Abhängigkeiten

`labwc (>= 0.9.4)`, `querencia-shell`, `procps` (`pgrep`, `ps`),
`systemd` (`loginctl`), `dbus-user-session`; für die Renderer-Prüfung
`querencia-sitzung` ab 0.1.8 oder `mesa-utils` (`eglinfo`), sonst bleibt
OpenGL unverändert. Ubuntu 26.04 liefert labwc
0.9.3; die APT-Quelle von Querencia liefert labwc 0.9.8 mit (Paketierung in
`querencia-packaging`).

## Bauen, testen, installieren

Siehe [docs/building.md](docs/building.md) und [docs/testing.md](docs/testing.md).

## Lizenz

GPL-3.0-or-later (wie `querencia-shell`, aus dem die Sitzungsdateien
stammen), siehe [LICENSE](LICENSE).

## Fehler melden

Fehler, Wünsche und Fragen zu Querencia gehen an die gemeinsame Meldestelle:
<https://github.com/querencia-desktop/querencia/issues/new/choose>.
Sicherheitslücken bitte nicht öffentlich melden, siehe [SECURITY.md](SECURITY.md).
