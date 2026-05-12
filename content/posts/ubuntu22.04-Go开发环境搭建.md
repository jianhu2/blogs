---
title: "ubuntu 22.04 安装go"
subtitle: ""
date: 2024-04-21T16:19:04+08:00
lastmod: "2024-04-21"
draft: false
tags: ["linux", "dev-env"]
hideFromHomePage: false
---


# ubuntu 22.04 安装go(适用ubuntu20以上版本) 


##  环境准备
 ```
  apt update && apt-get upgrade -y
```
## 环境安装
mkdir ~/go

cd ~/go

wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz

tar -C /usr/local go1.22.2.linux-amd64.tar.gz


## 设置环境变量

Go代码必须放在工作空间中，实际上就是一个目录，且必须包含src、pkg、bin三个子目录。它们的用途如下：

- bin：包含编译后的可执行命令
- pkg：包含包对象
- src：包含Go的源文件，它们被组织成包

因此首先创建go语言的工作空间：
```
$  mkdir $HOME/gowork
```

在配置文件中添加环境变量

```
$ vim /etc/profile
```


加入以下内容：
```

export GOROOT=/usr/local/go
export GOPATH=$HOME/gowork
export GOBIN=$GOPATH/bin
export PATH=$GOPATH:$GOBIN:$GOROOT/bin:$PATH
export GONOSUMDB="github.com"
export GONOPROXY="github.com"
export GOPROXY=https://goproxy.cn,direct
export GOPRIVATE="github.com"

```

设置使用git方式拉取私人仓库
```
 git config --global url."git@github.com:".insteadOf "https://github.com/"
```


使配置文件生效
```
$ source /etc/profile
```

安装完成后查看go版本以确认：

```
$ go version
```

之后执行`go env`来检查环境变量是否配置成功：

```sh
GO111MODULE='on'
GOARCH='amd64'
GOBIN=''
GOCACHE='/tmp/gocache'
GOENV='/root/.config/go/env'
GOEXE=''
GOEXPERIMENT=''
GOFLAGS=''
GOHOSTARCH='amd64'
GOHOSTOS='linux'
GOINSECURE=''
GOMODCACHE='/home/go/path/pkg/mod'
GONOPROXY='github.com'
GONOSUMDB='github.com'
GOOS='linux'
GOPATH='/home/go/path'
GOPRIVATE='github.com'
GOPROXY='https://goproxy.cn,direct'
GOROOT='/home/go/root/go'
GOSUMDB='sum.golang.org'
GOTMPDIR=''
GOTOOLCHAIN='auto'
GOTOOLDIR='/home/go/root/go/pkg/tool/linux_amd64'
GOVCS=''
GOVERSION='go1.22.2'
GCCGO='gccgo'
GOAMD64='v1'
AR='ar'
CC='gcc'
CXX='g++'
CGO_ENABLED='1'
GOMOD='/dev/null'
GOWORK=''
CGO_CFLAGS='-O2 -g'
CGO_CPPFLAGS=''
CGO_CXXFLAGS='-O2 -g'
CGO_FFLAGS='-O2 -g'
CGO_LDFLAGS='-O2 -g'
PKG_CONFIG='pkg-config'
GOGCCFLAGS='-fPIC -m64 -pthread -Wl,--no-gc-sections -fmessage-length=0 -ffile-prefix-map=/tmp/go-build2638198603=/tmp/go-build -gno-record-gcc-switches'
```


## 环境测试

首先在工作空间中创建源代码目录：

```
$ cd $HOME/gowork
```

然后在该目录下创建hello.go文件

```
$ vim hello.go
```

输入以下程序：

```
package main

import "fmt"

func main() {
    fmt.Printf("hello, world\n")
}
```

然后用`go run`运行

```
$ go run hello.go
```

输出`hello, world`，运行成功。

参考：
- https://go.dev/dl/


