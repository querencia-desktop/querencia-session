# Bauen und installieren – querencia-session

Es gibt nichts zu übersetzen (POSIX-Shell-Skripte und Konfiguration).

```bash
make check                          # Testsuite, siehe TESTING.md
make install DESTDIR=/tmp/stage     # Probeinstallation in einen Ordner
```

Variablen: `PREFIX` (`/usr`), `BINDIR`, `LIBEXECDIR`, `DATADIR`,
`SYSCONFDIR` (`/etc`), `DESTDIR`. Abweichende Pfade werden beim Installieren
in den Starter, die Sitzungsdatei und `rc.xml` eingesetzt.

Pakete baut das Repository `querencia-packaging`; direkt nach `/usr` sollte
nur der Paketbau installieren.
