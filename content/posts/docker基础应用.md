---
title: "docker基础应用"
subtitle: ""
date: 2021-03-02T16:19:04+08:00
lastmod: "2023-06-21"
draft: false
description: "指定docker数据存储路径，常用的docker命令"
image: "/images/Docker-build.png"
tags: ["docker"]
hideFromHomePage: false
---



# 1.指定docker数据存储路径
## 1.1 环境：
   - centos 7.9
   - Docker version 20.10.10, build b485636
    
## 1.2 设置docker工作目录：

1. 查看docker配置文件root目录
      ``` 
     [root@localhost ~]# cat /usr/lib/systemd/system/docker.service |grep "ExecStart"
     ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
      ```
2. 停止正在运行的docker镜像以及docker服务 
3. 查看docker实际的数据存储目录，移动源(旧)数据到新的docker root目录：
   ```sh
   docker info |grep "Docker Root Dir"
   systemctl stop docker.socket
   mv  /var/lib/docker /data
   ```
4. docker指定data存储位置
   配置注意事项
- 1：以下内容中 --insecure-registry=192.168.0.15 此处改为你自己服务器ip。 或者不填写也可以;
- 2：以下内容中 -graph /data/docker 是指定docker root路径
- 3：Docker version 23.0.0, build e92dd87 docker 23.0.0版本指定docker root路径 --data-root  /data/docker 
  
20.10.10 配置root路径 --graph：
   ```  
   vi /usr/lib/systemd/system/docker.service
   ExecStart=/usr/bin/dockerd  --graph /data/docker -H fd:// --containerd=/run/containerd/containerd.sock
   ```
23.0.0 以及以后的版本配置root路径 -data-root：
   ```  
   vi /usr/lib/systemd/system/docker.service
   ExecStart=/usr/bin/dockerd   --data-root  /data/docker -H fd:// --containerd=/run/containerd/containerd.sock
   ```  

5. 重启docker 生效
    ```
    systemctl daemon-reload
    systemctl restart docker 
    ```

# 2. 常用命令
## 2.1 查看容器网络映射端口
docker network inspect bridge
## 2.2 进入容器
docker exec -it 63021ad8716d /bin/bash

## 2.3 查看使用状态
docker stats

## 2.4 查看Docker正在运行的容器是通过什么命名启动的
docker ps -a --no-trunc
docker history minio/minio:latest --format "table {{.ID}}{{.CreatedBy}}" --no-trunc

## 2.5  查看docker 占用的空间
docker system df
docker system df -v
## 2.6 清理docker磁盘空间
docker system prune -a
sudo apt-get clean
## 2.7 批量删除镜像
* 2.7.1 批量删除无tag标签镜像
  - docker images|grep none|awk '{print $3}'|xargs docker rmi

* 2.7.2 批量删除已经退出的容器：
  - docker ps -a |grep Exited|awk '{print $1}'|xargs docker rm
*  2.7.3 强制删除所有的镜像 
  - docker rmi -f $(docker images -qa)
##  2.8 查看日志
* 2.8.1 查看指定时间日志:
 ```
docker logs -t --since="2022-11-16" d1826d2bb544
docker logs minio --since="2022-11-16" 2>&1 --until "2022-11-16T18:30" 
docker logs minio --since="2022-11-16" 2>&1 --until "2022-11-16T18:30" |grep "error"
docker logs minio --since="2022-11-16" 2>&1 --until "2022-11-16T18:30" |grep "error" -C 10 
```
* 2.8.2 查看最后10条日志
```
docker logs -f --tail 10 f7255fec27e5
docker logs -f --tail 10 f7255fec27e5 2>&1 |grep "error"
docker logs -f --tail 10 f7255fec27e5 2>&1 |grep "error" -C 10 
```

## 2.9 对已经启动的容器设置开机自启动：
docker update --restart=always 你的镜像名称

## 2.10 docker 镜像内复制文件到宿主机上

docker cp iotsquare:/etc/iotsquare/iotsquare.toml .

## 2.11  宿主机上文件复制到 docker 镜像内

docker cp iotsquare.toml iotsquare:/home

## 2.10 docker 保存镜像

docker save -o test.tar registry.cn-shenzhen.aliyuncs.com/{{name}}/{object}:{version}

## 2.11 docker 加载镜像

## 2.12. **创建和运行容器**：
    - `docker run`：运行一个新的容器。
    - `docker start`：启动一个已停止的容器。
    - `docker stop`：停止一个运行中的容器。
    - `docker restart`：重启一个容器。
    - `docker exec`：在正在运行的容器中执行命令。

## 2.13 **管理容器**：
    - `docker ps`：列出正在运行的容器。
    - `docker ps -a`：列出所有容器，包括已停止的。
    - `docker rm`：删除一个或多个容器。

## 2.14. **管理镜像**：
    - `docker images`：列出本地镜像。
    - `docker pull`：从 Docker Hub 下载镜像。
    - `docker build`：构建一个镜像。
    - `docker rmi`：删除一个或多个本地镜像。

## 2.15. **容器和主机之间的拷贝**：
    - `docker cp`：在容器和主机之间拷贝文件。

## 2.16. **管理网络**：
    - `docker network ls`：列出所有网络。
    - `docker network create`：创建一个新的网络。
    - `docker network rm`：删除一个网络。

## 2.17. **管理数据卷**：
    - `docker volume ls`：列出所有数据卷。
    - `docker volume create`：创建一个新的数据卷。
    - `docker volume rm`：删除一个数据卷。

## 2.18. **查找容器和镜像**：
    - `docker search`：在 Docker Hub 上搜索镜像。

## 2.19. **暂停和恢复容器**：
    - `docker pause`：暂停一个运行中的容器。
    - `docker unpause`：恢复一个暂停的容器。


# 3. [docker镜像库](https://hub.docker.com/)
To use the access token from your Docker CLI client:

1. Run docker login -u {name}

2. At the password prompt, enter the personal access token.
   xx-xx-xx-xx


# 4. 以普通用户运行docker容器

## 4.1 root账户下添加用户：
``` useradd test
    passwd test
```

## 4.2 修改用户可以使用root权限
```shell
sudo vi /etc/sudoers
# 添加行
root    ALL=(ALL)       ALL
test    ALL=(ALL)       ALL

```

## 4.3 将用户加入docker用户组：
```shell
su test
sudo groupadd docker
sudogpasswd -a test docker
newgrp docker 
```

# 5. docker-compose 安装:
```
curl -L https://github.com/docker/compose/releases/download/1.24.0-rc3/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

# 6. docker 配置代理
### 1. 修改配置
$  systemctl edit docker.service
```
[Service]
Environment="HTTP_PROXY=http://192.168.159.132:8123"
Environment="HTTPS_PROXY=http://192.168.159.132:8123"
Environment="NO_PROXY=localhost,127.0.0.1"
```

### 2. 显示配置结果：

```systemctl show --property Environment docker.service ```

###  3. 重新启动服务
``` systemctl restart docker.service```

#  参考链接
- [Docker基础技术-陈浩](https://coolshell.cn/articles/17010.html)
- [Docker 中文指南](https://www.widuu.com/chinese_docker/userguide/dockerhub.html)