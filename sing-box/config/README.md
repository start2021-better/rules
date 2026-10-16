## 如何把json规则文件转成srs(二进制)文件？

系统环境：安装了singbox的openwrt终端即可操作

```shell
# 执行命令
sing-box rule-set compile myproxy-mini.json -o myproxy-mini.srs
```

## srs(二进制)文件转成普通json文件


```shell
# 执行命令
sing-box rule-set decompile myproxy-mini.srs -o myproxy-mini.json
```
