#!/bin/bash
#    Setup Strong strongSwan server for Ubuntu and Debian
#
#    Copyright (C) 2014-2015 Phil Plückthun <phil@plckthn.me>
#    Based on Strongswan on Docker
#    https://github.com/philplckthun/docker-strongswan
#
#    This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
#    Unported License: http://creativecommons.org/licenses/by-sa/3.0/

if [ `id -u` -ne 0 ]
then
  echo "木有权限, 请在脚本前加上 sudo"
  exit 0
fi

#################################################################
# Variables

[ -z "$STRONGSWAN_TMP" ] && STRONGSWAN_TMP="/tmp/strongswan"
[ -z "$STRONGSWAN_VERSION" ] && STRONGSWAN_VERSION="5.5.1"
[ -z "$KEYSIZE" ] && KEYSIZE=16
#STRONGSWAN_USER
#STRONGSWAN_PASSWORD
#STRONGSWAN_PSK

if [ -z "$INTERACTIVE" ]; then
  INTERACTIVE=1
fi
[[ $INTERACTIVE = "true" ]] && INTERACTIVE=1
[[ $INTERACTIVE = "false" ]] && INTERACTIVE=0

#################################################################
# Functions

call () {
  eval "$@ > /dev/null 2>&1"
}

checkForError () {
  if [ "$?" = "1" ]
  then
    bigEcho "唉呀出错了!"
    exit 1
  fi
}

generateKey () {
  KEY=`cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c $KEYSIZE`
}

bigEcho () {
  echo ""
  echo "============================================================"
  echo "$@"
  echo "============================================================"
  echo ""
}

pacapt () {
  eval "$STRONGSWAN_TMP/pacapt $@"
}

backupCredentials () {
  if [ -f /etc/ipsec.secrets ]; then
    cp /etc/ipsec.secrets /etc/ipsec.secrets.backup
  fi

  if [ -f /etc/ppp/l2tp-secrets ]; then
    cp /etc/ppp/l2tp-secrets /etc/ppp/l2tp-secrets.backup
  fi
}

writeCredentials () {
  bigEcho "正在保存认证信息..."

  cat > /etc/ipsec.secrets <<EOF
# This file holds shared secrets or RSA private keys for authentication.
# RSA private key for this host, authenticating it to any other host
# which knows the public part.  Suitable public keys, for ipsec.conf, DNS,
# or configuration of other implementations, can be extracted conveniently
# with "ipsec showhostkey".

: PSK "$STRONGSWAN_PSK"

$STRONGSWAN_USER : EAP "$STRONGSWAN_PASSWORD"
$STRONGSWAN_USER : XAUTH "$STRONGSWAN_PASSWORD"
EOF

  cat > /etc/ppp/chap-secrets <<EOF
# This file holds secrets for L2TP authentication.
# Username  Server  Secret  Hosts
"$STRONGSWAN_USER" "*" "$STRONGSWAN_PASSWORD" "*"
EOF
}

getCredentials () {
  bigEcho "认证信息"

  if [ "$STRONGSWAN_USER" = "" ]; then
    if [ "$INTERACTIVE" = "0" ]; then
      STRONGSWAN_USER=""
    else
        echo "VPN 用户名"
      read -p "起个用户名 [vpn]: " STRONGSWAN_USER
    fi

    if [ "$STRONGSWAN_USER" = "" ]
    then
      STRONGSWAN_USER="vpn"
    fi
  fi

  #################################################################

  if [ "$STRONGSWAN_PASSWORD" = "" ]; then
    echo "VPN 密码"
    echo "你要自己设置一个还是要自动生成一个? [y|n]"
    while true; do
      if [ "$INTERACTIVE" = "0" ]; then
        echo "自动生成 VPN 密码..."
        yn="n"
      else
        read -p "" yn
      fi

      case $yn in
        [Yy]* ) echo ""; echo "设置 VPN 密码:"; read -p "" STRONGSWAN_PASSWORD; break;;
        [Nn]* ) generateKey; STRONGSWAN_PASSWORD=$KEY; break;;
        * ) echo "打 Yes 或 No [y|n].";;
      esac
    done
  fi

  #################################################################

  if [ "$STRONGSWAN_PSK" = "" ]; then
    echo "VPN PSK (预共享密钥)."
    echo "你要自己设置一个还是要自动生成一个? [y|n]"
    while true; do
      if [ $INTERACTIVE -eq 0 ]; then
        echo "自动生成 PSK (预共享密钥)..."
        yn="n"
      else
        read -p "" yn
      fi

      case $yn in
        [Yy]* ) echo ""; echo "设置 PSK (预共享密钥):"; read -p "" STRONGSWAN_PSK; break;;
        [Nn]* ) generateKey; STRONGSWAN_PSK=$KEY; break;;
        * ) echo "打 Yes 或 No [y|n].";;
      esac
    done

    echo ""
    echo "好, PSK (预共享密钥)是: '$STRONGSWAN_PSK'."
    echo ""
  fi
}

