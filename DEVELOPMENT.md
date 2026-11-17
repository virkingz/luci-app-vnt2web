# 开发说明

## 设计原则

1. **不做重复的轮子**。OpenWrt 已有 procd、UCI、LuCI、rpcd，
   插件就用这些，自己只写「vnt 特有的」那部分。
2. **逻辑集中在 shell 库**。`files/usr/share/vnt2web/*.sh` 是唯一的事实来源；
   `rpcd` 后端与 `init.d` 脚本都调它，不各写一遍。
   这样加参数只需改一处。
3. **不依赖编译**。插件是纯脚本 + 前端资源（`PKGARCH=all`），
   因此可以免 SDK 打包，产物与 SDK 编译等价。

## 为什么和飞牛版长得不一样

飞牛版（`vnt-nas`）用 Python 写后端、自带网页管理页、托管 `vnt2_web`。
那是被环境逼出来的：

| | 飞牛 fnOS | OpenWrt |
|---|---|---|
| 插件界面框架 | **没有**，只能自带网页 | LuCI（现成） |
| 后端语言 | Python（系统自带） | shell / ucode（系统自带） |
| 适合的核心 | `vnt2_web`（自带网页） | `vnt2_cli`（纯命令行，更轻） |
| 配置存储 | 自己管文件 | UCI（系统统一） |
| 进程管理 | 自己写 pid 管理 | procd（系统统一） |

所以这里**刻意不用 Python**：路由器普遍没装 Python，Flash 也放不下。

## 各文件职责

| 文件 | 职责 |
|------|------|
| `files/usr/share/vnt2web/vnt.sh` | 基础层：路径、日志、架构映射、HTTP 客户端、版本查询、镜像与代理 |
| `files/usr/share/vnt2web/vnt-core.sh` | 核心层：下载/安装/回滚、UCI→参数翻译、进程状态、防火墙 |
| `files/etc/init.d/vnt2web` | procd 服务 + 扩展子命令（status/diag/check_update/update_core/log） |
| `files/etc/config/vnt2web` | UCI 默认值与字段文档（本身就是配置说明） |
| `files/usr/libexec/rpcd/vnt2web` | LuCI 后端（rpcd shell 插件），暴露 ubus 对象 `vnt2web`；只做参数校验与 JSON 编解码 |
| `htdocs/.../view/vnt2web/client.js` | LuCI 前端界面 |
| `scripts/ipk.py` | ipk 组装器（纯 Python，含 ar + tar.gz） |
| `scripts/build-ipk.py` | 打包驱动：收集文件、生成 control、调 ipk.py |
| `scripts/test.py` | 本地测试，124 项 |

## 加一个组网参数要改哪里

以新增参数「`--foo-bar`」为例：

1. `files/etc/config/vnt2web`：加一行 `option foo_bar ''`（写清注释）
2. `files/usr/share/vnt2web/vnt-core.sh` 的 `vnt_build_args`：
   加 `v="$(vnt_uci_get foo_bar '')"; [ -n "$v" ] && args="$args --foo-bar $v"`
3. `htdocs/.../client.js`：加一个 `s.option(form.Value, 'foo_bar', ...)`
4. `scripts/test.py` 的 `test_args`：加一条断言

布尔开关同理，但取值判断用 `[ "$(vnt_uci_get foo_bar 0)" = "1" ]`。

## 打包

```sh
python scripts/build-ipk.py          # 版本号取 Makefile 的 PKG_VERSION
python scripts/build-ipk.py 1.0.1    # 指定版本
```

产物：`dist/luci-app-vnt2web_<版本>-1_all.ipk`

打包器有两点必须注意（都踩过）：

- **权限走显式表**。不能依赖源文件权限位——Windows 上 `os.chmod` 的执行位
  `os.stat` 读不回来，会导致 `init.d` 脚本装上去是 644，OpenWrt 拒绝启动服务。
  `build-ipk.py` 的 `INSTALL_MAP` 里显式写了每个文件的目标权限。
- **换行统一 LF**。Windows 上编辑会把 `.sh`/`.uc`/`.js` 写成 CRLF，
  装到 Linux 后 shell 可能因 `\r` 报错。打包前统一转 LF（跳过图片等二进制）。

