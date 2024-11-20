echo "开始 DIY 配置..."
echo "===================="

# Git稀疏克隆，只克隆指定目录到本地
# 参数1是分支名, 参数2是仓库地址, 参数3是子目录，同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

#替换 golang 为 1.22.x 版本
rm -rf feeds/packages/lang/golang
rm -rf feeds/luci/applications/luci-app-netdata
git clone https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang

# 拉取仓库数据
git clone --depth=1 https://github.com/fw876/helloworld package/helloworld
git clone https://github.com/MilesPoupart/luci-app-vssr package/luci-app-vssr
git clone https://github.com/jerrykuku/lua-maxminddb package/lua-maxminddb
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
# 拉取中文版netdata
git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
# 设备关机功能
git clone --depth=1 https://github.com/sirpdboy/luci-app-poweroffdevice package/luci-app-poweroffdevice

# 添加自定义软件包
echo '
CONFIG_PACKAGE_luci-app-passwall=y       #passwall
CONFIG_PACKAGE_luci-app-ttyd=y           #ttyd
# CONFIG_PACKAGE_luci-app-adguardhome=y    #adguardhome
# CONFIG_PACKAGE_luci-app-vlmcsd=y         #KMS服务器（激活工具）
# CONFIG_PACKAGE_luci-app-cpufreq=y        #CPU 性能优化调节
# CONFIG_PACKAGE_UnblockNeteaseMusic-Go=y  #解锁网易云音乐
# CONFIG_PACKAGE_luci-app-unblockmusic=y   #解锁网易云音乐
# CONFIG_PACKAGE_luci-app-netdata=y        #实时监控
' >> .config

# 取消主题设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 修改 argon 为默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 更改 Argon 主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
cp -f $GITHUB_WORKSPACE/images/firewall.config package/network/config/firewall/files/firewall.config
cp -f $GITHUB_WORKSPACE/images/dropbear.config package/network/services/dropbear/files/dropbear.config

# 修改欢迎 banner
cp -f $GITHUB_WORKSPACE/images/banner package/base-files/files/etc/banner

# 设置密码为空
sed -i '/CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings

# 修改概览里时间显示为中文数字
sed -i 's/os.date()/os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")/g' package/lean/autocore/files/x86/index.htm

# x86只显示CPU
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

echo '设置作者信息'
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt-$(TZ=UTC-8 date "+%Y.%m.%d")'/g" package/lean/default-settings/files/zzz-default-settings   
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' By GEOMCH'/g" package/lean/default-settings/files/zzz-default-settings

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} OpenWrt 定制版 玩客云/g" package/lean/default-settings/files/zzz-default-settings

echo 'zzz-default-settings自定义'
# 网络配置信息，将从 zzz-default-settings 文件的第2行开始添加 
# 参考 https://github.com/coolsnowwolf/lede/blob/master/package/lean/default-settings/files/zzz-default-settings
# 先替换掉最后一行 exit 0 再追加自定义内容
sed -i '/.*exit 0*/c\# 自定义配置' package/lean/default-settings/files/zzz-default-settings
cat >> package/lean/default-settings/files/zzz-default-settings <<-EOF

# 设置wan口的pppoe拨号
uci delete network.wan                                          # 删除wan口
uci delete network.wan6                                         # 删除wan6口
uci set network.lan.proto='static'                              # lan口静态IP
uci set network.lan.ipaddr='192.168.9.254'                      # IPv4 地址(openwrt后台地址)
uci set network.lan.netmask='255.255.255.0'                     # IPv4 子网掩码
uci set network.lan.gateway='192.168.9.1'                       # IPv4 网关
uci set network.lan.broadcast='192.168.9.255'                   # IPv4 广播
uci set network.lan.dns='114.114.114.114'                       # DNS(多个DNS要用空格分开)
uci delete network.lan.ip6assign                                # 接口→LAN→IPv6 分配长度——关闭，恢复uci set network.lan.ip6assign='64'
uci commit network

uci delete dhcp.lan.ra                                         # 路由通告服务，设置为“已禁用”
uci delete dhcp.lan.ra_management                              # 路由通告服务，设置为“已禁用”
uci delete dhcp.lan.dhcpv6                                     # DHCPv6 服务，设置为“已禁用”
uci set dhcp.lan.ignore='1'                                    # 关闭DHCP功能
uci set dhcp.@dnsmasq[0].filter_aaaa='1'                       # DHCP/DNS→高级设置→解析 IPv6 DNS 记录——禁止
uci set dhcp.@dnsmasq[0].cachesize='0'                         # DHCP/DNS→高级设置→DNS 查询缓存的大小——设置为'0'
uci commit dhcp

uci delete firewall.@defaults[0].syn_flood                     # 防火墙→SYN-flood 防御——关闭；默认开启
uci set firewall.@defaults[0].fullcone='2'                     # 防火墙→FullCone-NAT——启用；默认关闭
uci commit firewall

uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci set dropbear.@dropbear[0].Port='8822'                      # SSH端口设置为'8822'
uci commit dropbear

uci set system.@system[0].hostname='OpenWrt-Wky'               # 修改主机名称
uci commit system

uci set ttyd.@ttyd[0].command='/bin/login -f root'             # 设置ttyd免帐号登录
uci commit ttyd

# 设置防火墙默认参数
uci set firewall.@defaults[0].input=ACCEPT
uci set firewall.@defaults[0].output=ACCEPT
uci set firewall.@defaults[0].forward=ACCEPT
uci commit firewall

# 设置lan口参数
uci set firewall.@zone[0].input=ACCEPT
uci set firewall.@zone[0].output=ACCEPT
uci set firewall.@zone[0].forward=ACCEPT
uci set firewall.@zone[0].masq='1'
uci set firewall.@zone[0].mtu_fix='1'
uci commit firewall

# 设置wan口参数
uci set firewall.@zone[1].input=ACCEPT
uci set firewall.@zone[1].output=ACCEPT
uci set firewall.@zone[1].forward=ACCEPT
uci set firewall.@zone[1].masq='1'
uci set firewall.@zone[1].mtu_fix='1'
uci commit firewall

# 设置网络诊断
uci set luci.diag.dns='www.baidu.com'
uci set luci.diag.ping='www.baidu.com'
uci set luci.diag.route='www.baidu.com'
uci commit luci

exit 0
EOF

echo "
config subscribe_list
        option remark '1'
        option url 'https://a0782bbe-46e1-9a72-9e3783b0259d.pigfarmcloud.com/api/v1/client/subscribe?token=610cd9b909a88876dc2b205f69b9fdda'
 
config subscribe_list
        option remark '2'
        option url 'https://a0782bbe-46e1-9a72-9e3783b0259d.pigfarmcloud.com/api/v1/client/subscribe?token=610cd9b909a88876dc2b205f69b9fdda'
" >> package/passwall/luci-app-passwall/root/usr/share/passwall/0_default_config

./scripts/feeds update -a
./scripts/feeds install -a

echo "===================="
echo "结束 DIY 配置..."
