# 1. centos 扩展磁盘分区

* 1.1 系统环境1
  - vmware
  -  centos 7.9

# 2.扩展步骤
## 2.1 步骤一

  关机状态下在设置->硬盘->扩展->选择硬盘大小; 我这里选择扩展到50G

## 2.2 步骤二

- 进入系统内部执行命令扩展磁盘大小，主要是创建逻辑卷(PVC)/物理卷(PV),从逻辑卷(LV)映射到物理卷(PV):
  ```shell
  df -mh   
  lsblk -l   // 查询系统磁盘挂载目录
  fdisk -l
  pvcreate /dev/sda3
  vgextend centos  /dev/sda3
  vgs          //  返回卷组的属性
  pvdisplay    //  查看物理卷
  vgdisplay    //  查看逻辑卷
  lvdisplay    //  查看逻辑卷状态
  lvextend -L +50G /dev/test_vg/test_lv  // 分配指定大小
  lvextend -l +100%FREE /dev/centos/root  // 分配100的剩余空间
  xfs_growfs /dev/mapper/centos-root      // 刷新根分区生效
  df -mh          // 查询磁盘
    ``` 
 - 系统重启更新重新挂载磁盘卷  
```shell
lvdisplay    //  查看逻辑卷状态
vgchange -a y test_vg  // 重新激活逻辑卷组
mount /dev/test_vg/test_lv /data  // 重新挂载逻辑卷到指定目录

```
    
