---
title: "gcc windows环境安装(目前13.2版本)"
subtitle: ""
date: 2023-11-02T10:19:04+08:00
lastmod: "2023-11-03"
draft: false
tags: ["开发环境"]
hideFromHomePage: false
---

# 文章目录
```text
一、简介
    1. MinGW 和 MinGW-W64 区别和联系  
二、下载
    1. 从 sourceforge.net 下载
    2. 从 github 下载
    3. 从 镜像站点 下载
三、安装与配置
    1. 在线安装
    2. 离线安装
    3. 环境配置
四、总结
```


# 一、简介
1. MinGW 和 MinGW-W64 区别和联系
   MinGW和MinGW-W64都是用于Windows平台的轻量级GNU工具链，用于开发和编译C和C++程序。

MinGW（Minimalist GNU for Windows）是一个32位的GNU工具链，它提供了一套基于GNU的开发环境，包括GCC编译器和一些GNU库，可以用来编译Windows下的C和C++程序。但MinGW只支持32位程序的编译。

MinGW-W64是一个64位的GNU工具链，是MinGW的升级版，原本它是MinGW的分支，后来成为独立发展的项目，它支持同时编译32位和64位程序。它包括了一系列的GNU库和工具，例如GCC、Binutils、GDB等，还支持一些实用工具和库，如OpenMP、MPI等。


总的来说，MinGW-W64可以看作是MinGW的升级版，它支持更多的编译选项和更多的库，可以编译出更加高效和安全的程序。

另外，MinGW-W64原本是从MinGW项目fork出来的独立的项目。MinGW 早已停止更新，内置的GCC最高版本为4.8.1，而MinGW-W64目前仍在维护，它也是GCC官网所推荐的。


# 二、下载
MinGW-w64 源码地址：
 - https://github.com/mingw-w64/mingw-w64

官方没在任何地方提供二进制安装程序。
哪里找MinGW-w64二进制应用程序？
下面提供几种方式：

## 1. 从 sourceforge.net 下载(不推荐)
不推荐在这里下载，因为这里提供的二进制安装程序是旧的，支持的GCC版本停留在了"MinGW-W64 GCC-8.1.0"

下载地址：
https://sourceforge.net/projects/mingw-w64/files/

## 2. 从 github 下载(推荐)
选择x86_64-13.2.0-release-win32-seh-ucrt-rt_v11-rev0.7z,下载地址：
 - https://github.com/niXman/mingw-builds-binaries/releases

## 3. 从镜像站点下载（推荐）
下载地址，选择要安装的版本：
- http://files.1f0.de/mingw/


## 4. 自己编译源码(不推荐)


## 三、安装与配置
这里介绍github.com的离线安装方式：

1. windows环境选择 `x86_64-13.2.0-release-win32-seh-ucrt-rt_v11-rev0.7z`  
   下载地址：
    - https://github.com/niXman/mingw-builds-binaries/releases
2. 配置环境变量：
    - 将下载的解压到指定目录，如我的windows环境： 把 C:/Sortware/gcc/gccV13.2/ 加入系统环境变量 Path 中去，方便我们命令行使用。

3. 重新打开命令行执行gcc -v
```text
# gcc -v
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=C:/Sortware/gcc/gccV13.2/mingw64/bin/../libexec/gcc/x86_64-w64-mingw32/13.2.0/lto-wrapper.exe
Target: x86_64-w64-mingw32
Configured with: ../../../src/gcc-13.2.0/configure --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32 --target=x86_64-w64-mingw32 --prefix=/mingw64 --with-sysroot=/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64 --enable-host-shared --disable-multilib --enable-languages=c,c++,fortran,lto --enable-libstdcxx-time=yes --enable-threads=win32 --enable-libstdcxx-threads=yes --enable-libgomp --enable-libatomic --enable-lto --enable-graphite --enable-checking=release --enable-fully-dynamic-string --enable-version-specific-runtime-libs --enable-libstdcxx-filesystem-ts=yes --disable-libssp --disable-libstdcxx-pch --disable-libstdcxx-debug --enable-bootstrap --disable-rpath --disable-win32-registry --disable-nls --disable-werror --disable-symvers --with-gnu-as --with-gnu-ld --with-arch=nocona --with-tune=core2 --with-libiconv --with-system-zlib --with-gmp=/c/buildroot/prerequisites/x86_64-w64-mingw32-static --with-mpfr=/c/buildroot/prerequisites/x86_64-w64-mingw32-static --with-mpc=/c/buildroot/prerequisites/x86_64-w64-mingw32-static --with-isl=/c/buildroot/prerequisites/x86_64-w64-mingw32-static --with-pkgversion='x86_64-win32-seh-rev0, Built by MinGW-Builds project' --with-bugurl=https://github.com/niXman/mingw-builds CFLAGS='-O2 -pipe -fno-ident -I/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64/opt/include -I/c/buildroot/prerequisites/x86_64-zlib-static/include -I/c/buildroot/prerequisites/x86_64-w64-mingw32-static/include' CXXFLAGS='-O2 -pipe -fno-ident -I/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64/opt/include -I/c/buildroot/prerequisites/x86_64-zlib-static/include -I/c/buildroot/prerequisites/x86_64-w64-mingw32-static/include' CPPFLAGS=' -I/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64/opt/include -I/c/buildroot/prerequisites/x86_64-zlib-static/include -I/c/buildroot/prerequisites/x86_64-w64-mingw32-static/include' LDFLAGS='-pipe -fno-ident -L/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64/opt/lib -L/c/buildroot/prerequisites/x86_64-zlib-static/lib -L/c/buildroot/prerequisites/x86_64-w64-mingw32-static/lib ' LD_FOR_TARGET=/c/buildroot/x86_64-1320-win32-seh-ucrt-rt_v11-rev0/mingw64/bin/ld.exe --with-boot-ldflags=' -Wl,--disable-dynamicbase -static-libstdc++ -static-libgcc'
Thread model: win32
Supported LTO compression algorithms: zlib
gcc version 13.2.0 (x86_64-win32-seh-rev0, Built by MinGW-Builds project)
```
# 四、总结
【从sourceforge.net下载】中提供的安装程序，支持的GCC 8.1.0，版本太老了，很多功能不支持，不推荐从这里下载安装；
【2. 从github下载】、【3. 从镜像网站下载】中提供的安装程序，支持的GCC版本都比较新，推荐从这里下载安装；

# 五、参考链接：
- http://lihuaxi.xjx100.cn/news/1433293.html?action=onClick