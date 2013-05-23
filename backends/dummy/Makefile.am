SUBDIRS = lib

BACKEND_NAME = "dummy"

AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--vapidir=. \
	--vapidir=$(top_builddir)/backends/dummy/lib \
	--vapidir=$(top_srcdir)/folks \
	$(addprefix --pkg ,$(dummy_deps)) \
	$(NULL)

backenddir = $(BACKEND_DIR)/dummy
backend_LTLIBRARIES = dummy.la

dummy_la_SOURCES = \
	dummy-backend-factory.vala \
	$(NULL)

dummy_deps = \
	folks \
	folks-internal \
	folks-dummy \
	gee-0.8 \
	gio-2.0 \
	gobject-2.0 \
	$(NULL)

dummy_la_CPPFLAGS = \
	-I$(top_srcdir)/folks \
	-I$(top_srcdir)/backends/dummy/lib \
	-I$(top_srcdir)/backends/dummy/lib/folks \
	-include $(CONFIG_HEADER) \
	-DPACKAGE_DATADIR=\"$(pkgdatadir)\" \
	-DBACKEND_NAME=\"$(BACKEND_NAME)\" \
	-DG_LOG_DOMAIN=\"$(BACKEND_NAME)\" \
	$(NULL)

dummy_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(CODE_COVERAGE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

dummy_la_LIBADD = \
	$(AM_LIBADD) \
	$(top_builddir)/backends/dummy/lib/libfolks-dummy.la \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/folks/libfolks-internal.la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

dummy_la_LDFLAGS = \
	$(AM_LDFLAGS) \
	$(CODE_COVERAGE_LDFLAGS) \
	-shared \
	-fPIC \
	-module \
	-avoid-version \
	$(NULL)

GITIGNOREFILES = \
	folks-backend-dummy.vapi \
	$(dummy_la_SOURCES:.vala=.c) \
	dummy_la_vala.stamp \
	$(NULL)

-include backend.mk
-include $(top_srcdir)/git.mk
