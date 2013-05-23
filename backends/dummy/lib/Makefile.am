BACKEND_NAME = "dummy"

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/folks \
	-include $(CONFIG_HEADER) \
	-include folks/redeclare-internal-api.h \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

VAPIGENFLAGS += \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	$(NULL)

folks_dummydir = $(libdir)
folks_dummy_LTLIBRARIES = libfolks-dummy.la

##################################################################
# Support library
##################################################################

libfolks_dummy_la_vala.stamp:

folks_dummy_valasources = \
	dummy-backend.vala \
	dummy-fat-persona.vala \
	dummy-persona.vala \
	dummy-persona-store.vala \
	$(NULL)

libfolks_dummy_la_SOURCES = \
	$(folks_dummy_valasources) \
	$(NULL)

# XXX: it would be nice to do something like this below:
#    $(addprefix --pkg ,$(folks_backend_dummy_deps)) \
# to factor out repetition, but automake's Vala support doesn't like it
# because it assumes it can simply match every flag in any _VALAFLAGS string.
libfolks_dummy_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_srcdir)/folks \
	--pkg folks \
	--pkg folks-internal \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg gobject-2.0 \
	--includedir folks \
	--vapi folks-dummy.vapi \
	-H folks/folks-dummy.h \
	$(NULL)

libfolks_dummy_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libfolks_dummy_la_LIBADD = \
	$(AM_LIBADD) \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/folks/libfolks-internal.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

# The quoting here is unnecessary but harmless, and has the useful side-effect
# that vim quickfix mode (:make) doesn't interpret the libtool --mode=link
# command as an error message in a bizarrely named file
libfolks_dummy_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-version-info "$(LT_CURRENT)":"$(LT_REVISION)":"$(LT_AGE)" \
	-export-symbols-regex "^(DUMMY|dummy)_.*|" \
	$(NULL)

folks_dummy_includedir = $(includedir)/folks
folks_dummy_include_HEADERS = \
	folks/folks-dummy.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	folks-dummy.vapi \
	folks-dummy.deps \
	$(NULL)

##################################################################
# General
##################################################################

MAINTAINERCLEANFILES = \
	$(folks_dummy_valasources:.vala=.c) \
	libfolks_dummy_la_vala.stamp \
	folks/folks-dummy.h \
	folks-dummy.vapi \
	$(NULL)

EXTRA_DIST = \
	$(pkgconfig_in) \
	$(MAINTAINERCLEANFILES) \
	$(NULL)

-include ../backend.mk
-include $(top_srcdir)/git.mk
