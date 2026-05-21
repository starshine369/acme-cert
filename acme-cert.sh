#!/bin/bash 
export LANG=en_US.UTF-8
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}

[[ $EUID -ne 0 ]] && yellow "请以 root 模式运行脚本" && exit

# ==========================================
# 自动注册全局快捷键 (输入 acme 即可呼出)
# ==========================================
if [[ ! -f "/usr/local/bin/acme" || "$(cat /usr/local/bin/acme 2>/dev/null)" != "$(cat $0 2>/dev/null)" ]]; then
    cp "$0" /usr/local/bin/acme
    chmod +x /usr/local/bin/acme
fi

# ==========================================
# 系统与环境检测
# ==========================================
if [[ -f /etc/redhat-release ]]; then
    release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
    release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
    release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="Centos"
else 
    red "不支持当前的系统，请选择使用 Ubuntu, Debian, Centos 系统" && exit 
fi

v4v6(){
    v4=$(curl -s4m5 icanhazip.com -k)
    v6=$(curl -s6m5 icanhazip.com -k)
}

if [ ! -f /tmp/acme_env_check ]; then
    green "首次运行，检测并安装必要的依赖包..."
    if [[ x"${release}" == x"alpine" ]]; then
        apk add wget curl tar jq tzdata openssl expect git socat iproute2 virt-what
    else
        if [ -x "$(command -v apt-get)" ]; then
            apt update -y && apt install socat cron curl openssl lsof dnsutils tar wget -y
        elif [ -x "$(command -v yum)" ]; then
            yum update -y && yum install epel-release socat cronie bind-utils curl openssl lsof tar wget -y
        elif [ -x "$(command -v dnf)" ]; then
            dnf update -y && dnf install socat cronie bind-utils curl openssl lsof tar wget -y
        fi
    fi
    touch /tmp/acme_env_check
fi

if [[ -z $(curl -s4m5 icanhazip.com -k) ]]; then
    yellow "检测到 VPS 为纯 IPv6，添加 NAT64 节点..."
    echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
    sleep 2
fi

# ==========================================
# 核心功能模块
# ==========================================
release_port_80(){
    if [[ -n $(lsof -i :80|grep -v "PID") ]]; then
        yellow "检测到 80 端口被占用，正在释放..."
        lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
        green "80 端口释放完毕！"
        sleep 1
    fi
}

install_acme_core(){
    readp "请输入注册申请所需邮箱 (直接回车随机生成): " Aemail
    if [ -z $Aemail ]; then
        Aemail=$(date +%s%N | md5sum | cut -c 1-8)@gmail.com
    fi
    yellow "使用邮箱：$Aemail"
    green "开始安装 acme.sh 核心组件..."
    bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
    rm -rf ~/.acme.sh acme.sh
    curl https://get.acme.sh | sh -s email=$Aemail
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        green "acme.sh 安装成功！"
        bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    else
        red "acme.sh 安装失败，请检查网络！" && exit
    fi
}

install_cert(){
    mkdir -p "${CERT_PATH}"
    bash ~/.acme.sh/acme.sh --install-cert -d ${ym} \
        --key-file "${CERT_PATH}/private.key" \
        --fullchain-file "${CERT_PATH}/cert.crt" --ecc
}

check_result(){
    if [[ -f "${CERT_PATH}/cert.crt" && -f "${CERT_PATH}/private.key" ]] && [[ -s "${CERT_PATH}/cert.crt" && -s "${CERT_PATH}/private.key" ]]; then
        green "\n=============================================="
        green "🎉 证书申请成功并下发！"
        yellow "证书存放路径如下："
        green "公钥 (crt) : ${CERT_PATH}/cert.crt"
        green "私钥 (key) : ${CERT_PATH}/private.key"
        green "==============================================\n"
    else
        red "❌ 证书申请失败！请检查 IP 解析、防火墙或 API 密钥设置。"
        exit 1
    fi
}

