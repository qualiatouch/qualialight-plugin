RACK_DIR ?= ../..

# FLAGS will be passed to both the C and C++ compiler
FLAGS +=
CFLAGS +=
CXXFLAGS += $(shell pkg-config --cflags libola)

# Careful about linking to shared libraries, since you can't assume much about the user's environment and library search path.
# Static libraries are fine, but they should be added to this plugin's build system.
LDFLAGS += $(shell pkg-config --libs libola)

# Add .cpp files to the build
rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
SOURCES += $(call rwildcard,src,*.cpp)

# OLA libraries (Linux only)
#ifdef ARCH_LIN
  CXXFLAGS += -Idep/ola/include

  OBJECTS += dep/ola/lib/libola.a
  OBJECTS += dep/ola/lib/libolacommon.a
  # OBJECTS += dep/ola/lib/libolaproto.a
  OBJECTS += dep/ola/lib/libprotobuf.a
  OBJECTS += dep/ola/lib/libuuid.a

  # System libraries that OLA depends on
  # LDFLAGS += -lprotobuf -luuid -lpthread
  LDFLAGS += -lpthread

  # Tell the build system these need to be built first
  # DEPS += $(OBJECTS)
  DEPS += dep/ola/lib/libola.a
#endif

# Add files to the ZIP package when running `make dist`
# The compiled plugin and "plugin.json" are automatically added.
DISTRIBUTABLES += res
DISTRIBUTABLES += $(wildcard LICENSE*)
DISTRIBUTABLES += $(wildcard README*)

# Include the Rack plugin Makefile framework
include $(RACK_DIR)/plugin.mk

# Build recipe for OLA (runs inside Docker container)
#ifdef ARCH_LIN
dep/ola/lib/libola.a:
	# Install build dependencies
	sudo apt-get update
	sudo apt-get install -y \
		autoconf \
		automake \
		libtool \
		libprotobuf-dev \
		protobuf-compiler \
		libprotoc-dev \
		pkg-config \
		libcppunit-dev \
		bison \
		flex \
		uuid-dev
	# Clone and build OLA
	mkdir -p dep
	cd dep && git clone --depth 1 --branch master https://github.com/OpenLightingProject/ola.git ola-src
	cd dep/ola-src && autoreconf -fi
	cd dep/ola-src && CXX="g++ -std=c++11" ./configure \
		--disable-all-plugins \
		--disable-osc \
		--disable-uart \
		--disable-libusb \
		--disable-libftdi \
		--disable-http \
		--disable-examples \
		--disable-unittests \
		--enable-rdm-tests=no \
		--disable-shared --enable-static \
		--prefix=$(abspath dep/ola)
	cd dep/ola-src && $(MAKE) -j$(shell nproc)
	cd dep/ola-src && $(MAKE) install
	# Copy system static libraries into dep so toolchain can find them
	mkdir -p dep/ola/lib
	cp /usr/lib/x86_64-linux-gnu/libprotobuf.a dep/ola/lib/ || true
	cp /usr/lib/x86_64-linux-gnu/libuuid.a dep/ola/lib/ || true

dep/ola/lib/libolacommon.a: dep/ola/lib/libola.a
#dep/ola/lib/libolaproto.a: dep/ola/lib/libola.a

#endif
