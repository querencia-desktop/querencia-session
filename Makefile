# Querencia Session: installs the session starter and its labwc configuration.
# Packages use DESTDIR (see querencia-packaging); nothing here touches $HOME.
PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec
DATADIR ?= $(PREFIX)/share
SYSCONFDIR ?= /etc
DESTDIR ?=

INSTALL ?= install

# Paths written into the installed files (default layout: /usr, /etc).
SUBST = sed -e 's|/usr/bin/querencia-session|$(BINDIR)/querencia-session|g' \
	-e 's|/usr/libexec/querencia/|$(LIBEXECDIR)/querencia/|g' \
	-e 's|^SYSCONFDIR=.*|SYSCONFDIR=$${QUERENCIA_SYSCONFDIR:-$(SYSCONFDIR)}|' \
	-e 's|^BINDIR=.*|BINDIR=$${QUERENCIA_BINDIR:-$(BINDIR)}|' \
	-e 's|/usr/bin/querencia-screenshot}|$(BINDIR)/querencia-screenshot}|'

.PHONY: all install check clean

all:
	@echo "Nichts zu bauen (Shell-Skripte). 'make check', 'make install DESTDIR=…'."

install:
	$(INSTALL) -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(LIBEXECDIR)/querencia \
		$(DESTDIR)$(SYSCONFDIR)/querencia/labwc \
		$(DESTDIR)$(DATADIR)/wayland-sessions $(DESTDIR)$(DATADIR)/applications
	$(SUBST) bin/querencia-session >$(DESTDIR)$(BINDIR)/querencia-session
	chmod 0755 $(DESTDIR)$(BINDIR)/querencia-session
	$(SUBST) libexec/querencia-screenshot-start >$(DESTDIR)$(LIBEXECDIR)/querencia/querencia-screenshot-start
	chmod 0755 $(DESTDIR)$(LIBEXECDIR)/querencia/querencia-screenshot-start
	$(SUBST) labwc/rc.xml >$(DESTDIR)$(SYSCONFDIR)/querencia/labwc/rc.xml
	$(INSTALL) -m 0644 labwc/environment labwc/autostart $(DESTDIR)$(SYSCONFDIR)/querencia/labwc/
	chmod 0644 $(DESTDIR)$(SYSCONFDIR)/querencia/labwc/rc.xml
	$(SUBST) share/wayland-sessions/querencia.desktop >$(DESTDIR)$(DATADIR)/wayland-sessions/querencia.desktop
	chmod 0644 $(DESTDIR)$(DATADIR)/wayland-sessions/querencia.desktop
	$(INSTALL) -m 0644 share/applications/x-querencia-mimeapps.list $(DESTDIR)$(DATADIR)/applications/

check:
	sh tests/run.sh

clean:
	@:
