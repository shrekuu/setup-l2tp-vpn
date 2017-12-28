# 在 Ubuntu/Debian 上配置高鲁棒性(真的, 骗你是小狗) StrongSwan IPSec(& L2TP) VPN 服务

> 如果你不爱 LibreSwan 了那就试试 StrongSwan.

## 安装

1. 先安装 strongswan 与 xl2tpd:

    ```
    sudo apt install strongswan xl2tpd
    ```

2. 然后执行(运行此脚本不需要额外的域名或公网 IP):

    ```
    curl -L -O https://rawgit.com/shrekuu/setup-l2tp-vpn/master/setup.sh
    chmod +x setup.sh
    sudo ./setup.sh
    ```

脚本运行过程中你需要设置:

- 用户名
- 密码
- PSK (预共享密钥)

> 若要升级 Strongswan, 再跑一遍此脚本即可, 记得要先备份你的 IPSec 配置.

## 用法

此脚本安装了 `vpn-assist` 启动脚本到 `/etc/init.d` 目录. 比如:

```sh
sudo service vpn-assist start
sudo service vpn-assist stop
sudo service vpn-assist restart

```


也支持 Systemd 启动. 比如:

```sh
sudo systemctl start vpn-assist
sudo systemctl stop vpn-assist
sudo systemctl restart vpn-assist
```


> 在 `etc/ppp/chap-secrets`(l2tp) 这里修改账号.
> [@zackdevine 也可以参考这个宝宝的账号管理脚本](https://github.com/zackdevine/setup-strongswan-vpn-account)

## 卸载

卸载 `strongswan` 和 `xl2tpd`:

```sh
sudo apt purge strongswan
sudo apt purge xl2tpd
```

删除 `/etc/init.d/vpn-assist`.
