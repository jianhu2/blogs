# 1. 将service端口暴露到本地

比如将生成环境的redis暴露到本地6379端口
```shell
kubectl port-forward service/redis -n [namesplace] 6379:6379
```

# 2. 进入容器中
```
kubectl exec -it [pod]  -n [namesplace]  -- bash 
```


# 3. 查看日志

查看最后1行的日志
 ```
  kubectl logs -f --tail 1 [pod] -n [namesplace]
```
查看最后一分钟的所有日志
```
kubectl -n [namesplace] logs [pod] --since=1m
```
查看指定时间
```
kubectl -n -n [namesplace] logs -f [pod] --since-time="2022-10-24T02:54:03.467+01:00"
```
# 4. 查看配置：
```
kubectl get pod product-6b5c98478b-rpgr6 --namespace=product-prod -o yaml

kubectl describe pods product-6b5c98478b-rpgr6 --namespace=product-prod
```

# 5. 从pod复制文件到宿主机
```shell
kubectl cp redis-test/redis-0:/data/* .
```