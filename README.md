# lserver (Alias: Staree)

### 概述
```
总体思路就是做一个基于ltask (or skynet) 的数据与逻辑分离的游戏服务端框架, 后期数据可能加入持久化的功能.
可以说就是一个面数据(库)的游戏服务端框架, lserver 旨在提供更简单轻松的开发体验。
由于ltask提供的基础功能太少(socket, db driver 等)这些功能都自己做的话，难免不太成熟. 后面做
一个基于skynet的版本可能更适合正式项目
```


### Why
[跨服务的事务问题](https://blog.codingnow.com/2016/07/skynet_transaction.html)
```
用过 skynet 的同学都知道其中一点比较麻烦的地方, 比如服务中函数重入导致的数据不一致问题, 上面链接的跨服务事务问题
比如管理服务, 逻辑的热更, 这些严重加大了开发者的心智负担以及BUG产生率(自我感觉),
从而导致了这个框架的诞生, 引用上面链接中的一个评论: "在需要多次往返Actor之间进行通信的时候，感觉非常痛苦"
```


### How
```
怎么解决 skynet 开发的弊端，提升开发者的开发体验, 让开发者把精力更集中与解决业务问题，而不是其他。
我的思路就是 数据(状态)与逻辑分离, lserver 中会启动若干个 worker 服务, worker 里面都是业务逻辑,没有业务状态,
他们是完全平等的，或者说相同的.worker 被外部事件驱动 (网络事件, 定时器)。事件会平均分配到 各个 worker 里。 
说到这，lserver 里的 业务状态到底放在哪呢? 答案是 每个状态都有一个唯一的名字并存储在一个单独的服务里(state-cell),
worker在处理一个事件的时候, 会通过接口查询并锁住相关state, 用完后会更新相关state 并解锁。 
```


### 对比 Skynet 服务器开发优势
```
1. 没有函数重入和多服务之间的事务问题(通过 lock/unlock state 解决)
2. 无需管理服务 (一切逻辑都在worker里)
3. 由于worker 是纯逻辑, 热更变的非常简单, 从外部修改某个 state 也很简单
4. 后期将加入 state 可选的持久化功能，比如我们将游戏中的房间状态进行持久化, 则可以做到重启服务器房间依然可以继续玩
5. 暂时这些把，其他的想到了再说
```


### 网关设计 (tcp)
```
network-tcp 服务进行网络监听和读取 (socket事件在gate中处理) 对连接进行鉴权, 处理登录请求, 登录成功后, 对后续的消息进行切包(同skynet 2字节头, 小端)发送到worker进行处理,
并处理重连，顶号的逻辑, worker 只处理业务逻辑(玩家登录, 玩家请求, 玩家登出)
```


### 数据库 (mongo)
```
数据库目前只打算集成mongo, 用的是云大的lua-mongo, 用的时候发现没有验证账号功能，于是我从skynet中把这个功能合并了过来.
```


### ORM (state persistent)
```
有了数据库之后, lserver 的另一大优势就可以做了，state 自动落地(可选). 接口可以设计成这样 starre.new(name, t, persistent, filter)
state 可能包含一些字段我们并不想存数据库, 可以传一个 filter 过滤, 比如 player's filter: {id = true, gold = true, diamond = true}

还可以在后台(Debug Console)提供一个接口, 更据 state 的名字，从数据库从新加载, (比如从后台更新活动时间之类的需求，将非常好解决)
```


### Test (Linux)
```
0. 系统预先安装好lua5.4
1. 克隆代码到本地, 进入lserver 并创建 luaclib 文件夹
2. 进入ltask, make, 将编译好的 ltask.so 拷贝至luaclib, 进入3rd下各个库, make or make linux, 然后将 so文件 拷贝至luaclib
3. 进入 luaclib-src, make, 然后 make install
4. 在lserver文件下 lua main.lua config
5. 新开一个窗口 lua client.lua 运行模拟客户端

```



## 捐赠 
```
如果你对这个项目感兴趣的话,欢迎赞助
```
<img src="https://raw.githubusercontent.com/HYbutterfly/Fantasy-scorpio-donation/master/wechatpay.png" align="left" height="400" width="300">
<img src="https://raw.githubusercontent.com/HYbutterfly/Fantasy-scorpio-donation/master/alipay.png" height="400" width="300">