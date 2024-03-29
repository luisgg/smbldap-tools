## Common Makefile
## ======================================================================

PACKAGE_NAME=		smbldap-tools
PACKAGE_VERSION=	0.9.6.svn
PACKAGE_TARNAME=	smbldap-tools

## Path
## ----------------------------------------------------------------------

INSTALL_ROOT=		$(DESTDIR)

package_subdir=		/smbldap-tools

prefix=			/usr/local
exec_prefix=		${prefix}
bindir=			${exec_prefix}/bin
sbindir=		${exec_prefix}/sbin
libdir=			${exec_prefix}/lib
libexecdir=		${exec_prefix}/libexec${package_subdir}
sysconfdir=		${prefix}/etc${package_subdir}
localstatedir=		${prefix}/var
datarootdir=		${prefix}/share
datadir=		${datarootdir}${package_subdir}
mandir=			${datarootdir}/man
infodir=		${datarootdir}/info
docdir=			${datarootdir}/doc/${PACKAGE_TARNAME}

vardir=			${localstatedir}/lib${package_subdir}
rundir=			${localstatedir}/run${package_subdir}
logdir=			${localstatedir}/log${package_subdir}

PERL_LIBDIR=		/usr/share/perl5

## Commands, Flags and so on
## ----------------------------------------------------------------------

SUBST=			$(BUILD_COMMON)/subst
CP=			cp -p
RM=			rm -rf
LN_S=			ln -s
INSTALL=		$(BUILD_COMMON)/install-sh -c
CHMOD_FILES=		chmod 0644
CHMOD_CMDS=		chmod 0755
## ----------------------------------------------------------------------

BUILD_TARGETS_TOP=	$(BUILD_COMMON)/subst

## Package local
## ----------------------------------------------------------------------

include $(BUILD_COMMON)/Makefile.package

## Suffix rules
## ======================================================================

.SUFFIXES: .pl .pm .cmd .example .tmpl

.pl.cmd:
	@echo "Building $@ from $< ..."
	@$(RM) $@ $@.tmp
	@$(BUILD_COMMON)/subst <$< >$@.tmp
	@$(CHMOD_CMDS) $@.tmp
	@mv $@.tmp $@

.pl.pm:
	@echo "Building $@ from $< ..."
	@$(RM) $@ $@.tmp
	@$(BUILD_COMMON)/subst <$< >$@.tmp
	@$(CHMOD_FILES) $@.tmp
	@mv $@.tmp $@

.tmpl.example:
	@echo "Building $@ from $< ..."
	@$(RM) $@ $@.tmp
	@$(BUILD_COMMON)/subst <$< >$@.tmp
	@$(CHMOD_FILES) $@.tmp
	@mv $@.tmp $@

## Target rules
## ======================================================================

default:: build

build:: $(BUILD_TARGETS)

$(BUILD_TARGETS):: $(BUILD_COMMON)/subst

install:: $(INSTALL_TARGETS)

install-dir:
	@echo "Creating directory $(INSTALL_ROOT)$(INSTALL_DIR) ..."
	@$(INSTALL) -d $(INSTALL_ROOT)$(INSTALL_DIR)

install-files: install-dir
	@for f in $(INSTALL_FILES); do \
	    echo "Installing file $$f into $(INSTALL_ROOT)$(INSTALL_DIR) ..."; \
	    $(INSTALL) -m 0644 -t='s/\.substed$$//' $$f "$(INSTALL_ROOT)$(INSTALL_DIR)" \
	      || exit 1; \
	done

install-cmd-dir:
	@echo "Creating directory $(INSTALL_ROOT)$(INSTALL_CMD_DIR) ..."
	@$(INSTALL) -d $(INSTALL_ROOT)$(INSTALL_CMD_DIR)

install-cmds: install-cmd-dir
	@for f in $(INSTALL_CMDS); do \
	    echo "Installing file $$f into $(INSTALL_ROOT)$(INSTALL_CMD_DIR) ..."; \
	    $(INSTALL) -m 0755 -t='s/\.cmd$$//' $$f "$(INSTALL_ROOT)$(INSTALL_CMD_DIR)" \
	      || exit 1; \
	done

clean::
	$(RM) $(BUILD_TARGETS) $(BUILD_TARGETS_POST) *.tmp

distclean:: clean

build install clean distclean::
	@if [ -n "$(DIRS)" ]; then \
	    set - $(DIRS); \
	    for subdir in "$$@"; do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	    done \
	fi

build:: $(BUILD_TARGETS_POST)

$(BUILD_COMMON)/subst: $(BUILD_COMMON)/subst.pl $(BUILD_COMMON)/Makefile $(BUILD_COMMON)/Makefile.package
	cp $< $@.tmp
	$(PERL_CMD) -ne 'print if s/^(\w+)\s*=\s*(.*?)\s$$/$$1=$$2\n/' $(BUILD_COMMON)/Makefile $(BUILD_COMMON)/Makefile.package >>$@.tmp
	chmod 0755 $@.tmp
	mv $@.tmp $@

