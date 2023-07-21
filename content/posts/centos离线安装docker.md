# centos 7.9安装docker

# 1.离线下载docker
```
https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz
```

# 2.离线安装docker
准备前：
## 2.0.1 关闭Selinux
首先, 执行getenforce或sestatus, 查询selinux状态, CentOS系统安装后默认为enforcing.
```
getenforce
或
sestatus
```

## 2.0.2 修改selinux配置
```shell
vim /etc/selinux/config
修改selinux配置文件
SELINUX=enforcing
修改为
SELINUX=disabled
```

## 2.0.3 重复服务器以上修改生效
```shell
reboot 
```

## 2.1 移动文件到目标服务器并执行tar命令解压，如：
```
tar -zxvf docker-20.10.9.tgz

```
## 2.2 将/home/docker目录下解压出来的所有docker文件复制到 /usr/bin/ 目录下
```
cp docker/* /usr/bin/
```
## 2.3 将docker注册为service，进入/etc/systemd/system/目录,并创建docker.service文件
```shell
cd /etc/systemd/system/
touch docker.service
```

## 2.4 编辑docker.service文件,将以下内容复制到docker.service文件中，如下
注1：以下内容中 --insecure-registry=192.168.0.15 此处改为你自己服务器ip。 或者不填写也可以;
注2：以下内容中 -graph /data/docker 是指定docker root路径
```shell
vi docker.service

[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd --selinux-enabled=false --insecure-registry=192.168.1.15
#ExecStart=/usr/bin/dockerd  --graph /data/docker -H fd:// --containerd=/run/containerd/containerd.sock

ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target

```

## 2.5 给docker.service文件添加执行权限，如下
```shell
 chmod 777 /etc/systemd/system/docker.service
```

## 2.6 设置docker日志配置

```shell
vi /etc/docker/daemon.json

{
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "512m",
		"max-file": "3"
	} 
}
```

## 2.7 重新加载配置文件，启动docker并设置开机自启动
```shell
systemctl daemon-reload
systemctl start docker
systemctl enable docker.service
```

## 2.8 如果非root用户, 安装docker, 还需要将当前用户添加到docker用户组, root用户可以跳过这一步.
```
// 添加用户组
sudo groupadd docker

sudo usermod -aG docker $USER

// 更新用户组
newgrp docker 
```
# 3. 安装docker-compse

## 3.1 下载二进制文件移动到目标服务器

```shell
curl -L https://github.com/docker/compose/releases/download/1.24.0-rc3/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
```
# 4.查看docker服务运行状态

## 4.1 查询版本

```shell
docker -v  
docker version 

docker-compose -v
docker-compose version
```

## 4.2 查询docker服务
``` 
systemctl status docker 
```


# 5. docker 配置

docker 配置路径不在路径1就在路径2
## 5.1 docker 配置路径1

```shell
  /usr/lib/systemd/system/docker.service
```


## 5.2 docker 配置路径2
```shell
/etc/systemd/system/docker.service
```