check_ip_match(){
    v4v6
    domainIP=$(dig @8.8.8.8 +time=2 +short "$ym" 2>/dev/null | grep -m1 '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$')
    if [[ -z $domainIP ]]; then
        domainIP=$(dig @2001:4860:4860::8888 +time=2 aaaa +short "$ym" 2>/dev/null | grep -m1 ':')
    fi
    
    if [[ -z $domainIP ]]; then
        red "域名未解析出 IP！"
    else
        green "当前域名解析到的 IP: $domainIP"
        if [[ ! $domainIP =~ $v4 ]] && [[ ! $domainIP =~ $v6 ]]; then
            yellow "⚠️ 警告：当前域名解析 IP 与本机 IP 不匹配！若是独立 80 端口模式，必然失败！"
        fi
    fi
}

# ==========================================
# 申请模式一：独立 80 端口 (域名/纯IP)
# ==========================================
mode_standalone(){
    release_port_80
    install_acme_core
    
    echo -e "\n=============================================="
    echo -e "请选择申请证书的目标类型："
    echo -e "  ${green}1.${plain} 域名证书 (有效期90天，提前1个月自动续期)"
    echo -e "  ${green}2.${plain} 纯 IP 证书 (强行高频轮换，每 5 天自动续期)"
    readp "请选择 [1-2]: " cert_type
    
    if [[ "$cert_type" == "1" ]]; then
        readp "请输入需要申请证书的域名 (如 example.com): " ym
        if [ -z "$ym" ]; then red "域名不能为空！" && exit; fi
        readp "请输入存放路径 (回车默认存放于 /root/cert/domain/$ym/ ): " custom_path
        CERT_PATH=${custom_path:-/root/cert/domain/$ym}
        green "证书将下发至: $CERT_PATH"
        
        check_ip_match
        
        v4v6
        # --days 60: 等于 90 天有效期用了 60 天后续期 (即提前 1 个月)
        if [[ $domainIP == $v6 ]]; then
            bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure --days 60
        else
            bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --insecure --days 60
        fi
        
    elif [[ "$cert_type" == "2" ]]; then
        echo -e "\n=============================================="
        echo -e "请选择纯 IP 证书的申请模式："
        echo -e "  1. 仅 IPv4 证书"
        echo -e "  2. 仅 IPv6 证书"
        echo -e "  3. IPv4 + IPv6 (双栈共存证书)"
        readp "请选择 [1-3]: " ip_choice
        
        v4v6
        # --days 5: 无论有效期多长，强制每 5 天向 Let's Encrypt 重新请求刷新
        case "$ip_choice" in 
            1 )
                if [ -z "$v4" ]; then red "未检测到公网 IPv4！" && exit; fi
                ym="$v4"
                CERT_PATH="/root/cert/IP/$ym"
                green "将为 IPv4: $ym 申请证书。下发至: $CERT_PATH"
                bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --insecure --days 5
                ;;
            2 )
                if [ -z "$v6" ]; then red "未检测到公网 IPv6！" && exit; fi
                ym="$v6"
                CERT_PATH="/root/cert/IP/$ym"
                green "将为 IPv6: $ym 申请证书。下发至: $CERT_PATH"
                bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure --days 5
                ;;
            3 )
                if [ -z "$v4" ] || [ -z "$v6" ]; then red "IPv4 或 IPv6 缺失，环境不满足双栈条件！" && exit; fi
                ym="$v4"
                CERT_PATH="/root/cert/IP/$ym"
                green "将为双栈 ($v4 + $v6) 申请整合证书。下发至: $CERT_PATH"
                bash ~/.acme.sh/acme.sh --issue -d ${v4} -d ${v6} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure --days 5
                ;;
            * ) red "选择错误！"; exit 1 ;;
        esac
    else
        red "选择错误！" && exit
    fi
    
    install_cert
    check_result
}

