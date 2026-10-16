## 如何把json规则文件转成srs(二进制)文件
# 环境
安装了singbox的openwrt系统环境

命令

sing-box rule-set compile myproxy-mini.json -o myproxy-mini.srs

反向命令

sing-box rule-set decompile myproxy-mini.srs -o myproxy-mini.json
