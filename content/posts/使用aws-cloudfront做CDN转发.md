# CND转发到v2ray服务
环境:
 - 域名一个
 - aws cloudfront服务


## 数据转发流程
 - A.example.com->cloudfront->B.example.com->ip.ec2.port


## 注意事项
### 踩过的坑：
1. v2ray-plugin报错 ``` http: TLS handshake error from 64.252.173.97:23912: read tcp 172.21.0.3:443->64.252.173.97:23912: read: connection reset by peer```
    - 原因为2层(EC2,cloudfront)TLS证书不一致; 第一个想法就是将两个证书整成一致，然后cloudfront就上传"Let's Encrypt自签的证书，发现使用自上传的证书cloudfront根本不转发数据了;得出一个结论:cloudfront必须使用它请求生成的tls证书；
    - 解决方案：A.example.com->cloudfront->ip.ec2.port转发流程修改为A.example.com->cloudfront->B.example.com->ip.ec2.port
2. v2ray-plugin报错```not found in 'Sec-Websocket-Version' header ```   
  ```shell
cloudfront ws一直是v2ray.com/core/transport/internet/websocket: failed to convert to WebSocket connection > websocket: unsupported version: 13 not found in 'Sec-Websocket-Version' header
```
   - 原因是cloudfront没有配置转发HTTP请求头,CloudFront 预设并不会转发所有的 HTTP request headers，
    有些 request headers 在经过 CloudFront 之后就被丟掉了导致 v2ray 无法识别到必要的数据。
     需要更改 origin request policies 為 Managed-AllViewer，這樣它才會轉發所有的 headers。
   
    - 解决方案：cloudfront设置源请求策略为```Managed-AllViewer```

3. cloudfront转发数据到源失败，解决方法是需要更改行为策略->缓存策略名称(Managed-CachingDisabled)->源请求策略名称(Managed-AllViewerExceptHostHeader)
    - 源服务器没有接收到数据,错误的提示：
        ```shell
        root@localhost ~ # curl -v  https://proxy.example.com
        * About to connect() to proxy.example.com port 443 (#0)
        *   Trying 13.225.103.85...
        * Connected to proxy.example.com (13.225.103.85) port 443 (#0)
        * Initializing NSS with certpath: sql:/etc/pki/nssdb
        *   CAfile: /etc/pki/tls/certs/ca-bundle.crt
          CApath: none
        * SSL connection using TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        * Server certificate:
        *       subject: CN=proxy.example.com
        *       start date: Apr 15 00:00:00 2023 GMT
        *       expire date: May 14 23:59:59 2024 GMT
        *       common name: proxy.example.com
        *       issuer: CN=Amazon RSA 2048 M01,O=Amazon,C=US
        > GET / HTTP/1.1
        > User-Agent: curl/7.29.0
        > Host: proxy.example.com
        > Accept: */*
        >
        < HTTP/1.1 404 Not Found
        < Content-Length: 0
        < Connection: keep-alive
        < Date: Sat, 15 Apr 2023 06:43:51 GMT
        < X-Cache: Error from cloudfront
        < Via: 1.1 69b8510b9be29c1f776639b7e7318dac.cloudfront.net (CloudFront)
        < X-Amz-Cf-Pop: HKG60-C1
        < X-Amz-Cf-Id: -Sm_h3IyQgK6sHFS28lv9leV321FbRd0UiJF5ZlqwJ2bofBw2Uqu9g==
        <
        
        ```
     - 正确的路由出现```Bad Request```提示：
        ```shell
        root@localhost ~ # curl -v   https://proxy.example.com
        * About to connect() to proxy.example.com port 443 (#0)
        *   Trying 13.225.103.32...
        * Connected to proxy.example.com (13.225.103.32) port 443 (#0)
        * Initializing NSS with certpath: sql:/etc/pki/nssdb
        *   CAfile: /etc/pki/tls/certs/ca-bundle.crt
          CApath: none
        * SSL connection using TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        * Server certificate:
        *       subject: CN=proxy.example.com
        *       start date: Apr 15 00:00:00 2023 GMT
        *       expire date: May 14 23:59:59 2024 GMT
        *       common name: proxy.example.com
        *       issuer: CN=Amazon RSA 2048 M01,O=Amazon,C=US
        > GET / HTTP/1.1
        > User-Agent: curl/7.29.0
        > Host: proxy.example.com
        > Accept: */*
        >
        < HTTP/1.1 400 Bad Request
        < Content-Type: text/plain; charset=utf-8
        < Content-Length: 12
        < Connection: keep-alive
        < Sec-Websocket-Version: 13
        < X-Content-Type-Options: nosniff
        < Date: Sat, 15 Apr 2023 06:52:06 GMT
        < X-Cache: Error from cloudfront
        < Via: 1.1 4466aaf3ba3ee7921322175dc8537b7a.cloudfront.net (CloudFront)
        < X-Amz-Cf-Pop: HKG60-C1
        < X-Amz-Cf-Id: BpS3Gy7MhRdnx6qZ28HUxaD1CyUyOfH4bN3jStHo2PLKnh0SBuRIAg==
        <
        Bad Request
        * Connection #0 to host proxy.example.com left intact
        ```

## 参考链接：
- [CloudFront配置HTTP请求头的问题](https://github.com/v2ray/discussion/issues/795)
- [docker-compose for v2ray](https://hub.docker.com/r/gists/v2ray-plugin)