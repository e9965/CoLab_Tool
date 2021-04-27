sh_ver="2.7.3"
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin
aria2_passwd=${1} && [[ -z ${aria2_passwd} ]] && aria2_passwd=$(openssl rand -hex 5)
aria2_conf_dir="/root/.aria2c" && mkdir -p ${aria2_conf_dir}
download_path="/conetnt/Temp"
aria2_conf="${aria2_conf_dir}/aria2.conf"
aria2_log="${aria2_conf_dir}/aria2.log" && touch ${aria2_log}
aria2c="/usr/local/bin/aria2c"
Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}信息${Font_color_suffix}]"
Error="[${Red_font_prefix}错误${Font_color_suffix}]"
Tip="[${Green_font_prefix}注意${Font_color_suffix}]"
LINE="======================================================="
APT_INSTALL(){
	IFS=" "
	apt-get install --ignore-missing -y p7zip-full p7zip-rar file rsync dos2unix cron wget curl ca-certificates findutils jq tar gzip dpkg openssl unzip dnsutils
    apt autoremove -y
	if [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
        wget -qO- git.io/ca-certificates.sh | bash
    fi
	IFS=$(echo -en "\n\b")
}
check_pid() {
    PID=$(ps -ef | grep "aria2c" | grep -v grep | grep -v "aria2.sh" | grep -v "init.d" | grep -v "service" | awk '{print $2}')
}
check_new_ver() {
    aria2_new_ver=$(
        {
            wget -t2 -T3 -qO- "https://api.github.com/repos/P3TERX/aria2-builder/releases/latest" ||
                wget -t2 -T3 -qO- "https://gh-api.p3terx.com/repos/P3TERX/aria2-builder/releases/latest"
        } | grep -o '"tag_name": ".*"' | head -n 1 | cut -d'"' -f4
    )
    if [[ -z ${aria2_new_ver} ]]; then
        echo -e "${Error} Aria2 最新版本获取失败，请手动获取最新版本号[ https://github.com/P3TERX/aria2-builder/releases ]"
        read -e -p "请输入版本号:" aria2_new_ver
        [[ -z "${aria2_new_ver}" ]] && echo "取消..." && exit 1
    fi
}
Download_aria2() {
    while [[ $(which aria2c) ]]; do
        echo -e "${Info} 删除旧版 Aria2 二进制文件..."
        rm -vf $(which aria2c)
    done
    DOWNLOAD_URL="https://github.com/P3TERX/aria2-builder/releases/download/${aria2_new_ver}/aria2-${aria2_new_ver%_*}-static-linux-amd64.tar.gz"
    {
        wget -t2 -T3 -O- "${DOWNLOAD_URL}" ||
            wget -t2 -T3 -O- "https://gh-acc.p3terx.com/${DOWNLOAD_URL}"
    } | tar -zx
    [[ ! -s "aria2c" ]] && echo -e "${Error} Aria2 下载失败 !" && exit 1
    [[ ${update_dl} = "update" ]] && rm -f "${aria2c}"
    mv -f aria2c "${aria2c}"
    [[ ! -e ${aria2c} ]] && echo -e "${Error} Aria2 主程序安装失败！" && exit 1
    chmod +x ${aria2c}
    echo -e "${Info} Aria2 主程序安装完成！"
}
Download_aria2_conf() {
    PROFILE_URL1="https://p3terx.github.io/aria2.conf"
    PROFILE_URL2="https://aria2c.now.sh"
    PROFILE_URL3="https://cdn.jsdelivr.net/gh/P3TERX/aria2.conf@master"
    PROFILE_LIST="
aria2.conf
clean.sh
core
script.conf
rclone.env
upload.sh
delete.sh
dht.dat
dht6.dat
move.sh
LICENSE
"
    mkdir -p "${aria2_conf_dir}" && cd "${aria2_conf_dir}"
    for PROFILE in ${PROFILE_LIST}; do
        [[ ! -f ${PROFILE} ]] && rm -rf ${PROFILE}
        wget -N -t2 -T3 ${PROFILE_URL1}/${PROFILE} ||
            wget -N -t2 -T3 ${PROFILE_URL2}/${PROFILE} ||
            wget -N -t2 -T3 ${PROFILE_URL3}/${PROFILE}
        [[ ! -s ${PROFILE} ]] && {
            echo -e "${Error} '${PROFILE}' 下载失败！清理残留文件..."
            rm -vrf "${aria2_conf_dir}"
            exit 1
        }
    done
    sed -i "s@^\(dir=\).*@\1${download_path}@" ${aria2_conf}
    sed -i "s@/root/.aria2/@${aria2_conf_dir}/@" ${aria2_conf_dir}/*.conf
    sed -i "s@^\(rpc-secret=\).*@\1${aria2_passwd}@" ${aria2_conf}
    sed -i "s@^#\(retry-on-.*=\).*@\1true@" ${aria2_conf}
    sed -i "s@^\(max-connection-per-server=\).*@\132@" ${aria2_conf}
    sed -i '/complete/'d ${aria2_conf}
    sed -i 's/force-save=false/force-save=true/g' ${aria2_conf}
    sed -i "s/max-concurrent-downloads=5/max-concurrent-downloads=8/g" ${aria2_conf}
    sed -i "s/listen-port=51413/listen-port=41413/g" ${aria2_conf}
    echo "on-download-complete=${aria2_conf_dir}/clean.sh" >> ${aria2_conf}
    wget -qO ${aria2_conf_dir}/clean.sh https://raw.githubusercontent.com/e9965/CoLab_Tool/main/clean.sh
    echo "bt-external-ip=$(grep "server_addr" /content/frp.sh | cut -d" " -f3 | nslookup | grep -E "Address" | grep -oE "[[:digit:]]+.[^.]+.[^.]+.[^.]+." | grep -vE "^127")" >> ${aria2_conf}
    touch aria2.session
    chmod +x *.sh
    echo -e "${Info} Aria2 完美配置下载完成！"
}
Service_aria2() {
    wget -N -t2 -T3 "https://raw.githubusercontent.com/P3TERX/aria2.sh/master/service/aria2_debian" -O /etc/init.d/aria2 ||
        wget -N -t2 -T3 "https://cdn.jsdelivr.net/gh/P3TERX/aria2.sh@master/service/aria2_debian" -O /etc/init.d/aria2 ||
        wget -N -t2 -T3 "https://gh-raw.p3terx.com/P3TERX/aria2.sh/master/service/aria2_debian" -O /etc/init.d/aria2
    [[ ! -s /etc/init.d/aria2 ]] && {
        echo -e "${Error} Aria2服务 管理脚本下载失败 !"
        exit 1
    }
    chmod +x /etc/init.d/aria2
    update-rc.d -f aria2 defaults
    echo -e "${Info} Aria2服务 管理脚本下载完成 !"
}

Install_aria2() {
    [[ -e ${aria2c} ]] && echo -e "${Error} Aria2 已安装，请检查 !" && exit 1
    echo -e "${Info} 开始下载/安装 主程序..."
    check_new_ver
    Download_aria2
    echo -e "${Info} 开始下载/安装 Aria2 完美配置..."
    Download_aria2_conf
    echo -e "${Info} 开始下载/安装 服务脚本(init)..."
    Service_aria2
    aria2_RPC_port=${aria2_port}
    echo -e "${Info} 开始创建 下载目录..."
    mkdir -p ${download_path}
    echo -e "${Info} 所有步骤 安装完毕，开始启动..."
    /etc/init.d/aria2 start
}
crontab_update_start() {
    crontab -l >"/tmp/crontab.bak"
    sed -i "/aria2.sh update-bt-tracker/d" "/tmp/crontab.bak"
    sed -i "/tracker.sh/d" "/tmp/crontab.bak"
    echo -e "\n0 7 * * * /bin/bash <(wget -qO- git.io/tracker.sh) ${aria2_conf} RPC 2>&1 | tee ${aria2_conf_dir}/tracker.log" >>"/tmp/crontab.bak"
    crontab "/tmp/crontab.bak"
    rm -f "/tmp/crontab.bak"
    Update_bt_tracker
    echo && echo -e "${Info} 自动更新 BT-Tracker 开启成功 !"
}
Update_bt_tracker() {
    check_pid
    [[ -z $PID ]] && {
        bash <(wget -qO- git.io/tracker.sh) ${aria2_conf}
    } || {
        bash <(wget -qO- git.io/tracker.sh) ${aria2_conf} RPC
    }
}

echo "开始初始化"
APT_INSTALL > /dev/null 2>&1
echo "完成初始化 & 开始安装Aria2"
Install_aria2 > /dev/null 2>&1
echo "完成安装Aria2 & SSR 》 开始准备链接数据"
crontab_update_start > /dev/null 2>&1
echo -ne "${LINE}\n搭建完成！${LINE}\n"
