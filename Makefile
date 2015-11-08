CC=cc

ERL_INCLUDE_PATH=$(HOME)/.erlangs/18.1/usr/include

FLAGS=-fPIC
FLAGS+=-shared
FLAGS+=-dynamiclib
FLAGS+=-std=c99
FLAGS+=-undefined dynamic_lookup
FLAGS+=-I$(ERL_INCLUDE_PATH)
FLAGS+=-Ic_src/skylight_x86_64-darwin

FLAGS+=-Wall

all: priv/skylight_nif.so

priv/skylight_nif.so: c_src/skylight_x86_64-darwin/skylight_dlopen.o
	$(CC) $(FLAGS) c_src/skylight_x86_64-darwin/skylight_dlopen.o c_src/skylight_nif.c -o priv/skylight_nif.so

clean:
	rm -fv c_src/**/*.o priv/*.so
