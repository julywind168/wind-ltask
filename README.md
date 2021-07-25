# lserver (Alias: Staree)



### 概述
```
总体思路就是做一个基于ltask 的数据与逻辑分离的游戏服务端框架, 后期数据可能加入持久化的功能.
可以说就是一个面数据(库)的游戏服务端框架
```


### Test (Linux)
````
0. 系统预先安装好lua5.4
1. 克隆代码到本地
2. 创建 luaclib 文件夹
3. 进入ltask, make, 将编译好的 ltask.so 拷贝到 luaclib 文件夹下
4. 在lserver文件下 lua main.lua config
```