# shadowsocks-libev基于ubuntu宿主机部署ss-local客户端.md

# 1. 安装
## 1.1 准备环境：
  - Linux ubuntu 6.2.0-20-generic ubuntu  2023-04 amd64
  -  基于ubuntu宿主机安装 shadowsocks-libev和v2ray-plugin
## 1.2  安装shadowsocks-libev：
     sudo apt install shadowsocks-libev
## 1.3   安装v2ray-plugin

``` shell
wget https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.2/v2ray-plugin-linux-amd64-v1.3.2.tar.gz
tar -zxvf v2ray-plugin-linux-amd64-v1.3.2.tar.gz     
mv v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin
chmod  775 /usr/bin/v2ray-plugin
```

## 1.3 配置shadowsocks-libev配置文件
```
vi /etc/shadowsocks-libev/config.json

{
"server": "domain.com",
"server_port": 443,
"password": "password",
"method": "aes-128-gcm",
"local_address": "0.0.0.0",
"local_port": 1080,
"plugin": "/usr/bin/v2ray-plugin",
"plugin_opts": "tls;host=domain.com;path=/",
"plugin_args": "",
"remarks": "proxy",
"timeout": 10,
"mode": "tcp_and_udp"
}
```
## 1.4 把shadowsocks-libe.service的ss-server修改成ss-local
```shell
cat /lib/systemd/system/shadowsocks-libev.service
ExecStart=/usr/bin/ss-local -c $CONFFILE $DAEMON_ARGS

sudo systemctl daemon-reload
sudo systemctl restart shadowsocks-libev
```
# 2. 测试ip代理是否成功
```
curl -v  ip.gs   // 能成功显示代理IP则成功
curl --socks5 127.0.0.1:1080 https://www.google.com  // 测试是否能访问google
```
# 3. 配置http_proxy：
v2ray-plugs是用的socks5协议，所以本地走代理的话需要配置http_proxy=socks5
## 3.1 临时配置http_proxy
```
export http_proxy=socks5://127.0.0.1:1080
export https_proxy=$http_proxy
```

## 3.2 永久配置http_proxy

```shell
vi  /etc/profile

PROXY_HOST=127.0.0.1
PROXY_PORT=1080
export http_proxy=socks5://$PROXY_HOST:$PROXY_PORT
export https_proxy=$http_proxy
export no_proxy=localhost,172.16.0.0/16,192.168.0.0/16.,127.0.0.1,10.10.0.0/16,192.168.159.0/24,192.168.171.0/24

source /etc/profile
```

# 4. 取消http_proxy代理
```
 unset http_proxy
 unset https_proxy
```
# 5. 参考
v2ray各种系统配置示例
- https://github.com/v2fly/v2ray-examples/blob/master/Shadowsocks-Websocket-Web-TLS/config_client.json

socks5配置参考：
- https://gist.github.com/yougg/5d2b3353fc5e197a0917aae0b3287d64