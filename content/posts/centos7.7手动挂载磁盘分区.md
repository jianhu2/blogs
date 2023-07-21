# 1. centos挂载磁盘分区
## 1.1 系统环境
- aliyun
- CentOS Linux release 7.7.1908 (Core)
    
## 1.2 目的：
- 磁盘扩容到256G，主分区(/dev/vda1)使用100G; 剩156G可扩容
    
## 1.3 限制条件：
 - 主分区(/dev/vda1)系统盘使用的是ID 83数据卷分区，主分区(/dev/vda1)默认不是lvm，不能实现无缝扩容，
 - 考虑到生产商用环境数据量大，操作风险大，这里用可分配的156G新建分区挂载到系统磁盘/data目录,而不是在主分区上直接扩容


# 2. 磁盘分区

## 2.1 查询磁盘大小
```shell
#  lsblk -l
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda             253:0    0  256G  0 disk
vda1            253:1    0  100G  0 part /
vda2            253:2    0  156G  0 part
```

## 2.2 查看所有磁盘信息（包括未挂载磁盘）
```shell
#   fdisk -l

Disk /dev/vda: 274.9 GB, 274877906944 bytes, 536870912 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000b2d99

   Device Boot      Start         End      Blocks   Id  System
/dev/vda1   *        2048   209712509   104855231   83  Linux
/dev/vda2       209713152   536870911   163578880   83  Linux

Disk /dev/mapper/test_vg-test_lv: 167.5 GB, 167503724544 bytes, 327155712 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

## 2.3 创建新的磁盘分区
### 2.3.1 进入磁盘：

```shell
fdisk /dev/vda
```
1. 选择分区号，linux基本分区和扩展分区之和不能大于4，所以在1-4直接选择，一般是从大到小按编号选：输入命令n，然后输入1。
2. 输入命令t，然后输入分区类型，输入83表示数据卷分区
3. 输入命令w，重写分区表

### 2.3.2 查看创建的分区
1. 使用```fdisk -l```查看创建的分区，有时候会看不到创建的新分区，此时使用fdisk命令看不到新建的分区信息。

2. partprobe 是一个可以修改kernel中分区表的工具，可以使kernel重新读取分区表而不用重启系统。命令：

    ``` partprobe /dev/vda```
3. 将物理硬盘分区初始化为物理卷，以便LVM使用：

    ```pvcreate /dev/vda2```
   
## 2.4 创建卷组和逻辑卷并格式化
1. 创建卷组test_vg:

    ``` vgcreate test_vg /dev/vda2```

2. 创建逻辑卷test_lv并分配磁盘空间：

    ``` lvcreate -l +156%FREE -n test_lv test_vg```

3. 查看磁盘空间使用情况：

    ```df -mh ```
4. 格式化逻辑卷：

    ```mkfs.ext4 /dev/test_vg/test_lv ```
  
## 2.5 创建目录将新的分区挂载到创建的目录
1. 创建目录data：
   
    ``` mkdir /data```
   
2. 挂载目录:
   
    ```mount /dev/test_vg/test_lv /data```

3. partprobe显示资源正忙，这种情况，需要重启服务器才行：

    ``` partprobe ```
## 2.6 设置分区在系统重启后自动挂载,在文件追加（未验证）：
```shell
 # vi /etc/fstab
  
  /dev/test_vg/test_lv  /data  ext4 default 0 0 

  ```


# 3. 重启后磁盘挂载失效重新挂载
## 3.1 查询磁盘挂载状态示例
```shell
[root@iZwz9cram8gccy39lygvdfZ ~]# lsblk
NAME                MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda                 253:0    0  256G  0 disk
|-vda1              253:1    0  100G  0 part /
`-vda2              253:2    0  156G  0 part
  `-test_vg-test_lv 252:0    0  156G  0 lvm  /data

[root@iZwz9cram8gccy39lygvdfZ ~]# vgs
  VG      #PV #LV #SN Attr   VSize   VFree
  test_vg   1   1   0 wz--n- 156.00g    0
  
[root@iZwz9cram8gccy39lygvdfZ ~]# lvscan
  ACTIVE            '/dev/test_vg/test_lv' [156.00 GiB] inherit

[root@iZwz9cram8gccy39lygvdfZ ~]# lvdisplay 
  --- Logical volume ---
  LV Path                /dev/test_vg/test_lv
  LV Name                test_lv
  VG Name                test_vg
  LV UUID                bHGWWb-CC0V-3vFB-oE3j-7lPg-fkIw-XB28oZ
  LV Write Access        read/write
  LV Creation host, time iZwz9cram8gccy39lygvdfZ, 2022-11-29 12:19:09 +0800
  LV Status              available
  # open                 1
  LV Size                156.00 GiB
  Current LE             39936
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     8192
  Block device           252:0
```

## 3.2 修改逻辑卷分组状态:
```
[root@iZwz9cram8gccy39lygvdfZ ~]# vgchange -a y test_vg
  1 logical volume(s) in volume group "test_vg" now active
```

## 3.3 命令解释：
``` 
  lsblk -l     //  查询系统磁盘分配属性
  vgs          //  查看卷组的属性
  pvdisplay    //  查看物理卷
  vgdisplay    //  查看逻辑卷
  lvdisplay    //  查看逻辑卷状态
  lvscan       //  查看存在的所有LVM逻辑卷
  vgchange -a y test_vg  // 重新激活逻辑卷分组
  mount /dev/test_vg/test_lv /data  // 重新挂载逻辑卷到指定目录
```



# 4.参考连接
- [aliyun文档-通过LVM扩容逻辑卷](https://help.aliyun.com/document_detail/131143.html)
- [aliyun文档-通过LVM创建逻辑卷-本文使用的方法](https://help.aliyun.com/document_detail/131141.html)