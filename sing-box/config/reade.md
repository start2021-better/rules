在安装了singbox的openwrt环境下，如何把json规则文件转成srs(二进制)文件:
sing-box rule-set compile myproxy-mini.json -o myproxy-mini.srs
反向操作：
sing-box rule-set decompile myproxy-mini.srs -o myproxy-mini.json
