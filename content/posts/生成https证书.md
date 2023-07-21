#  生成HTTPS证书

# 1. 使用loge命令的方式生成HTTPS证书
参数说明：
1. *.domain.com 替换为你的域名，支持所有子域名
2. -- dns 是指域名在哪个云厂商，支持的云厂商有alidns/cloudflare aws;详细参考github官方文档
```
CLOUDFLARE_EMAIL="xx@gmail.com" \
CLOUDFLARE_API_KEY="xxx" \
lego --email "xx@gmail.com" --dns cloudflare --domains "*.domain.com" run
```

# 2 使用certbot的方式生成HTTPS证书

xx.domain.com 替换为你指定的子域名，只支持单个子域名
```
sudo certbot certonly --agree-tos --email xx@gmail.com --webroot -w /var/lib/letsencrypt/ -d xx.domain.com
```

# 3.检查HTTPS证书是否生效
```
cfssl-certinfo -domain xx.domain.com:443
```

# 4 参考文档：
- [使用certbot的方式生成HTTPS证书](https://github.com/certbot/certbot)
- [使用lego手动生成tls证书参数文档](https://go-acme.github.io/lego/dns/)