#################################################################

# phil 你在逗我, 你,,并没有在这写安装的过程呀

if [ "$INTERACTIVE" = "0" ]; then
  bigEcho "静默安装..."
else
  echo "要安装 strongSwan 啦."
  echo -n "继续嘛? [y|n] "

  while true; do
    read -p "" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit 0;;
        * ) echo "打 Yes 或 No [y|n].";;
    esac
  done
fi

#################################################################

# 看安装 curl 了没

call which curl
if [ "$?" = "1" ]; then
  bigEcho "什么系统, 连 curl 都木有. 去安装一下 curl, 比如: sudo apt install curl"
  exit 1
fi

#################################################################

# 看安装 ipsec 工具了没

call which ipsec
if [ "$?" = "0" ]; then
  echo "ipsec 安装着呢!"

  if [ "$INTERACTIVE" = "0" ]; then
    bigEcho "ipsec 没装, 静默安装呀, 那不管了"
  else
    echo -n "继续嘛? [y|n] "

    while true; do
      read -p "" yn
      case $yn in
          [Yy]* ) break;;
          [Nn]* ) exit 0;;
          * ) echo "打 Yes 或 No [y|n].";;
      esac
    done
  fi
fi

#################################################################

# 清理一下, 准备编译环境
call rm -rf $STRONGSWAN_TMP
call mkdir -p $STRONGSWAN_TMP

curl -sSL "https://github.com/icy/pacapt/raw/ng/pacapt" > $STRONGSWAN_TMP/pacapt
if [ "$?" = "1" ]; then
  bigEcho "唉呀, 下载 pacapt 出错!"
  exit 1
fi

call chmod +x $STRONGSWAN_TMP/pacapt

echo ""

#################################################################

bigEcho "先安装几个依赖..."

call pacapt -Sy --noconfirm
checkForError

call pacapt -S --noconfirm -- make g++ gcc iptables xl2tpd libssl-dev module-init-tools curl openssl-devel
checkForError

#################################################################

bigEcho "安装 StrongSwan..."

call mkdir -p $STRONGSWAN_TMP/src
curl -sSL "https://download.strongswan.org/strongswan-$STRONGSWAN_VERSION.tar.gz" | tar -zxC $STRONGSWAN_TMP/src --strip-components 1
checkForError

cd $STRONGSWAN_TMP/src
./configure --prefix=/usr --sysconfdir=/etc \
  --enable-eap-radius \
  --enable-eap-mschapv2 \
  --enable-eap-identity \
  --enable-eap-md5 \
  --enable-eap-mschapv2 \
  --enable-eap-tls \
  --enable-eap-ttls \
  --enable-eap-peap \
  --enable-eap-tnc \
  --enable-eap-dynamic \
  --enable-xauth-eap \
  --enable-openssl \
  --disable-gmp
checkForError

make
checkForError

make install
checkForError

#################################################################

bigEcho "准备配置文件..."

cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

config setup
  uniqueids=no
  charondebug="cfg 2, dmn 2, ike 2, net 0"

conn %default
  dpdaction=clear
  dpddelay=300s
  rekey=no
  left=%defaultroute
  leftfirewall=yes
  right=%any
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  auto=add

#######################################
# L2TP Connections
#######################################

conn L2TP-IKEv1-PSK
  type=transport
  keyexchange=ikev1
  authby=secret
  leftprotoport=udp/l2tp
  left=%any
  right=%any
  rekey=no
  forceencaps=yes

#######################################
# Default non L2TP Connections
#######################################

conn Non-L2TP
  leftsubnet=0.0.0.0/0
  rightsubnet=10.0.0.0/24
  rightsourceip=10.0.0.0/24

#######################################
# EAP Connections
#######################################

