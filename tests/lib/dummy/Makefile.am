AM_VALAFLAGS += \
	$(ERROR_VALAFLAGS) \
	--library=dummy-test \
	--header=dummy-test.h \
    --vapidir=$(top_srcdir)/folks \
	--vapidir=$(top_srcdir)/backends/dummy/lib \
	--vapidir=$(top_srcdir)/backends/dummy/vapi \
	--vapidir=$(abs_top_srcdir)/tests/lib \
	--vapidir=$(abs_top_builddir)/tests/lib \
    --vapidir=. \
    --pkg gee-0.8 \
    --pkg folks-dummy \
	--pkg folks-test \
	-g \
	$(NULL)

noinst_LTLIBRARIES = libdummy-test.la

libdummy_test_la_SOURCES = \
	test-case.vala \
	$(NULL)

libdummy_test_la_CFLAGS = \
	-I$(top_srcdir) \
    -I$(top_srcdir)/folks \
	-I$(top_srcdir)/tests/lib \
	-I$(top_srcdir)/backends/dummy/lib \
	-I$(top_srcdir)/backends/dummy/lib/folks \
	$(AM_CFLAGS) \
	$(ERROR_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

libdummy_test_la_LIBADD = \
	$(top_builddir)/folks/libfolks.la \
	$(top_builddir)/tests/lib/libfolks-test.la \
	$(top_builddir)/backends/dummy/lib/libfolks-dummy.la \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	dummy-test.vapi \
	dummy-test.h \
	$(NULL)

EXTRA_DIST = \
	dummy-test.deps \
	dummy-test.vapi \
	dummy-test.h \
	$(NULL)

GITIGNOREFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala,$(libdummy_test_la_SOURCES))) \
	libdummy_test_la_vala.stamp \
	$(NULL)

-include $(top_srcdir)/git.mk