# ==========================================
# 申请模式二：DNS API (仅限域名)
# ==========================================
mode_dns_api(){
    install_acme_core
    
    readp "请输入需要申请证书的域名 (如 example.com): " ym
    if [ -z "$ym" ]; then red "域名不能为空！" && exit; fi
    readp "请输入存放路径 (回车默认存放于 /root/cert/domain/$ym/ ): " custom_path
    CERT_PATH=${custom_path:-/root/cert/domain/$ym}
    green "证书将下发至: $CERT_PATH"
    
    echo -e "请选择托管域名解析服务商："
    echo -e "  1. Cloudflare (API Token 模式 - 推荐，更安全)"
    echo -e "  2. Cloudflare (Global API Key 模式 - 传统老方法)"
    echo -e "  3. 腾讯云 DNSPod"
    echo -e "  4. 阿里云 Aliyun"
    readp "请选择 [1-4]: " api_choice
    
    case "$api_choice" in 
        1 )
            readp "请输入 Cloudflare API Token: " CF_Token
            export CF_Token
            bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt --insecure --days 60
            ;;
        2 )
            readp "请输入 Cloudflare Global API Key: " CF_Key
            export CF_Key
            readp "请输入 Cloudflare 注册邮箱: " CF_Email
            export CF_Email
            bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt --insecure --days 60
            ;;
        3 )
            readp "请输入腾讯云 DNSPod DP_Id: " DP_Id
            export DP_Id
            readp "请输入腾讯云 DNSPod DP_Key: " DP_Key
            export DP_Key
            bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt --insecure --days 60
            ;;
        4 )
            readp "请输入阿里云 Ali_Key: " Ali_Key
            export Ali_Key
            readp "请输入阿里云 Ali_Secret: " Ali_Secret
            export Ali_Secret
            bash ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt --insecure --days 60
            ;;
        * ) red "选择错误！"; exit 1 ;;
    esac
    
    install_cert
    check_result
}

# ==========================================
# 维护模块
# ==========================================
list_certs(){
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装 acme.sh 核心组件" && exit 
    green "=============================================="
    bash ~/.acme.sh/acme.sh --list
    green "=============================================="
}

renew_certs(){
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装 acme.sh 核心组件" && exit 
    green "开始尝试续期所有证书..."
    bash ~/.acme.sh/acme.sh --cron -f
    green "续期执行完毕！"
}

uninstall_acme(){
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        bash ~/.acme.sh/acme.sh --uninstall
        rm -rf ~/.acme.sh
        green "acme.sh 核心组件已成功卸载。"
    else
        yellow "未检测到 acme.sh 核心，已跳过核心清理。"
    fi
    
    rm -f /usr/local/bin/acme
    green "Starshine ACME 面板及快捷命令已彻底卸载！(注意：已生成的证书文件仍会保留在原处)"
    exit 0
}

# ==========================================
# 主菜单
# ==========================================
clear
green "========================================================================="
blue  "            Starshine ACME 自动化证书管理脚本"
white "            Github: starshine369/acme-cert"
green "========================================================================="
echo -e " ${green}1.${plain} 独立 80 端口模式申请证书 (支持纯 IP / 单域名)"
echo -e " ${green}2.${plain} DNS API 模式申请证书 (需提供 API，支持泛域名)"
echo -e " ${green}3.${plain} 查询当前已申请的域名/IP证书信息"
echo -e " ${green}4.${plain} 手动强制续期所有证书"
echo -e " ${green}5.${plain} 彻底卸载 acme.sh 及本脚本"
echo -e " ${green}0.${plain} 退出"
green "========================================================================="
echo -e "\033[36m\033[01m 💡 提示：本脚本已注册全局命令，随时输入 acme 即可呼出本面板。\033[0m"
readp "请输入数字 [0-5]: " NumberInput

case "$NumberInput" in     
    1 ) mode_standalone;;
    2 ) mode_dns_api;;
    3 ) list_certs;;
    4 ) renew_certs;;
    5 ) uninstall_acme;;
    * ) exit ;;      
esac
