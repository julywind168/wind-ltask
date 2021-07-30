all:
	gcc lsocket.c -fPIC -shared -o lsocket.so -Wall -O3
	gcc lepoll.c -fPIC -shared -o lepoll.so -Wall -O3


install:
	cp lsocket.so ../luaclib/lsocket.so
	cp lepoll.so ../luaclib/lepoll.so