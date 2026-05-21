# Starshine ACME 自动化证书管理工具

[![License](https://img.shields.io/github/license/starshine369/acme-cert)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/starshine369/acme-cert)](https://github.com/starshine369/acme-cert/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/starshine369/acme-cert)](https://github.com/starshine369/acme-cert/issues)

这是一个基于 `acme.sh` 核心深度重构的自动化证书申请与管理脚本。专为高效、极简主义者设计，去除了所有冗余的广告与引流标识，支持自定义证书存放路径，并针对不同的网络环境进行了架构优化。

---

## 🚀 核心特性

- **⚡ 全局快捷键**：首次成功运行后自动注册为全局系统命令。此后在任何目录下，只需在终端输入快捷指令即可瞬间呼出控制面板。
- **📂 动态自定义路径**：打破传统脚本写死在 /root/ 或固定目录的局限，支持动态指定证书导出目录，默认路径为 /opt/cert/您的域名/。后续证书自动续期时，新证书将精准同步至该自定义目录。
- **🌐 纯 IPv6 适配**：内置 DNS64/NAT64 自动转换引擎。在纯 IPv6 环境下可自动建立与纯 IPv4 网络的无感互通，彻底解决境外纯 IPv6 机器申请证书时断网的痛点。
- **🛡️ 完善的申请模式**：
  - **独立 80 端口模式**：全自动检测并强力释放被占用的 80 端口，一键获取单域名 ECC 证书。
  - **DNS API 模式**：原生集成 Cloudflare、腾讯云（DNSPod）、阿里云（Aliyun）的官方 API 接口，支持单域名及泛域名（*.domain.com）证书申请，且无条件支持全自动续期。

---

## 📥 安装与运行

🌍 国际网络环境 (原生直连安装)
适用于非中国大陆地区、可无阻碍访问 GitHub 的 VPS 服务器：
```bash
wget -O acme-cert.sh https://raw.githubusercontent.com/starshine369/acme-cert/main/acme-cert.sh && chmod +x acme-cert.sh && ./acme-cert.sh
```

🇨🇳 国内网络环境 (镜像加速安装)
适用于中国大陆地区的 VPS（采用高可用代理节点，完美规避 GitHub 连接超时或握手失败）：
```bash
wget -O acme-cert.sh https://ghproxy.net/https://raw.githubusercontent.com/starshine369/acme-cert/main/acme-cert.sh && chmod +x acme-cert.sh && ./acme-cert.sh
```

---

## 🛠️ 使用说明

### 1. 快捷面板唤醒
安装并成功运行一次后，您不需要再寻找脚本所在的路径，随时随地在终端输入以下命令即可：

```bash
acme
```


### 2. 功能菜单介绍
运行脚本后将看到如下简洁明了的交互式菜单：
1. **独立 80 端口模式申请证书**：适用于纯净系统或临时停用 80 端口的服务，自动化配置网络验证环境。
2. **DNS API 模式申请证书**：申请泛域名证书必备，支持 Cloudflare/腾讯云/阿里云，全自动配置 API 密钥并完成泛域名验证。
3. **查询当前已申请的域名证书信息**：直观展示已成功托付给 acme.sh 的域名列表及各自的自动续期时间戳。
4. **手动强制续期所有证书**：无脑强制刷新系统内所有已过期或未过期的证书，验证路径连通性。
5. **彻底卸载 acme.sh 及本脚本**：一键清理系统内的核心组件及快捷键（已申请的证书文件仍会予以保留）。

---

## 📂 默认证书输出规范

当您通过脚本成功申请证书后，公钥与私钥会自动安装到以下格式的路径中（以默认路径为例）：
- **公钥文件 (Fullchain CRT)**: /opt/cert/您的域名/cert.crt
- **私钥文件 (Private KEY)**: /opt/cert/您的域名/private.key

*提示：如果在申请过程中输入了自定义路径，后续的 crontab 自动续期任务也会精准将新证书刷新至您指定的自定义路径下。*

---

## 📜 声明与开源协议

- 本项目基于 acme.sh 官方客户端进行二次封装与体验优化。
- 遵循 **MIT License** 开源协议，欢迎进行 Fork、Star 或提交 Issue 共同完善。
