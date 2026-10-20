# Querencia Session

Sitzungsstart von [Querencia Desktop](../querencia/README.md): der Starter
`querencia-session`, die labwc-Konfiguration der Sitzung und die
Wayland-Sitzungsdatei für Anmeldebildschirme.

> **Status: Alpha (0.1.0~alpha4).** Auf der Entwicklungs-VM läuft noch der
> Entwicklungsstarter (`herkunft/`). Der portable Stand hier ist mit
> `tests/run.sh` geprüft, aber **noch nicht in einer echten Anmeldung**.

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
     │                            setzt Tastatur/Sprache, gleicht die Benutzerkopie ab, gibt
     │                            Sprache und Desktop an systemd/D-Bus, stoppt die Portale
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
Portale bekommt (QD-062).

## Abhängigkeiten

`labwc (>= 0.9.4)`, `querencia-shell`, `procps` (`pgrep`, `ps`),
`systemd` (`loginctl`), `dbus-user-session`. Ubuntu 26.04 liefert labwc
0.9.3 – siehe `docs/TROUBLESHOOTING.md` im Repository `querencia`.

## Bauen, testen, installieren

Siehe [docs/building.md](docs/building.md) und [docs/testing.md](docs/testing.md).

## Lizenz

GPL-3.0-or-later (wie `querencia-shell`, aus dem die Sitzungsdateien
stammen), siehe [LICENSE](LICENSE).
