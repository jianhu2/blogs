# ssh端口转发(ssh port-forward)
SSH 除了登录服务器，还有一大用途，就是作为加密通信的中介，充当两台服务器之间的通信加密跳板，使得原本不加密的通信变成加密通信。这个功能称为端口转发（port forwarding），又称 SSH 隧道（tunnel）。
端口转发有两个主要作用：

1. 将不加密的数据放在 SSH 安全连接里面传输，使得原本不安全的网络服务增加了安全性，比如通过端口转发访问 Telnet、FTP 等明文服务，数据传输就都会加密。

2. 作为数据通信的加密跳板，绕过网络防火墙。

端口转发有三种使用方法：本地转发，远程转发，动态转发。 因为常用到了前两种转发，这里只介绍前两种转发。

## 1. 本地转发
本地转发(local forwarding)指的是，将目标服务器的端口(target-host:target-port) 转发跳板机(tunnel-host) 映射到本地端口(local-port); 
然后访问本地的端口(local-port)就可以通过跳板机(tunnel-host)转发到目标服务器的端口(target-host:target-port);

* ``` sh -L local-port:target-host:target-port tunnel-host ```

示例：
- 转发redis到本地16379
  - ```ssh -L 16379:127.0.0.1:6379 dev.hujian.xyz -N ```
  
### 2. 远程转发

远程转发指的是在远程 SSH 服务器建立的转发规则。
它跟本地转发正好反过来。建立本地计算机到远程计算机的 SSH 隧道以后，本地转发是通过本地计算机访问远程计算机，而远程转发则是通过远程计算机访问本地计算机。它的命令格式如下。

```ssh -R remote-port:target-host:target-port -N remotehost```

示例：
- 远程计算机通过```curl http://my.public.server:8080``` 访问本地的80 web服务
  - ```ssh -R 8080:localhost:80 -N my.public.server```

## 3. k8s端口本地转发：

redis端口转发示例：
- ```kubectl port-forward service/redis -n devops-test 26379:6379```

## 4 参考连接：
- [ssh 端口转发](https://wangdoc.com/ssh/port-forwarding.html)
- [An Illustrated Guide to SSH Tunnels](https://solitum.net/posts/an-illustrated-guide-to-ssh-tunnels)
- [kubernetes port-forward](https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)