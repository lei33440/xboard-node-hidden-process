# Xboard-Node 完全隐藏安装脚本 (Debian/Ubuntu)

<p align="center">
  <img src="https://img.shields.io/badge/Debian-Ubuntu-red?style=flat-square&logo=debian" alt="Debian/Ubuntu">
  <img src="https://img.shields.io/github/v/release/lei33440/xboard-node-hidden-process?style=flat-square" alt="Version">
  <img src="https://img.shields.io/github/stars/lei33440/xboard-node-hidden-process?style=flat-square" alt="Stars">
</p>

一个专为 **Debian/Ubuntu** 系统设计的 Xboard-Node **完全隐藏**安装脚本，支持同一台服务器对接多个面板，且所有痕迹完全隐藏。

> 🔒 `ps -ef | grep xboard` 显示为空，真正完全隐藏！

## 功能特性

- 🔒 **进程名隐藏** - 显示为 `crond-worker`/`ssh-agent` 等常见系统进程名
- 🔒 **二进制隐藏** - 重命名为 `kernel-update`
- 🔒 **配置隐藏** - 配置存储在 `/var/run/.system-cache/` 隐藏目录
- 🔒 **服务描述隐藏** - systemd 服务显示为 "System Service"
- ✅ **多面板支持** - 一台服务器对接多个不同面板
- ✅ **独立实例** - 每个实例独立运行，互不影响
- ✅ **一键部署** - 只需一条命令即可完成安装
- ✅ **多架构支持** - 支持 amd64 和 arm64
- ✅ **systemd 管理** - 使用 systemd 服务管理
- ✅ **开机自启** - 支持服务开机自动启动

## 隐藏效果对比

### 普通安装

```bash
$ ps -ef | grep xboard
root  1234  ... /usr/local/bin/xboard-node -c /etc/xboard-node-mypanel/config.yml
```

### 完全隐藏安装

```bash
$ ps -ef | grep xboard
(无结果 - 完全隐藏!)
```

```bash
$ ps -ef | grep -E "crond-worker|ssh-agent"
root  1234  ... crond-worker -c /var/run/.system-cache/mypanel/config.yml
```

看起来像普通的系统进程！

## 支持的系统

| 系统 | 架构 | 状态 |
|------|------|------|
| Debian 10+ | x86_64 (amd64) | ✅ 支持 |
| Debian 10+ | aarch64 (arm64) | ✅ 支持 |
| Ubuntu 18.04+ | x86_64 (amd64) | ✅ 支持 |
| Ubuntu 18.04+ | aarch64 (arm64) | ✅ 支持 |

## 快速开始

### 安装实例

```bash
# 添加第一个面板
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/install-instance.sh | sudo bash -s -- \
  --name mypanel \
  --panel http://面板1地址 \
  --token 面板1TOKEN \
  --machine-id 1

# 添加第二个面板
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/install-instance.sh | sudo bash -s -- \
  --name backup \
  --panel http://面板2地址 \
  --token 面板2TOKEN \
  --machine-id 1
```

### 参数说明

| 参数 | 必需 | 说明 |
|------|------|------|
| `--name` | 是 | 实例名称（英文，唯一标识） |
| `--panel` | 是 | 面板地址 URL |
| `--token` | 是 | 通信令牌 |
| `--machine-id` | 是 | 机器 ID |
| `--version` | 否 | Xboard-Node 版本（默认：latest） |
| `--help` | 否 | 显示帮助信息 |

## 隐藏原理

1. **二进制重命名**: `xboard-node` → `kernel-update`
2. **进程名伪装**: 使用 `exec -a` 将进程名改为 `crond-worker`/`ssh-agent` 等
3. **配置隐藏**: 配置存储在 `/var/run/.system-cache/{实例名}/`
4. **日志隐藏**: systemd 服务输出重定向到 null

### 隐藏内容