### 2.2.1 执行扩展示例
```sh 
root@localhost ~ # df -mh
Filesystem               Size  Used Avail Use% Mounted on
devtmpfs                 969M     0  969M   0% /dev
tmpfs                    980M     0  980M   0% /dev/shm
tmpfs                    980M  9.9M  970M   2% /run
tmpfs                    980M     0  980M   0% /sys/fs/cgroup
/dev/mapper/centos-root   17G   14G  3.3G  81% /
/dev/sda1               1014M  299M  716M  30% /boot
overlay                   17G   14G  3.3G  81% /var/lib/docker/overlay2/0971f73c015ca770356f4ba4b30afeaf8a5bab897787d00fb12e976013c816b4/merged
overlay                   17G   14G  3.3G  81% /var/lib/docker/overlay2/080f5771c97382cba9de40fc04cc449d661831cb6404d1165ba5f9d94ff097a4/merged
overlay                   17G   14G  3.3G  81% /var/lib/docker/overlay2/418d6d02082ce2c868843e06cf9bbcefc8d854620a779e5d40c9e818ddc9ff8b/merged
overlay                   17G   14G  3.3G  81% /var/lib/docker/overlay2/1a3310ec1ffe14dc972c46ecc56cae627c66ac6ea22d8ec86a7ee341ab395a3a/merged
shm                       64M     0   64M   0% /var/lib/docker/containers/89721e8e469f187ee631632a86e158c752ae93b901bdc968567231797e24d6f0/mounts/shm
shm                       64M     0   64M   0% /var/lib/docker/containers/65e865a368434ff6d6ead1bd3eae5566dc3c75eeb8b747ec6bebc046a6d94d14/mounts/shm
shm                       64M     0   64M   0% /var/lib/docker/containers/2be6579cd347c2b993e85cd17289dc6205aeb0fa2e566e99893b31c66fc6ea37/mounts/shm
shm                       64M   16K   64M   1% /var/lib/docker/containers/039aef669459f804f306b710b845c090efcad0a0359cc9aa3428580dc0117b2b/mounts/shm
tmpfs                    196M     0  196M   0% /run/user/0


root@localhost ~ # fdisk -l

root@localhost ~ # pvcreate /dev/sda3
  Physical volume "/dev/sda3" successfully created.

root@localhost ~ # vgextend centos  /dev/sda3
  Volume group "centos" successfully extended

root@localhost ~ # vgs
  VG     #PV #LV #SN Attr   VSize  VFree
  centos   2   2   0 wz--n- 48.99g <30.00g
root@localhost ~ # vgdisplay
  --- Volume group ---
  VG Name               centos
  System ID
  Format                lvm2
  Metadata Areas        2
  Metadata Sequence No  4
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                2
  Open LV               2
  Max PV                0
  Cur PV                2
  Act PV                2
  VG Size               48.99 GiB
  PE Size               4.00 MiB
  Total PE              12542
  Alloc PE / Size       4863 / <19.00 GiB
  Free  PE / Size       7679 / <30.00 GiB
  VG UUID               vFfONo-DxPv-pnCQ-lPtz-3gCe-8dqz-dqFywm

root@localhost ~ # pvdisplay
  --- Physical volume ---
  PV Name               /dev/sda2
  VG Name               centos
  PV Size               <19.00 GiB / not usable 3.00 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              4863
  Free PE               0
  Allocated PE          4863
  PV UUID               tiJXzP-GDDT-o2Nb-M3sZ-LjpH-mJhD-82rx1B

  --- Physical volume ---
  PV Name               /dev/sda3
  VG Name               centos
  PV Size               30.00 GiB / not usable 4.00 MiB
  Allocatable           yes
  PE Size               4.00 MiB
  Total PE              7679
  Free PE               7679
  Allocated PE          0
  PV UUID               0tXB8b-zDVW-f0xz-7zpy-sfhc-A7dh-29te0U

root@localhost ~ # lvextend -L +29.9G /dev/mapper/centos-root
  Rounding size to boundary between physical extents: 29.90 GiB.
  Size of logical volume centos/root changed from <17.00 GiB (4351 extents) to <46.90 GiB (12006 extents).
  Logical volume centos/root successfully resized.

# resize2fs /dev/mapper/centos-root
resize2fs 1.42.9 (28-Dec-2013)
resize2fs: Bad magic number in super-block while trying to open /dev/mapper/centos-root
Couldn't find valid filesystem superblock.

root@localhost ~ # xfs_growfs /dev/mapper/centos-root
meta-data=/dev/mapper/centos-root isize=512    agcount=4, agsize=1113856 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=4455424, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal               bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 4455424 to 12294144


root@localhost ~ # df -mh
Filesystem               Size  Used Avail Use% Mounted on
devtmpfs                 969M     0  969M   0% /dev
tmpfs                    980M     0  980M   0% /dev/shm
tmpfs                    980M  9.9M  970M   2% /run
tmpfs                    980M     0  980M   0% /sys/fs/cgroup
/dev/mapper/centos-root   47G   14G   34G  30% /
/dev/sda1               1014M  299M  716M  30% /boot
overlay                   47G   14G   34G  30% /var/lib/docker/overlay2/0971f73c015ca770356f4ba4b30afeaf8a5bab897787d00fb12e976013c816b4/merged
overlay                   47G   14G   34G  30% /var/lib/docker/overlay2/080f5771c97382cba9de40fc04cc449d661831cb6404d1165ba5f9d94ff097a4/merged
overlay                   47G   14G   34G  30% /var/lib/docker/overlay2/418d6d02082ce2c868843e06cf9bbcefc8d854620a779e5d40c9e818ddc9ff8b/merged
overlay                   47G   14G   34G  30% /var/lib/docker/overlay2/1a3310ec1ffe14dc972c46ecc56cae627c66ac6ea22d8ec86a7ee341ab395a3a/merged
shm                       64M     0   64M   0% /var/lib/docker/containers/89721e8e469f187ee631632a86e158c752ae93b901bdc968567231797e24d6f0/mounts/shm
shm                       64M     0   64M   0% /var/lib/docker/containers/65e865a368434ff6d6ead1bd3eae5566dc3c75eeb8b747ec6bebc046a6d94d14/mounts/shm
shm                       64M     0   64M   0% /var/lib/docker/containers/2be6579cd347c2b993e85cd17289dc6205aeb0fa2e566e99893b31c66fc6ea37/mounts/shm
shm                       64M   16K   64M   1% /var/lib/docker/containers/039aef669459f804f306b710b845c090efcad0a0359cc9aa3428580dc0117b2b/mounts/shm
tmpfs                    196M     0  196M   0% /run/user/0

```

## 3.参考：
- https://blog.csdn.net/chengyuqiang/article/details/59491942
- https://blog.runm.top/?p=1109