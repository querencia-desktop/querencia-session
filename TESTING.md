# Testen – querencia-session

```bash
sh tests/run.sh       # oder: make check
```

Die Tests laufen mit leerer Umgebung (`env -i`), eigenem Wegwerf-`HOME`,
einem gefälschten `labwc` und gefälschten Programmen. Sie starten nie labwc,
nie ein Panel und sprechen keine laufende Sitzung an. Geprüft werden u. a.
labwc-Versionsgrenze (0.9.3 abgelehnt), `--check`, `session.conf`
(Werte werden nie ausgeführt), Wahl der Benutzer- bzw. Systemkonfiguration,
Verweigerung in einer bestehenden Wayland-Sitzung und ohne logind,
Sitzungsdatei, Druck-Taste und eine Probeinstallation ohne Entwicklerpfade.

Nicht abgedeckt (braucht eine echte Anmeldung, siehe `docs/TESTING.md` im
Repository `querencia`): Start von labwc, Panel und Desktop, Abmelden,
Aufräumen übrig gebliebener Prozesse.
