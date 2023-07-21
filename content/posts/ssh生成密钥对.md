# 1. ssh密钥对
1. ssh key的类型有四种，分别是dsa、rsa、 ecdsa、ed25519。
2. 根据数学特性，这四种类型又可以分为两大类，dsa/rsa是一类，ecdsa/ed25519是一类，后者算法更先进。
3. dsa因为安全问题，已不再使用了。
4. ecdsa因为政治原因和技术原因，也不推荐使用。
5. rsa是目前兼容性最好的，应用最广泛的key类型，在用ssh-keygen工具生成key的时候，默认使用的也是这种类型。不过在生成key时，如果指定的key size太小的话，也是有安全问题的，推荐key size是3072或更大。
6. ed25519是目前最安全、加解密速度最快的key类型，由于其数学特性，它的key的长度比rsa小很多，优先推荐使用。它目前唯一的问题就是兼容性，即在旧版本的ssh工具集中可能无法使用。不过据我目前测试，还没有发现此类问题

# 2. ed25519  生成密钥对
``` ssh-keygen -t ed25519 -C "your_email@example.com" ```
* 参数解释：
    - -t： 指定使用的数字签名算法；
    - -C: 注释，随便填；
    - -f: 指定文件输出位置，可选默认为 ~/.ssh/

# 3. 验证ssh密钥对
添加公钥：
   - [Gitee公钥管理页面](https://gitee.com/profile/sshkeys)
   - [GitHub公钥管理页面](https://github.com/settings/keys)

验证命令，前提条件: 已经添加了公钥
```shell
ssh -T git@github.com   # github
ssh -T git@gitee.com    # gitee
```

# 4. 总结
``` 优先选择ed25519，否则选择rsa ```

# 5. 参考连接
- [无名之辈](https://www.cnblogs.com/librarookie/p/15389876.html)
- [ssh 密钥对解释](https://goteleport.com/blog/comparing-ssh-keys/)