# This detects a supported EAP method
conn IKEv2-EAP
  also=Non-L2TP
  keyexchange=ikev2
  eap_identity=%any
  rightauth=eap-dynamic

#######################################
# PSK Connections
#######################################

conn IKEv2-PSK
  also=Non-L2TP
  keyexchange=ikev2
  authby=secret

# Cisco IPSec
conn IKEv1-PSK-XAuth
  also=Non-L2TP
  keyexchange=ikev1
  leftauth=psk
  rightauth=psk
  rightauth2=xauth

EOF

cat > /etc/strongswan.conf <<EOF
# /etc/strongswan.conf - strongSwan configuration file
# strongswan.conf - strongSwan configuration file
#
# Refer to the strongswan.conf(5) manpage for details

charon {
  load_modular = yes
  send_vendor_id = yes
  plugins {
    include strongswan.d/charon/*.conf
    attr {
      dns = 8.8.8.8, 8.8.4.4
    }
  }
}

include strongswan.d/*.conf
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
auth file = /etc/ppp/chap-secrets
debug avp = yes
debug network = yes
debug state = yes
debug tunnel = yes
[lns default]
ip range = 10.1.0.2-10.1.0.254
local ip = 10.1.0.1
require chap = yes
refuse pap = yes
require authentication = no
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
crtscts
idle 1800
mtu 1280
mru 1280
lock
lcp-echo-failure 10
lcp-echo-interval 60
connect-delay 5000
EOF

#################################################################

if [[ -f /etc/ipsec.secrets ]] || [[ -f /etc/ppp/chap-secrets ]]; then
  echo "替换旧的认证信息文件? (会先自动备份一下) [y|n]"

  while true; do
    if [ "$INTERACTIVE" = "0" ]; then
      echo "唉呀, 有旧的认证信息文件, 静默安装前需要你先手动移除他们."
      break
    fi

    read -p "" yn
    case $yn in
        [Yy]* ) backupCredentials; getCredentials; writeCredentials; break;;
        [Nn]* ) break;;
        * ) echo "打 Yes 或 No [y|n].";;
    esac
  done
else
  getCredentials
  writeCredentials
fi

#################################################################

bigEcho "应用改动..."

iptables --table nat --append POSTROUTING --jump MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
for each in /proc/sys/net/ipv4/conf/*
do
  echo 0 > $each/accept_redirects
  echo 0 > $each/send_redirects
done

#################################################################

bigEcho "创建 /etc/init.d/vpn-assist 脚本..."

cat > /etc/init.d/vpn-assist <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          vpn
# Required-Start:    $network $local_fs
# Required-Stop:     $network $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Strongswan and L2TPD helper
# Description:       Service that starts up XL2TPD and IPSEC
### END INIT INFO

# Author: Phil Plückthun <phil@plckthn.me>

case "$1" in
  start)
    iptables --table nat --append POSTROUTING --jump MASQUERADE
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
      echo 0 > $each/accept_redirects
      echo 0 > $each/send_redirects
    done
    /usr/sbin/xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd.control
    ipsec start
    ;;
  stop)
    iptables --table nat --flush
    echo 0 > /proc/sys/net/ipv4/ip_forward
    kill $(cat /var/run/xl2tpd.pid)
    ipsec stop
    ;;
  restart)
    echo "Restarting IPSec and XL2TPD"
    iptables --table nat --append POSTROUTING --jump MASQUERADE
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
      echo 0 > $each/accept_redirects
      echo 0 > $each/send_redirects
    done
    kill $(cat /var/run/xl2tpd.pid)
    /usr/sbin/xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd.control
    ipsec restart
    ;;
esac
exit 0
EOF

chmod +x /etc/init.d/vpn-assist

#################################################################

bigEcho "启动 VPN..."

/etc/init.d/vpn-assist start

#################################################################

echo "============================================================"
echo "PSK Key: $STRONGSWAN_PSK"
echo "Username: $STRONGSWAN_USER"
echo "Password: $STRONGSWAN_PASSWORD"
echo "============================================================"

echo "注意注意:"
echo "* 连接 Windows 机子前, 看看这: http://support.microsoft.com/kb/926179"
echo "* UDP 端口 1701, 500, 4500 要开着"
echo "* Strongswan 打洞洞不需要特定的域名或 IP"

#################################################################

bigEcho "清理清理..."

call rm -rf $STRONGSWAN_TMP

sleep 2
exit 0
