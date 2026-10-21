# Anmeldebildschirm (greetd) – Beispiele

**Nichts davon wird vom Paket aktiviert.** Das Paket `querencia-session`
legt nur `/usr/share/wayland-sessions/querencia.desktop` ab; jeder
Anmeldebildschirm, der Wayland-Sitzungen liest (GDM, SDDM, LightDM mit
passendem Greeter, ReGreet, tuigreet mit `--sessions`), bietet „Querencia
Desktop“ dann zur Auswahl an. Ein bereits eingerichteter Anmeldebildschirm
bleibt unverändert.

Wer greetd neu einrichten will, tut das als **eigenen, bewussten Schritt**
(fertig eingerichtet liefert das Paket `querencia-anmeldung` greetd mit
ReGreet, siehe Repository `querencia-anmeldung`):

- `config.toml.tuigreet` – nur Pakete aus Ubuntu (`greetd`, `tuigreet`).
- `config.toml.regreet` – grafischer Greeter ReGreet in `cage`; ReGreet ist
  **nicht** in Ubuntu 26.04 enthalten (das Paket `querencia-anmeldung`
  bringt ihn mit).

Vor dem Aktivieren prüfen, dass eine lokale grafische Ausgabe existiert
(`ls /dev/dri/card*`), sonst startet der grafische Greeter nicht. Eine
Textkonsole (Strg+Alt+F2) bleibt in jedem Fall erreichbar, weil greetd nur
sein eigenes VT belegt.
