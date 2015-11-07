compile: skylight_dlopen.o
	cc \
		-fPIC \
		-I/Users/whatyouhide/.erlangs/18.1/usr/include \
		-shared -dynamiclib \
		-Wall \
		-std=c99 \
		-undefined dynamic_lookup \
		skylight_dlopen.o skylight_nif.c \
		-o skylight_nif.so

clean:
	rm -fv *.o *.so
