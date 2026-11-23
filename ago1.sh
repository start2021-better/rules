#!/bin/bash
export LANG=en_US.UTF-8

is_sb_running() {
  if command -v pgrep >/dev/null 2>&1 && pgrep -f '[a]gsb/sing-box' >/dev/null 2>&1; then
    return 0
  fi
  find /proc/*/exe -type l 2>/dev/null | grep -E '^/proc/[0-9]+/exe$' | xargs -r readlink 2>/dev/null | grep -q 'agsb/sing-box'
}

if ! is_sb_running; then
  [ -n "${vlpt+x}" ] && vlp=yes
  [ -n "${vmpt+x}" ] && vmp=yes
  [ -n "${hypt+x}" ] && hyp=yes
  [ -n "${tupt+x}" ] && tup=yes
  [ -n "${anpt+x}" ] && anp=yes
  if [ "$vlp" != "yes" ] && [ "$vmp" != "yes" ] && [ "$hyp" != "yes" ] && [ "$tup" != "yes" ] && [ "$anp" != "yes" ]; then
    echo "注意，请在脚本前至少设置一个协议变量"
    exit 1
  fi
fi

export uuid="${uuid:-}"
export port_vl_re="${vlpt:-}"
export port_vm_ws="${vmpt:-}"
export port_hy2="${hypt:-}"
export port_tu="${tupt:-}"
export port_an="${anpt:-}"
export ym_vl_re="${reym:-}"
export argo="${argo:-}"
export ARGO_DOMAIN="${agn:-}"
export ARGO_AUTH="${agk:-}"
export ipsw="${ip:-}"

showmode() {
  echo "显示节点信息：agsb或者脚本 list"
  echo "双栈VPS显示IPv4节点配置：ip=4 agsb或者脚本 cip"
  echo "双栈VPS显示IPv6节点配置：ip=6 agsb或者脚本 cip"
  echo "卸载脚本：agsb或者脚本 del"
}

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "甬哥Github项目  ：github.com/yonggekkk"
echo "甬哥Blogger博客 ：ygkkk.blogspot.com"
echo "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
echo "ArgoSB一键无交互脚本"
echo "当前版本：25.6.5 (已修复变量引号与进程检测)"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}')
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)

case $(uname -m) in
  aarch64) cpu=arm64 ;;
  x86_64) cpu=amd64 ;;
  *) echo "目前脚本不支持$(uname -m)架构" && exit 1 ;;
esac

mkdir -p "$HOME/agsb"

warpcheck() {
  wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
  wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

ins() {
  if [ ! -e "$HOME/agsb/sing-box" ]; then
    curl -Lo "$HOME/agsb/sing-box" -# --retry 2 "https://github.com/yonggekkk/ArgoSB/releases/download/singbox/sing-box-$cpu"
    chmod +x "$HOME/agsb/sing-box"
    sbcore=$("$HOME/agsb/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
    echo "已安装Sing-box正式版内核：$sbcore"
  fi

  cat > "$HOME/agsb/sb.json" <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF

  if [ -z "$uuid" ]; then
    uuid=$("$HOME/agsb/sing-box" generate uuid)
  fi
  echo "$uuid" > "$HOME/agsb/uuid"
  echo "UUID密码：$uuid"

  command -v openssl >/dev/null 2>&1 && openssl ecparam -genkey -name prime256v1 -out "$HOME/agsb/private.key" >/dev/null 2>&1
  command -v openssl >/dev/null 2>&1 && openssl req -new -x509 -days 36500 -key "$HOME/agsb/private.key" -out "$HOME/agsb/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
  if [ ! -f "$HOME/agsb/private.key" ]; then
    curl -Lso "$HOME/agsb/private.key" https://github.com/yonggekkk/ArgoSB/releases/download/singbox/private.key
    curl -Lso "$HOME/agsb/cert.pem" https://github.com/yonggekkk/ArgoSB/releases/download/singbox/cert.pem
  fi

  if [ -n "$vlp" ]; then
    vlp=vlpt
    [ -z "$port_vl_re" ] && port_vl_re=$(shuf -i 10000-65535 -n 1)
    [ -z "$ym_vl_re" ] && ym_vl_re=www.yahoo.com
    echo "$port_vl_re" > "$HOME/agsb/port_vl_re"
    echo "$ym_vl_re" > "$HOME/agsb/ym_vl_re"
    if [ ! -e "$HOME/agsb/private_key" ]; then
      key_pair=$("$HOME/agsb/sing-box" generate reality-keypair)
      private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
      public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
      short_id=$("$HOME/agsb/sing-box" generate rand --hex 4)
      echo "$private_key" > "$HOME/agsb/private_key"
      echo "$public_key" > "$HOME/agsb/public.key"
      echo "$short_id" > "$HOME/agsb/short_id"
    fi
    private_key=$(< "$HOME/agsb/private_key")
    public_key=$(< "$HOME/agsb/public.key")
    short_id=$(< "$HOME/agsb/short_id")
    echo "Vless-reality端口：$port_vl_re"
    echo "Reality域名：$ym_vl_re"
    cat >> "$HOME/agsb/sb.json" <<EOF
    {
      "type": "vless",
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
EOF
  else
    vlp=vlptargo
  fi

  if [ -n "$vmp" ]; then
    vmp=vmpt
    [ -z "$port_vm_ws" ] && port_vm_ws=$(shuf -i 10000-65535 -n 1)
    echo "$port_vm_ws" > "$HOME/agsb/port_vm_ws"
    echo "Vmess-ws端口：$port_vm_ws"
    cat >> "$HOME/agsb/sb.json" <<EOF
    {
      "type": "vmess",
      "tag": "vmess-sb",
      "listen": "::",
      "listen_port": ${port_vm_ws},
      "users": [
        {
          "uuid": "${uuid}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "${uuid}-vm",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "tls": {
        "enabled": false,
        "server_name": "www.bing.com",
        "certificate_path": "$HOME/agsb/cert.pem",
        "key_path": "$HOME/agsb/private.key"
      }
    },
EOF
  else
    vmp=vmptargo
  fi

  if [ -n "$hyp" ]; then
    hyp=hypt
    [ -z "$port_hy2" ] && port_hy2=$(shuf -i 10000-65535 -n 1)
    echo "$port_hy2" > "$HOME/agsb/port_hy2"
    echo "Hysteria-2端口：$port_hy2"
    cat >> "$HOME/agsb/sb.json" <<EOF
    {
      "type": "hysteria2",
      "tag": "hy2-sb",
      "listen": "::",
      "listen_port": ${port_hy2},
      "users": [
        {
          "password": "${uuid}"
        }
      ],
      "ignore_client_bandwidth": false,
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "$HOME/agsb/cert.pem",
        "key_path": "$HOME/agsb/private.key"
      }
    },
EOF
  else
    hyp=hyptargo
  fi

  if [ -n "$tup" ]; then
    tup=tupt
    [ -z "$port_tu" ] && port_tu=$(shuf -i 10000-65535 -n 1)
    echo "$port_tu" > "$HOME/agsb/port_tu"
    echo "Tuic-v5端口：$port_tu"
    cat >> "$HOME/agsb/sb.json" <<EOF
    {
      "type": "tuic",
      "tag": "tuic5-sb",
      "listen": "::",
      "listen_port": ${port_tu},
      "users": [
        {
          "uuid": "${uuid}",
          "password": "${uuid}"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "$HOME/agsb/cert.pem",
        "key_path": "$HOME/agsb/private.key"
      }
    },
EOF
  else
    tup=tuptargo
  fi

  if [ -n "$anp" ]; then
    anp=anpt
    [ -z "$port_an" ] && port_an=$(shuf -i 10000-65535 -n 1)
    echo "$port_an" > "$HOME/agsb/port_an"
    echo "Anytls端口：$port_an"
    cat >> "$HOME/agsb/sb.json" <<EOF
    {
      "type": "anytls",
      "tag": "anytls-sb",
      "listen": "::",
      "listen_port": ${port_an},
      "users": [
        {
          "password": "${uuid}"
        }
      ],
      "padding_scheme": [],
      "tls": {
        "enabled": true,
        "certificate_path": "$HOME/agsb/cert.pem",
        "key_path": "$HOME/agsb/private.key"
      }
    },
EOF
  else
    anp=anptargo
  fi

  sed -i '${s/,\s*$//}' "$HOME/agsb/sb.json"
  cat >> "$HOME/agsb/sb.json" <<EOF
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

  if ! "$HOME/agsb/sing-box" check -c "$HOME/agsb/sb.json" >/dev/null 2>&1; then
    echo "sing-box 配置校验失败，详细信息如下："
    "$HOME/agsb/sing-box" check -c "$HOME/agsb/sb.json"
    exit 1
  fi

  nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >"$HOME/agsb/sb.log" 2>&1 &
  sleep 2

  if [[ -n "$argo" ]]; then
    if [ ! -e "$HOME/agsb/cloudflared" ]; then
      argocore=$(curl -Ls https://data.jsdelivr.net/v1/package/gh/cloudflare/cloudflared | grep -Eo '"[0-9.]+",' | sed -n 1p | tr -d '",')
      echo "下载cloudflared-argo最新正式版内核：$argocore"
      curl -Lo "$HOME/agsb/cloudflared" -# --retry 2 "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
      chmod +x "$HOME/agsb/cloudflared"
    fi
    if [[ -n "${ARGO_DOMAIN}" && -n "${ARGO_AUTH}" ]]; then
      name='固定'
      nohup "$HOME/agsb/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${ARGO_AUTH}" >/dev/null 2>&1 &
      echo "${ARGO_DOMAIN}" > "$HOME/agsb/sbargoym.log"
      echo "${ARGO_AUTH}" > "$HOME/agsb/sbargotoken.log"
    else
      name='临时'
      nohup "$HOME/agsb/cloudflared" tunnel --url "http://localhost:${port_vm_ws}" --edge-ip-version auto --no-autoupdate --protocol http2 > "$HOME/agsb/argo.log" 2>&1 &
    fi
    echo "申请Argo${name}隧道中……请稍等"
    sleep 8
    if [[ -n "${ARGO_DOMAIN}" && -n "${ARGO_AUTH}" ]]; then
      argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null)
    else
      argodomain=$(grep -a trycloudflare.com "$HOME/agsb/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
    fi
    if [[ -n "${argodomain}" ]]; then
      echo "Argo${name}隧道申请成功，域名为：$argodomain"
    else
      echo "Argo${name}隧道申请失败，请稍后再试"
    fi
  fi

  if is_sb_running; then
    [ -f ~/.bashrc ] || touch ~/.bashrc
    sed -i '/yonggekkk/d' ~/.bashrc
    echo "if ! pgrep -f '[a]gsb/sing-box' >/dev/null 2>&1; then export ip=\"${ipsw}\" argo=\"${argo}\" uuid=\"${uuid}\" $vlp=\"${port_vl_re}\" $vmp=\"${port_vm_ws}\" $hyp=\"${port_hy2}\" $tup=\"${port_tu}\" reym=\"${ym_vl_re}\" agn=\"${ARGO_DOMAIN}\" agk=\"${ARGO_AUTH}\"; bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh); fi" >> ~/.bashrc
    COMMAND="agsb"
    SCRIPT_PATH="$HOME/bin/$COMMAND"
    mkdir -p "$HOME/bin"
    curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh > "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    grep -qxF 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo 'source ~/.bashrc' >> ~/.bash_profile
    source ~/.bashrc

    crontab -l > /tmp/crontab.tmp 2>/dev/null
    sed -i '/agsb\/sing-box/d' /tmp/crontab.tmp
    echo '@reboot /bin/bash -c "nohup $HOME/agsb/sing-box run -c $HOME/agsb/sb.json >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
    sed -i '/agsb\/cloudflared/d' /tmp/crontab.tmp
    if [[ -n "$argo" ]]; then
      if [[ -n "${ARGO_DOMAIN}" && -n "${ARGO_AUTH}" ]]; then
        echo '@reboot /bin/bash -c "nohup $HOME/agsb/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $(cat $HOME/agsb/sbargotoken.log 2>/dev/null) >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
      else
        echo '@reboot /bin/bash -c "nohup $HOME/agsb/cloudflared tunnel --url http://localhost:$(grep -A2 vmess-sb $HOME/agsb/sb.json | tail -1 | tr -cd 0-9) --edge-ip-version auto --no-autoupdate --protocol http2 > $HOME/agsb/argo.log 2>&1 &"' >> /tmp/crontab.tmp
      fi
    fi
    crontab /tmp/crontab.tmp 2>/dev/null
    rm -f /tmp/crontab.tmp
    echo "ArgoSB脚本进程启动成功，安装完毕" && sleep 2
  else
    echo "ArgoSB脚本进程未启动，安装失败，日志如下："
    cat "$HOME/agsb/sb.log" 2>/dev/null
    exit 1
  fi
}

cip() {
  ipbest() {
    serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
    if [[ "$serip" =~ : ]]; then
      server_ip="[$serip]"
    else
      server_ip="$serip"
    fi
    echo "$server_ip" > "$HOME/agsb/server_ip.log"
  }

  ipchange() {
    v4=$(curl -s4m5 icanhazip.com -k)
    v6=$(curl -s6m5 icanhazip.com -k)
    if [[ -z "$v4" ]]; then
      vps_ipv4='无IPV4'
      vps_ipv6="$v6"
    elif [[ -n "$v4" && -n "$v6" ]]; then
      vps_ipv4="$v4"
      vps_ipv6="$v6"
    else
      vps_ipv4="$v4"
      vps_ipv6='无IPV6'
    fi
    echo "本地IPV4地址：$vps_ipv4"
    echo "本地IPV6地址：$vps_ipv6"
    if [ "$ipsw" == "4" ]; then
      if [ -z "$v4" ]; then ipbest; else server_ip="$v4"; echo "$server_ip" > "$HOME/agsb/server_ip.log"; fi
    elif [ "$ipsw" == "6" ]; then
      if [ -z "$v6" ]; then ipbest; else server_ip="[$v6]"; echo "$server_ip" > "$HOME/agsb/server_ip.log"; fi
    else
      ipbest
    fi
  }

  warpcheck
  if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
    ipchange
  else
    systemctl stop wg-quick@wgcf >/dev/null 2>&1
    kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
    ipchange
    systemctl start wg-quick@wgcf >/dev/null 2>&1
    systemctl restart warp-go >/dev/null 2>&1
    systemctl enable warp-go >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
  fi

  rm -rf "$HOME/agsb/jh.txt"
  uuid=$(< "$HOME/agsb/uuid")
  server_ip=$(< "$HOME/agsb/server_ip.log")

  echo "---------------------------------------------------------"
  echo "---------------------------------------------------------"
  echo "ArgoSB脚本输出节点配置如下："
  echo

  if [ -f "$HOME/agsb/port_vl_re" ]; then
    echo "【 vless-reality-vision 】节点信息如下："
    port_vl_re=$(< "$HOME/agsb/port_vl_re")
    ym_vl_re=$(< "$HOME/agsb/ym_vl_re")
    public_key=$(< "$HOME/agsb/public.key")
    short_id=$(< "$HOME/agsb/short_id")
    vl_link="vless://$uuid@$server_ip:$port_vl_re?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
    echo "$vl_link" >> "$HOME/agsb/jh.txt"
    echo "$vl_link"
    echo
  fi

  if [ -f "$HOME/agsb/port_vm_ws" ]; then
    echo "【 vmess-ws 】节点信息如下："
    port_vm_ws=$(< "$HOME/agsb/port_vm_ws")
    vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vm-ws-$hostname\", \"add\": \"$server_ip\", \"port\": \"$port_vm_ws\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"www.bing.com\", \"path\": \"/$uuid-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
    echo "$vm_link" >> "$HOME/agsb/jh.txt"
    echo "$vm_link"
    echo
  fi

  if [ -f "$HOME/agsb/port_hy2" ]; then
    echo "【 Hysteria2 】节点信息如下："
    port_hy2=$(< "$HOME/agsb/port_hy2")
    hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&sni=www.bing.com#hy2-$hostname"
    echo "$hy2_link" >> "$HOME/agsb/jh.txt"
    echo "$hy2_link"
    echo
  fi

  if [ -f "$HOME/agsb/port_tu" ]; then
    echo "【 Tuic 】节点信息如下："
    port_tu=$(< "$HOME/agsb/port_tu")
    tuic5_link="tuic://$uuid:$uuid@$server_ip:$port_tu?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=www.bing.com&allow_insecure=1#tu5-$hostname"
    echo "$tuic5_link" >> "$HOME/agsb/jh.txt"
    echo "$tuic5_link"
    echo
  fi

  argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null)
  [[ -z "$argodomain" ]] && argodomain=$(grep -a trycloudflare.com "$HOME/agsb/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')

  if [[ -n "$argodomain" ]]; then
    for pair in "443:104.16.0.0:tls" "8443:104.17.0.0:tls" "2053:104.18.0.0:tls" "2083:104.19.0.0:tls" "2087:104.20.0.0:tls" "2096:[2606:4700::0]:tls" "80:104.21.0.0:" "8080:104.22.0.0:" "8880:104.24.0.0:" "2052:104.25.0.0:" "2082:104.26.0.0:" "2086:104.27.0.0:" "2095:[2400:cb00:2049::0]:"; do
      p_port="${pair%%:*}"
      rest="${pair#*:}"
      p_add="${rest%%:*}"
      p_tls="${rest#*:}"
      ps_name=$([ "$p_tls" = "tls" ] && echo "vmess-ws-tls-argo-$hostname-$p_port" || echo "vmess-ws-argo-$hostname-$p_port")
      link_item="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$ps_name\", \"add\": \"$p_add\", \"port\": \"$p_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm?ed=2048\", \"tls\": \"$p_tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
      echo "$link_item" >> "$HOME/agsb/jh.txt"
      [ "$p_port" = "443" ] && vmatls_link1="$link_item"
      [ "$p_port" = "80" ] && vma_link7="$link_item"
    done
    sbtk=$(cat "$HOME/agsb/sbargotoken.log" 2>/dev/null)
    [ -n "$sbtk" ] && nametn="当前Argo固定隧道token：$sbtk"
    argoshow="Vmess主协议端口(Argo固定隧道端口)：$port_vm_ws\n当前Argo${name}域名：$argodomain\n${nametn}\n1、443端口的vmess-ws-tls-argo节点\n$vmatls_link1\n\n2、80端口的vmess-ws-argo节点\n$vma_link7\n"
  fi

  echo "---------------------------------------------------------"
  echo -e "$argoshow"
  echo "---------------------------------------------------------"
  echo "聚合节点信息，请查看$HOME/agsb/jh.txt文件或者运行cat $HOME/agsb/jh.txt进行复制"
  echo "---------------------------------------------------------"
  echo "相关快捷方式如下：(首次重连SSH后，agsb快捷方式生效)"
  showmode
  echo "---------------------------------------------------------"
  echo
}

if [[ "$1" == "del" ]]; then
  for P in /proc/[0-9]*; do
    if [ -L "$P/exe" ]; then
      TARGET=$(readlink -f "$P/exe" 2>/dev/null)
      if [[ "$TARGET" == *"/agsb/c"* || "$TARGET" == *"/agsb/s"* ]]; then
        PID=$(basename "$P")
        kill "$PID" 2>/dev/null && echo "Killed $PID ($TARGET)" || echo "Could not kill $PID ($TARGET)"
      fi
    fi
  done
  kill -15 $(pgrep -f '[a]gsb/s' 2>/dev/null)$(pgrep -f '[a]gsb/c' 2>/dev/null) >/dev/null 2>&1
  sed -i '/yonggekkk/d' ~/.bashrc
  sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
  source ~/.bashrc
  crontab -l > /tmp/crontab.tmp 2>/dev/null
  sed -i '/agsb\/sing-box/d' /tmp/crontab.tmp
  sed -i '/agsb\/cloudflared/d' /tmp/crontab.tmp
  crontab /tmp/crontab.tmp 2>/dev/null
  rm -f /tmp/crontab.tmp
  rm -rf "$HOME/agsb" "$HOME/bin/agsb"

  kill -15 $(cat /etc/s-box-ag/sbargopid.log 2>/dev/null) >/dev/null 2>&1
  kill -15 $(cat /etc/s-box-ag/sbpid.log 2>/dev/null) >/dev/null 2>&1
  kill -15 $(cat nixag/sbargopid.log 2>/dev/null) >/dev/null 2>&1
  kill -15 $(cat nixag/sbpid.log 2>/dev/null) >/dev/null 2>&1
  crontab -l > /tmp/crontab.tmp 2>/dev/null
  sed -i '/sbargopid/d' /tmp/crontab.tmp
  sed -i '/sbpid/d' /tmp/crontab.tmp
  crontab /tmp/crontab.tmp 2>/dev/null
  rm -f /tmp/crontab.tmp
  rm -rf /etc/s-box-ag /usr/bin/agsb
  sed -i '/yonggekkk/d' ~/.bashrc
  source ~/.bashrc
  rm -rf nixag
  echo "卸载完成"
  exit 0
elif [[ "$1" == "list" ]]; then
  cip
  exit 0
elif [[ "$1" == "cip" ]]; then
  cip && sleep 2
  echo "配置切换完成"
  exit 0
fi

if ! is_sb_running; then
  for P in /proc/[0-9]*; do
    if [ -L "$P/exe" ]; then
      TARGET=$(readlink -f "$P/exe" 2>/dev/null)
      if [[ "$TARGET" == *"/agsb/c"* || "$TARGET" == *"/agsb/s"* ]]; then
        PID=$(basename "$P")
        kill "$PID" 2>/dev/null && echo "Killed $PID ($TARGET)" || echo "Could not kill $PID ($TARGET)"
      fi
    fi
  done
  kill -15 $(pgrep -f '[a]gsb/s' 2>/dev/null)$(pgrep -f '[a]gsb/c' 2>/dev/null) >/dev/null 2>&1

  v4orv6() {
    if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
      echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
    fi
  }

  warpcheck
  if [[ ! $wgcfv4 =~ on|plus && !$wgcfv6 =~ on|plus ]]; then
    v4orv6
  else
    systemctl stop wg-quick@wgcf >/dev/null 2>&1
    kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
    v4orv6
    systemctl start wg-quick@wgcf >/dev/null 2>&1
    systemctl restart warp-go >/dev/null 2>&1
    systemctl enable warp-go >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
  fi

  echo "VPS系统：$op"
  echo "CPU架构：$cpu"
  echo "ArgoSB脚本未安装，开始安装…………" && sleep 2
  setenforce 0 >/dev/null 2>&1
  iptables -P INPUT ACCEPT >/dev/null 2>&1
  iptables -P FORWARD ACCEPT >/dev/null 2>&1
  iptables -P OUTPUT ACCEPT >/dev/null 2>&1
  iptables -F >/dev/null 2>&1
  netfilter-persistent save >/dev/null 2>&1
  ins
  cip
  echo
else
  echo "ArgoSB脚本已安装"
  echo "相关快捷方式如下："
  showmode
  exit 0
fi
