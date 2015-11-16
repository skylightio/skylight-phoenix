CC=cc

ERL_INCLUDE_PATH=$(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

# Compilation options
FLAGS=-fPIC -shared -std=c99
# Includes
FLAGS+=-Ic_src/skylight_x86_64-darwin -I$(ERL_INCLUDE_PATH)
# Warning flags
FLAGS+=-pedantic -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers


# OSX-specific options
ifeq ($(shell uname),Darwin)
	LDFLAGS+=-dynamiclib -undefined dynamic_lookup
endif


.PHONY: all clean


all: priv/skylight_nif.so

priv/skylight_nif.so: c_src/skylight_dlopen.o
	$(CC) $(FLAGS) $(LDFLAGS) $< c_src/skylight_nif.c -o $@

clean:
	rm -fv c_src/**/*.o priv/*.so
