CC=cc

ERL_INCLUDE_PATH=$(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Compilation
CFLAGS=-fPIC -g -O3 -ansi -std=c99
# Warnings
CFLAGS+=-pedantic -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
# Includes
CFLAGS+=-Ic_src -I$(ERL_INCLUDE_PATH)

# OSX-specific options
ifeq ($(shell uname),Darwin)
	LDFLAGS+=-dynamiclib -undefined dynamic_lookup
endif


.PHONY: all clean


## TARGETS

all: priv/skylight_nif.so

priv/skylight_nif.so: c_src/skylight_dlopen.o
	$(CC) $(CFLAGS) $(FLAGS) -shared $(LDFLAGS) -o $@ c_src/skylight_dlopen.o c_src/skylight_nif.c

clean:
	rm -fv c_src/*.o priv/skylight_nif.so
