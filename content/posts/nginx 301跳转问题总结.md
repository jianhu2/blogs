---
title: "nginx 301跳转问题总结"
subtitle: ""
date: 2023-07-25T10:19:04+08:00
lastmod: "2023-07-25"
draft: false
tags: ["network"]
hideFromHomePage: false
---

# 1.nginx 301跳转问题背景
 在使用hugo部署博客，部署方案nginx+docker,在浏览器地址使用url访问静态资源目录时，发现默认跳转到了http协议的地址。
 调出浏览器发现客户端发送的http请求收到了一个301状态码的响应，并且响应头中的Location字段便是跳转到的http协议的地址。
 ![issue](/images/nginx301issue.png)

# 2.原因分析

为啥服务端会返回301呢？首先需要弄清楚状态码的含义。HTTP协议中3xx开头的状态响应码都是表示重定向的响应。根据RFC的定义：

301 Moved Permanently

302 Found

303 See Other

307 Temporary Redirect

301是永久重定向。如果使用Nginx作为HTTP服务器，那么当用户输入一个不存在的地址之后，基本上会有两种情况：1.返回404状态码，2.返回301状态码和重定向地址。404 Not Found不做讨论，只说下301 Moved Permanently的处理过程。
首先需要明确的问题是，301重定向在什么情况下会被触发呢？

答案是：Nginx负责设置301 Moved Permanently状态码。但nginx.conf控制Nginx如何处理301 Moved Permanently状态码！ 换句话说，要不要进行页面重定向，和怎么重定向，完全是用户配置的结果！
Nginx主动设置301 Moved Permanently状态码只有一种情况，当用户在浏览器输入了一个url地址，末尾部分是一个文件目录且不以斜杠”/“结尾，比如 “www.test.com/index” 。 Nginx没有找到index这个文件，但发现了index是个目录。于是本次访问的返回状态码就会被设置成301 Moved Permanently。
浏览器与Nginx的通信过程如下所示：

![issue](/images/nginx301时序图.png)


一般情况下，我们会在nginx.conf中配置absolute_redirect ，server_name_in_redirect和port_in_redirect，以便到达个性化的重定向功能。其中absolute_redirect控制Location url的生成方式。
    
- absolute_redirect设置成on，则生成绝对路径作为Location url。
- absolute_redirect设置成off，则生成相对路径作为Location url。

只有absolute_redirect设置为on时，另外两个配置才会生效。


# 3. 解决方法
设置absolute_redirect为off，构造相对路径作为Location url，示例如下：
```
server {
    listen 80;
    absolute_redirect off;
    server_name  _;
    root /usr/share/nginx/html;


   location /index.html {
        add_header Cache-Control "no-cache, no-store";
    }


   location ~ \.(css|js|gif|jpg|jpeg|png|svg|ico)$ {
        try_files $uri =404;
    }

    location / {
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
        access_log /var/log/nginx/web.access.log;
        error_log /var/log/nginx/web.error.log;
        try_files $uri $uri/ index.html;
    }
}

```
配置后重启nginx,对于 "www.test.com/index" 的请求，Location响应头的值将等于 /index/。

# 4. 参考连接：
   - https://juejin.cn/post/7021818339651485726