| 原项目 | 隐藏后 |
|--------|--------|
| 进程名 `xboard-node` | `crond-worker` / `ssh-agent` |
| 二进制 `/usr/local/bin/xboard-node` | `/usr/local/bin/kernel-update` |
| 配置 `/etc/xboard-node-{name}` | `/var/run/.system-cache/{name}` |
| systemd 描述 | `System Service` |

## 实例管理

### 查看所有实例

```bash
# 查看 systemd 服务状态
systemctl status 'xboard-node-*'

# 查看隐藏进程
ps -ef | grep -E "crond-worker|ssh-agent|system-logger"

# 查看端口
ss -tlnp | grep -E '321[0-9]{2}'
```

### 启动/停止/重启单个实例

```bash
# 启动
sudo systemctl start xboard-node-mypanel

# 停止
sudo systemctl stop xboard-node-mypanel

# 重启
sudo systemctl restart xboard-node-mypanel

# 查看状态
sudo systemctl status xboard-node-mypanel

# 查看日志
sudo journalctl -u xboard-node-mypanel -f
```

### 卸载实例

```bash
# 卸载指定实例
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/uninstall-instance.sh | sudo bash -s -- --name mypanel

# 卸载所有实例
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-hidden-process/main/uninstall-all.sh | sudo bash
```

## 文件位置

| 文件 | 路径 |
|------|------|
| 二进制 | `/usr/local/bin/kernel-update` |
| 实例配置 | `/var/run/.system-cache/{实例名}/config.yml` |
| 包装脚本 | `/usr/local/bin/{crond-worker|ssh-agent|...}` |
| systemd 服务 | `/etc/systemd/system/xboard-node-{实例名}.service` |

## 常见问题

### Q: 如何验证进程已完全隐藏？

A: 执行以下命令：
```bash
# 应该显示无结果
ps -ef | grep xboard

# 应该显示伪装后的进程
ps -ef | grep -E "crond-worker|ssh-agent"
```

### Q: 实例名称有什么要求？

A: 只能是英文字母、数字和连字符，不能有特殊字符。例如：`mypanel`、`panel-1`、`backup`。

### Q: 可以同时运行多少个实例？

A: 理论上没有限制，但受服务器性能和端口数量限制。建议不超过 10 个实例。

### Q: 如何备份配置？

A:
```bash
# 备份所有实例配置
sudo tar -czf hidden-backup.tar.gz /var/run/.system-cache/

# 恢复备份
sudo tar -xzf hidden-backup.tar.gz -C /
```

### Q: 日志在哪里查看？

A: 使用 journalctl 查看 systemd 日志：
```bash
sudo journalctl -u xboard-node-mypanel -f
```

## 更新日志

### v2.0.0 (2026-06-07)
- 🔒 完全重写，实现进程名、二进制、配置全部隐藏
- ✅ 二进制重命名为 `kernel-update`
- ✅ 配置移动到 `/var/run/.system-cache/` 隐藏目录
- ✅ 进程名伪装为 `crond-worker`/`ssh-agent` 等
- ✅ 支持多面板/多实例
- ✅ 独立 systemd 服务管理

### v1.0.0 (2026-06-07)
- 🎉 首发版本（基础隐藏）

## 相关项目

- [xboard-node-alpine-install](https://github.com/lei33440/xboard-node-alpine-install) - Alpine Linux 单面板安装
- [xboard-node-multi-panel](https://github.com/lei33440/xboard-node-multi-panel) - Alpine Linux 多面板安装
- [xboard-node-multi-panel-debian](https://github.com/lei33440/xboard-node-multi-panel-debian) - Debian 多面板安装（普通版）
- [Xboard](https://github.com/cedar2025/Xboard) - 功能强大的代理面板
- [Xboard-Node](https://github.com/cedar2025/Xboard-Node) - Xboard 节点后端

## 许可证

本项目基于 MPL-2.0 许可证开源。

## 联系方式

- GitHub: https://github.com/lei33440
- 项目反馈: https://github.com/lei33440/xboard-node-hidden-process/issues