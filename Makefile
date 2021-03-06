BIN_NAME := mpris-ctl
CC ?= clang
LIBS = dbus-1
COMPILE_FLAGS = -std=c99 -Wpedantic -Wall -Wextra
LINK_FLAGS =
RCOMPILE_FLAGS = -DNDEBUG
DCOMPILE_FLAGS = -g -DDEBUG -O1
RLINK_FLAGS =
DLINK_FLAGS =

SOURCES = src/main.c
DESTDIR = /
INSTALL_PREFIX = usr/local
MAN_DIR = share/man

ifneq ($(LIBS),)
	CFLAGS += $(shell pkg-config --cflags $(LIBS))
	LDFLAGS += $(shell pkg-config --libs $(LIBS))
endif

ifeq ($(shell git describe > /dev/null 2>&1 ; echo $$?), 0)
	VERSION := $(shell git describe --tags --long --dirty=-git --always )
endif
ifneq ($(VERSION), )
	override CFLAGS := $(CFLAGS) -DVERSION_HASH=\"$(VERSION)\"
endif

.PHONY: all
all: debug

.PHONY: check
check: check_leak check_undefined
ifeq ($(CC),clang)
.PHONY: check
check: check_leak check_undefined check_memory
endif

.PHONY: leak
leak: export CFLAGS := $(CFLAGS) $(COMPILE_FLAGS) $(DCOMPILE_FLAGS) -fsanitize=address
leak:
	$(MAKE) BIN_NAME=mpris-ctl-leak

.PHONY: memory
memory: export CFLAGS := $(CFLAGS) $(COMPILE_FLAGS) $(DCOMPILE_FLAGS) -fsanitize=memory
memory:
	$(MAKE) BIN_NAME=mpris-ctl-mem

.PHONY: undefined
undefined: export CFLAGS := $(CFLAGS) $(COMPILE_FLAGS) $(DCOMPILE_FLAGS) -fsanitize=undefined
undefined:
	$(MAKE) BIN_NAME=mpris-ctl-undef

.PHONY: check_leak
check_leak:
	$(MAKE) leak run clean

.PHONY: check_memory
check_memory:
	$(MAKE) memory run clean

.PHONY: check_undefined
check_undefined:
	$(MAKE) undefined run clean

.PHONY: run
run: $(BIN_NAME)
	./$(BIN_NAME) info || test $$? -eq 1

release: export CFLAGS := $(CFLAGS) $(COMPILE_FLAGS) $(RCOMPILE_FLAGS)
release: export LDFLAGS := $(LDFLAGS) $(LINK_FLAGS) $(RLINK_FLAGS)
debug: export CFLAGS := $(CFLAGS) $(COMPILE_FLAGS) $(DCOMPILE_FLAGS)
debug: export LDFLAGS := $(LDFLAGS) $(LINK_FLAGS) $(DLINK_FLAGS)

$(BIN_NAME).1: $(BIN_NAME).1.scd
	scdoc < $< >$@

.PHONY: release
release: $(BIN_NAME)

.PHONY: debug
debug: $(BIN_NAME)

.PHONY: clean
clean:
	$(RM) $(BIN_NAME)
	$(RM) $(BIN_NAME).1

.PHONY: install
install: $(BIN_NAME) $(BIN_NAME).1
	install $(BIN_NAME) $(DESTDIR)$(INSTALL_PREFIX)/bin
	install -m 644 $(BIN_NAME).1 $(DESTDIR)$(INSTALL_PREFIX)/$(MAN_DIR)/man1

.PHONY: uninstall
uninstall:
	$(RM) $(DESTDIR)$(INSTALL_PREFIX)/bin/$(BIN_NAME)
	$(RM) $(DESTDIR)$(INSTALL_PREFIX)/$(MAN_DIR)/man1/$(BIN_NAME).1

$(BIN_NAME): $(SOURCES) src/*.h
	$(CC) $(CFLAGS) $(INCLUDES) $(SOURCES) $(LDFLAGS) -o$(BIN_NAME)
