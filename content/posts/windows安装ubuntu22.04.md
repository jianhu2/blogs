# 1.安装前准备
 - U盘>=8G，干净的U盘，因为在安装过程中会清除U盘数据;
 - Windows 7 或更高版本 (32/64 位均可)。
U盘安装引导依赖2选1,建议选Rufus：
 - [U盘引导安装依赖uboot](https://www.balena.io/etcher)
        - https://github.com/balena-io/etcher/releases/download/v1.18.4/balenaEtcher-Setup-1.18.4.exe
 - [U盘引导依赖-Rufus](https://github.com/pbatard/rufus/releases/download/v3.21/rufus-3.21.exe)   

下载ubuntu镜像选择对应的系统架构版本，建议选择官方，如果下载速度慢则选择aliyun：
-  [官方下载ubuntu22.04桌面版本](https://ubuntu.com/download/desktop/thank-you?version=22.04.2&architecture=amd64)
-  [阿里云镜像源ubuntu22.04桌面版本](https://mirrors.aliyun.com/ubuntu-releases/22.04/ubuntu-22.04.2-desktop-amd64.iso?spm=a2c6h.25603864.0.0.595f45f8lUUhYO)
-  [ubuntu-arm架构镜像源](https://cdimage.ubuntu.com/releases/)
# 2.U盘制作安装引导
 1. 将下载好的rufus和ubuntu22.04镜像放到U盘中
 2. 执行rufus二进制文件，按步骤执行：
     - 选择对应的U盘位置
     - 选择ubuntu镜像文件并选择打开
     - 选择START执行写入U盘，可能需要额外的资源来写入ISO，弹窗选择yes；在执行中可能遇到一些警告说会清空U盘，选择OK;
     - 安装引导过程总共需要约10分钟,安装完成后状态栏为READY，此时选择CLOSE,安装完成;
    
# 3. 安装ubuntu

U盘制作好安装引导后在目标机器上执行：
1. 重启电脑，在启动过程中按F12或者F10或者F2(根据电脑品牌选择不同)进入boot菜单，在菜单中选择USB
2. boot菜单中选择语言，continue进入下一步
3. 安装ubuntu步骤：选择normal installation；如果电脑给的配置很低，就选择minimal installation；
4. 配置安装：install type配置来选择是否将ubuntu作为您唯一的操作系统(此选择会删除windows系统并清除磁盘);如果当前有windows系统则可以选择双系统共同安装;
5. 存储卷LVM选择安全加密，并设置密码 用于恢复数据;密码记录下来保存在其它地方;
6. 创建你的登录账号密码和计算机名字，continue继续
7. 等待进度条，100%完成安装，并选择重启

# 参考链接
- [Install Ubuntu desktop](https://ubuntu.com/tutorials/install-ubuntu-desktop#2-download-an-ubuntu-image)
- [bootable引导](https://ubuntu.com/tutorials/create-a-usb-stick-on-windows#2-requirements)