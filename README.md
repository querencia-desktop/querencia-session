# Querencia Session

Sitzungsstart von [Querencia Desktop](../querencia/README.md): der Starter
`querencia-session`, die labwc-Konfiguration der Sitzung und die
Wayland-Sitzungsdatei für Anmeldebildschirme.

> **Status: Alpha (0.1.0~alpha2).** Auf der Entwicklungs-VM läuft noch der
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

Nichts wird in Home-Verzeichnisse geschrieben, kein Anmeldebildschirm wird
aktiviert. Zur Laufzeit legt der Starter `~/.local/state/querencia/` an
(Logs, PID-Einträge).

## Ablauf

```
Anmeldebildschirm / Konsole
  └─ querencia-session            prüft: keine andere Sitzung, logind-Sitz, labwc ≥ 0.9.4,
     │                            Konfiguration, querencia-panel; setzt Tastatur/Sprache
     └─ labwc -C /etc/querencia/labwc        (oder ~/.config/querencia/labwc, falls vollständig)
        └─ autostart  ─ querencia-polkit-agent         Passwortdialog für polkit (optional)
                      ─ querencia-einstellungen        gespeicherte Bildschirmanordnung (optional)
                      ─ querencia-desktop              Hintergrund, Symbole (optional)
                      ─ querencia-panel                oberes und unteres Panel
                      ─ querencia-benachrichtigungen   Benachrichtigungen (optional)
                      ─ querencia-sitzung --leerlauf   Leerlaufsperre (optional)
```

Abmelden: Menü „System → Abmelden …“ (Panel, `labwc --exit`) oder
`querencia-session --exit` aus einer anderen Shell desselben Benutzers.

## Abhängigkeiten

`labwc (>= 0.9.4)`, `querencia-shell`, `procps` (`pgrep`, `ps`),
`systemd` (`loginctl`), `dbus-user-session`. Ubuntu 26.04 liefert labwc
0.9.3 – siehe `docs/TROUBLESHOOTING.md` im Repository `querencia`.

## Bauen, testen, installieren

Siehe [BUILDING.md](BUILDING.md) und [TESTING.md](TESTING.md).

## Lizenz

GPL-3.0-or-later (wie `querencia-shell`, aus dem die Sitzungsdateien
stammen), siehe [LICENSE](LICENSE).
