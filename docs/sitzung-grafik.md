# Software-OpenGL bei zink auf NVK (QD-169)

Seit 0.1.0~alpha10. Betrifft `bin/querencia-session` und die
Autostart-Vorgabe `labwc/autostart`. Gleiche Logik wie der
Entwicklungsstarter in querencia-runtime (`session/grafik-1`,
`docs/sitzung-grafik.md` dort, mit Messungen).

## Warum

Mit einer NVIDIA-Karte und dem freien Treiber (nouveau) läuft OpenGL in
Mesa 26 als zink auf Vulkan (NVK). Der Renderer heißt dann z. B.

```text
zink Vulkan 1.4(NVIDIA GeForce RTX 3060 (NVK GA106) (MESA_NVK))
```

WebKit-Web-Prozesse stürzen dort ab, Firefox friert ein. Mit
`LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
GALLIUM_DRIVER=llvmpipe` (llvmpipe, OpenGL auf der CPU) laufen beide.
Panel und Arbeitsfläche zeichnen mit GTK 4 über Vulkan und merken davon
nichts.

## Was der Starter tut

1. **Einstellung** aus `~/.config/querencia/grafik.ini`:

   ```ini
   [Grafik]
   Software-OpenGL = automatisch
   ```

   `automatisch` (Vorgabe, auch ohne Datei), `an` (immer) oder `aus`
   (nie). Groß- und Kleinschreibung zählen nicht; der Schlüssel gilt nur
   unter `[Grafik]`. Ein unbekannter Wert gilt als `automatisch`, mit
   Hinweis im Protokoll.
2. **Vorprüfung:** Kerneltreiber der Render-Knoten
   (`/sys/class/drm/renderD*/device/driver`). Nur wenn einer `nouveau`
   ist, wird geprüft. `amdgpu`, `i915`/`xe`, `nvidia` (NVIDIA-Treiber) oder
   kein Render-Knoten: nichts, keine Zeit.
3. **Renderer-Prüfung** im Hintergrund, während der Starter Reste
   früherer Sitzungen beendet und die Benutzerkopie abgleicht:
   `querencia-sitzung --grafik-pruefen` (Paket querencia-sitzung ab 0.1.8),
   fehlt es oder scheitert es, `eglinfo -B -p surfaceless -a gles`
   (mesa-utils). Der Starter wartet höchstens 2 s ab Prüfbeginn, nur auf
   eine Fertig-Datei, nie auf den Prozess.
4. **Entscheidung** vor dem Setzen der Aktivierungsumgebung: Beginnt der
   Renderer mit `zink` und nennt NVK oder nouveau, bekommt die Sitzung die
   drei Variablen. Jeder andere Renderer und eine Prüfung ohne Ergebnis:
   nichts. `VK_*` setzt der Starter nie.
5. **Wohin:**
   - Aktivierungsumgebung von systemd und D-Bus (QD-064), nach dem Ende
     von labwc zurückgenommen;
   - Autostart: labwc bekommt nur `QUERENCIA_GRAFIK_UMGEBUNG`, der
     Autostart exportiert daraus genau die drei Namen für polkit-Agent,
     Arbeitsfläche, Panel, Benachrichtigungen und was diese starten;
   - **labwc selbst nicht** (es setzt mit GLES über zink zusammen;
     `MESA_LOADER_DRIVER_OVERRIDE` träfe seine GBM-Puffer). Was labwc
     direkt startet (Tastenkürzel aus `rc.xml`, XWayland), läuft wie
     bisher.
6. **Protokoll:** eine Zeile in `~/.local/state/querencia/sitzung-start.log`,
   z. B.

   ```text
   querencia-session: Grafik: OpenGL unverändert (Kerneltreiber amdgpu, kein nouveau: nicht geprüft)
   ```

   Hat die Benutzerkopie von `autostart` den Abschnitt nicht (eigene
   Datei), steht ein Hinweis darunter; dann gilt Software-OpenGL nur über
   die Aktivierungsumgebung.

`querencia-session --grafik-pruefen` zeigt dieselbe Zeile, ohne etwas zu
starten oder zu ändern.

## Grenzen

- dbus-daemon kann Werte der Aktivierungsumgebung nicht löschen; nach dem
  Abmelden behält er die drei Variablen für Dienste ohne
  `SystemdService=` bis zur nächsten Anmeldung.
- Eine Prüfung, die über die Zeitgrenze hängt, läuft weiter, bis sie von
  selbst endet; danach bleiben ihre Dateien `grafik-pruefung.<PID>` und
  `grafik-pruefung.<PID>.fertig` in `~/.local/state/querencia/` liegen
  (klein, ohne Wirkung; wie im Entwicklungsstarter).
- Nach dem Wechsel zum NVIDIA-Treiber (`nvidia`) prüft der Starter nicht
  mehr; der Rückfall fällt beim nächsten Login von selbst weg.
