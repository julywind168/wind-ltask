#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>

#define BACKLOG 32

extern int errno;



static int
l_sendto(lua_State *L) {
    int fd, port; 
    const char *host;
    const char *msg;
    size_t msglen;

    struct sockaddr_in to_addr = {0};
    uint32_t tolen = sizeof(to_addr);

    fd = luaL_checkinteger(L, 1);
    host = luaL_checkstring(L, 2);
    port = luaL_checkinteger(L, 3);
    msg = luaL_checklstring(L, 4, &msglen);

    to_addr.sin_family = AF_INET;
    to_addr.sin_port = htons(port);
    to_addr.sin_addr.s_addr = inet_addr(host);

    int len = sendto(fd, msg, msglen, 0, (struct sockaddr *) &to_addr, tolen);
    if (len > 0) {
        lua_pushinteger(L, len);
        return 1;
    } else {
        if (len < 0) { perror("sendto\n"); }
        return 0;
    }
}


static int
l_recvfrom(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int sz = luaL_optinteger(L, 2, 1024);
    char buffer[sz];

    struct sockaddr_in  from_addr = {0};
    uint32_t fromlen = sizeof(from_addr);

    int len = recvfrom(fd, buffer, sz, 0, (struct sockaddr *)&from_addr, &fromlen);
    if (len > 0) {
        lua_pushstring(L, inet_ntoa(from_addr.sin_addr));
        lua_pushinteger(L, ntohs(from_addr.sin_port));
        lua_pushlstring(L, buffer, len);
        return 3;
    } else {
        if (len < 0) { perror("recvfrom\n"); }
        return 0;
    }
}


static int
l_listen(lua_State *L) {
    static int reuse = 1;
    const char * host;
    int fd, port, proto;
    struct sockaddr_in my_addr = {0};

    host = luaL_checkstring(L, 1);
    port = luaL_checkinteger(L, 2);
    proto = (short)luaL_optinteger(L, 3, SOCK_STREAM);

    if ((fd = socket(PF_INET, proto, 0)) == -1) {
        perror("socket\n");
        return 0;
    }

    my_addr.sin_family = AF_INET;
    my_addr.sin_port = htons(port);
    my_addr.sin_addr.s_addr = inet_addr(host);

    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) == -1) {
        perror("setsockopet\n");
        return 0;
    }

    if (bind(fd, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) == -1) {
        perror("bind\n");
        return 0;
    }

    if (proto == SOCK_STREAM) {
        if (listen(fd, BACKLOG) == -1) {
            perror("listen\n");
            return 0;
        }        
    }

    lua_pushinteger(L, fd);
    return 1;
}

extern int
luaopen_lsocket(lua_State* L)
{
    static const struct luaL_Reg lib[] = {
        {"listen", l_listen},
        {"recvfrom", l_recvfrom},
        {"sendto", l_sendto},
        {NULL, NULL}
    };
    luaL_newlib(L, lib);

#define SETCONST(VALUE) \
    lua_pushinteger(L,VALUE); \
    lua_setfield(L,-2,#VALUE) \

    SETCONST(SOCK_STREAM);
    SETCONST(SOCK_DGRAM);


    return 1;
}