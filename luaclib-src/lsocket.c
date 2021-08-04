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
#include <sys/eventfd.h>

#define BACKLOG 32

extern int errno;


static int
l_eread(lua_State *L)
{
    uint64_t v;
    int fd = luaL_checkinteger(L, 1);
    size_t len = read(fd, &v, sizeof(uint64_t));
    if (len != sizeof(uint64_t)) {
        perror("eread()");
        lua_pushnil(L);
        return 1;
    }
    lua_pushinteger(L, v);
    return 1;
}


static int
l_ewrite(lua_State *L)
{
    int fd = luaL_checkinteger(L, 1);
    uint64_t v = luaL_checkinteger(L, 2);
    size_t len = write(fd, &v, sizeof(uint64_t));
    if (len != sizeof(uint64_t)) {
        perror("ewrite()");
        lua_pushnil(L);
        return 1;
    }
    lua_pushinteger(L, len);
    return 1;
}


static int
l_eventfd(lua_State *L)
{
    int efd = eventfd(0, 0);
    lua_pushinteger(L, efd);
    return 1;
}


int
setnonblocking(int sockfd)
{
    int flags = fcntl(sockfd, F_GETFL, 0); 
    if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) == -1)
        return -1;
    return 0;
}


static int
l_connect(lua_State *L) {
    const char *ip;
    int fd, port;
    struct sockaddr_in dest_addr = {0};

    ip = luaL_checkstring(L, 1);
    port = luaL_checkinteger(L, 2);

    fd = socket(PF_INET, SOCK_STREAM, 0);
    if (fd == -1) {
        perror("socket.connect()");
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    dest_addr.sin_addr.s_addr = inet_addr(ip);
    dest_addr.sin_port = htons(port);
    dest_addr.sin_family = AF_INET;

    if (connect(fd, (struct sockaddr *)&dest_addr, sizeof(struct sockaddr)) == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    lua_pushinteger(L, fd);
    return 1;
}


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

static int
l_accept(lua_State *L)
{
    static struct sockaddr_in client_addr;
    static socklen_t client_addr_len = sizeof(struct sockaddr_in);

    char * ip;
    int port;
             
    int fd = luaL_checkinteger(L, 1);
    int sock = accept(fd, (struct sockaddr *)&client_addr, &client_addr_len);
    if (sock < 0) {
        if (errno == EAGAIN) {
            lua_pushnil(L);
            lua_pushnil(L);
            lua_pushstring(L, "timeout");
            return 3;
        } else {
            lua_pushnil(L);
            lua_pushnil(L);
            lua_pushstring(L, strerror(errno));
            return 3;
        }
    }

    ip = inet_ntoa(client_addr.sin_addr);
    port = ntohs(client_addr.sin_port);

    int len = strlen(ip);
    char addr[len + 10];
    memcpy(addr, ip, len);
    addr[len] = ':';
    sprintf(addr + len + 1, "%d", port);

    lua_pushinteger(L, sock);
    lua_pushstring(L, addr);
    return 2;
}

static int
l_recv(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int sz = luaL_optinteger(L, 2, 1024);
    char buffer[sz];

    int len = recv(fd, buffer, sz, 0);
    if (len > 0) {
        lua_pushlstring(L, buffer, len);
        return 1;
    } else if (len == 0) {
        lua_pushnil(L);
        lua_pushstring(L, "closed");
        return 2;
    } else {
        if (errno == EAGAIN) {
            lua_pushnil(L);
            lua_pushstring(L, "timeout");
            return 2;
        } else {
            lua_pushnil(L);
            lua_pushstring(L, strerror(errno));
            return 2;
        }       
    }
}


static int
l_send(lua_State *L) {
    size_t sz;
    int fd = luaL_checkinteger(L, 1);
    const char *msg = luaL_checklstring(L, 2, &sz);

    int len = send(fd, msg, (int)sz, 0);
    lua_pushinteger(L, len);
    return 1;
}


static int
l_shutdown(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int err = shutdown(fd, 2); // stop both reception and transmission

    if (err == -1) {
        perror("shutdown");
    }

    return 0;
}

static int
l_close(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    int err = close(fd);
    if (err == -1) {
        perror("close");
    }
    return 0;
}


static int
l_setnonblocking(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    setnonblocking(fd);
    lua_pushinteger(L, fd);
    return 1;
}


static int
l_sleep(lua_State *L) {
    int ti = luaL_checkinteger(L, 1);
    usleep(ti*1000);
    return 0;
}


static int
l_time(lua_State *L)
{   
    struct timeval start;
    gettimeofday( &start, NULL );
    lua_pushinteger(L, 1000*start.tv_sec + start.tv_usec/1000);
    return 1;  /* number of results */
}

extern int
luaopen_lsocket(lua_State* L)
{
    static const struct luaL_Reg lib[] = {
        // public
        {"time", l_time},
        {"sleep", l_sleep},
        
        {"listen", l_listen},
        {"setnonblocking", l_setnonblocking},
        {"shutdown", l_shutdown},
        {"close", l_close},
    
        // udp        
        {"recvfrom", l_recvfrom},
        {"sendto", l_sendto},

        // tcp
        {"listen", l_listen},
        {"accept", l_accept},
        {"send", l_send},
        {"recv", l_recv},
        {"connect", l_connect},

        // eventfd
        {"eventfd", l_eventfd},
        {"ewrite", l_ewrite},
        {"eread", l_eread},
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