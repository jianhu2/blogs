---
title: "ubuntu2404手动安装docker"
subtitle: ""
date: 2025-03-18T11:19:04+08:00
lastmod: "2025-03-18"
draft: false
tags: ["linux"]
hideFromHomePage: false
---

# ubuntu手动安装docker.md

Ubuntu 24.04.1 LTS 安装docekr-compose docker; 非snap 安装.

## 查看系统版本：

```
# lsb_release -a


No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.1 LTS
Release:        24.04
Codename:       noble

```

## 一 安装前准备

强制删除snap安装的docekr，如果没有使用snap安装过docker请跳过。

- sudo snap remove --purge docker

## 二 安装步骤：

1. ```sudo apt-get update```
2. ```
   sudo apt-get install \
   apt-transport-https \
   ca-certificates \
   curl \
   gnupg-agent \
   software-properties-common
   ```
3. ``` curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -```
4. ``` sudo apt-key fingerprint 0EBFCD88```
5. ```
   sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable" 
   ```
6. ``` sudo apt-get update ```
7. ``` apt-cache madison docker-ce```
8. 安装指定docker版本：
   sudo apt-get install docker-ce=版本 docker-ce-cli=版本 containerd.io 示例如下：
    - ``` sudo apt-get install docker-ce=5:28.0.1-1~ubuntu.22.04~jammy docker-ce-cli=5:28.0.1-1~ubuntu.22.04~jammy containerd.io ```
9. ``` docker --version```
   10 ``` docker-compose --version```

10. 安装docker-compose:

- ```sudo curl -L "https://github.com/docker/compose/releases/download/v2.33.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose```

## 三 配置镜像源：

```
sudo tee /etc/docker/daemon.json <<-'EOF'
{

	"log-driver": "json-file",
	"log-opts": {
		"max-size": "512m",
		"max-file": "3"
	} ,

    "registry-mirrors": [
    	"https://docker-0.unsee.tech",
        "https://docker-cf.registry.cyou",
        "https://docker.1panel.live"
    ]
}
EOF
```

## 四 参考文档

### ubuntu安装docker：

- https://blog.csdn.net/qq_27348837/article/details/105699475

### 配置镜像源参考：

- https://www.coderjia.cn/archives/dba3f94c-a021-468a-8ac6-e840f85867ea
