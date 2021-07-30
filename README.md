# lserver (Alias: Staree)



### 概述
```
总体思路就是做一个基于ltask 的数据与逻辑分离的游戏服务端框架, 后期数据可能加入持久化的功能.
可以说就是一个面数据(库)的游戏服务端框架
```


### Test (Linux)
```
0. 系统预先安装好lua5.4
1. 克隆代码到本地
2. 创建 luaclib 文件夹
3. 进入ltask, make, 将编译好的 ltask.so 拷贝到 luaclib 文件夹下
4. 进入 luaclib-src, make, 将编译好的 若干so文件 拷贝到 luaclib 文件夹下
5. 在lserver文件下 lua main.lua config
6. 新开一个窗口 nc 127.0.0.1 6666, 然后输入 hello
```