## 测试

```sh
python scripts/test.py
```

124 项，全部不联网、不需要 OpenWrt 环境。覆盖：

| 分组 | 内容 |
|------|------|
| 架构映射 | 11 个真实 `DISTRIB_ARCH` + 3 个应拒绝的 |
| 版本解析 | 10 个正常输入（含镜像 URL 编码的坑）+ 4 个应拒绝 |
| 版本比较 | 6 组 |
| UCI→参数 | 用桩 `uci` 驱动真实 shell 库，5 组配置 |
| ipk 产物 | ar 结构、control 字段、9 个文件权限、uid/gid、CRLF |
| 静态检查 | sh -n、JSON 合法性、库函数引用完整性、JS 语法、RPC 与后端方法对应 |

### 测试如何驱动 shell 库

关键技巧是用**桩 `uci` 脚本**：把它放进 `PATH`，从环境变量
`UCI_vnt_main_<option>` 回读值。这样就能在不装 OpenWrt 的情况下
测试真实的参数翻译逻辑，而不是测一个重写的副本。

## 踩过的坑

- **ipk 外层用了 ar（最致命，上机才暴露）**。第一版把 ipk 外层写成了 `ar` 归档——
  那是 Debian `.deb` 的容器格式。opkg 不认，安装时报
  `pkg_init_from_file: Malformed package file`。
  **OpenWrt 的 ipk 外层是 gzip 压缩的 tar**，三个成员名前带 `./` 前缀。
  自检方法：`tar tzf xxx.ipk` 应能列出
  `./debian-binary ./data.tar.gz ./control.tar.gz`。
  教训：**打包格式必须拿官方真包做基准对照**，不能凭「ipk 源自 deb」的印象推断。
  现已把「外层必须是 gzip」写成硬断言，并保留官方基准包做自动对照。
- **内层成员名缺 `./` 前缀**。官方 `control.tar.gz` 里是 `./control`、`./postinst`，
  且有一条 `.` 根条目；`data.tar.gz` 同理（`./etc/...`）。第一版没加前缀。
- **可执行位丢失**。打包器最初按源文件权限写 tar，
  Windows 上 `os.stat` 拿不到执行位，`init.d/vnt` 装上去是 644 →
  服务无法启动。改为显式权限表。
- **`[ -x /sbin/uci ]` 判断过脆**。测试环境与部分精简固件里 uci 不在 `/sbin`，
  应统一用 `command -v uci`。
- **`procd_set_param file` 用错**。它表示「该文件变化时重启服务」，
  不是重定向输出。正确的是 `stderr 1` / `stdout 1` 交给 procd 采集。
- **版本号按 `/` 切分**。镜像把整段 URL 编码时会得到 `https%3A%2F%2F...`，
  必须用正则提取而非切分。
- **纯 shell 解不了 zip**。OpenWrt 默认既无 `unzip` 也无 `python3`，
  deflate 流无法用 shell 解。故把 `unzip` 列为包依赖，不做内置解包器
  （曾试图写一个，不现实）。
- **前端不能用改 `m.children[0]` 的方式插区块**。LuCI 的 Map 结构不是稳定的
  公开接口。改为把自定义区块用 `insertBefore`/`appendChild` 挂到 `m.render()`
  的结果上。

## 上机验证清单

以下需在真实设备上确认（开发环境无 OpenWrt 设备）：

- [ ] `opkg install` 成功，依赖自动解决
- [ ] LuCI 菜单「服务 → VNT 组网」出现
- [ ] 「检查更新」能查到版本号
- [ ] 「下载核心」成功，`/etc/vnt2web/bin/vnt2_cli --version` 可执行
- [ ] 启动后 `ip addr` 能看到 `vnt2-tun` 网卡
- [ ] `ping <对端虚拟IP>` 通
- [ ] 点对网：从对端访问本机 LAN 设备通
- [ ] `sysupgrade` 后核心仍在（验证存 `/etc` 的意义）
- [ ] 防火墙区域确实加上了虚拟网卡（`uci show firewall`）
