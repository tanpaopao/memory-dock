# 记忆坞 · DSH 插件

把本地记忆文件夹接进 DeepSeek Harness 的本地插件。加载后，DSH Web 界面右下会出现珊瑚色记忆悬浮球；点开后可以搜索、按分类浏览记忆卡，并把整张记忆插入当前输入框，或者直接拖到输入框/其他应用。

## 能力

- 常驻 `shell.overlay` 的悬浮球，带记忆总数角标
- 记忆面板：搜索、分类、文件预览、刷新
- 点击记忆卡：通过 `InputActions.captureInsertion()` / `insertText()` 插入当前 DSH 输入框，可撤销
- 拖拽记忆卡：以 `text/plain` / `text/markdown` 交付，可拖到当前输入框或其他支持文本拖放的应用
- 打开文件或在 Finder 中显示
- 工作区选择：调用 DSH 的目录选择服务，选择后立即保存
- Agent 工具 `memory_dock`：支持 `list`、`search`、`read` 三种操作，让 Agent 也能读取同一份本地记忆
- 本地优先：Host 只读工作区文件，不连接任何外部服务

## 安装

本目录本身就是一个 DSH bundle 包。可通过当前 Harness 的 Plugin Manager 安装本目录：

```text
/Users/kestrel/Documents/deepseek-harness/default-workspace/MemoryDock/dsh-plugin
```

或使用 CLI 把本地目录链接到 profile（profile 名以实际环境为准）：

```bash
dsh plugin --profile desktop add link:/path/to/MemoryDock/dsh-plugin
```

安装后不需要重启 DSH；Client bundle 会通过 HMR 加载。

## 工作区

默认工作区：`~/Documents/记忆坞`

- 一级文件夹就是分类
- 文件夹中的 `.md`、`.txt`、`.json`、`.yaml`、`.csv` 等文本文件会读取正文，可用于插入或拖拽
- `.pdf`、`.docx`、图片等二进制文件会显示为卡片，点击“打开”交给系统默认应用
- 面板设置中可以重新选择任意本地文件夹；选择结果写入 `~/.dsh/memory-dock/settings.json`

## 使用

1. 点击右下角橙色悬浮球打开面板
2. 搜索或选择分类
3. 点击记忆卡：插入当前输入框
4. 拖拽记忆卡：把正文拖到输入框或其他应用
5. 点击卡片右上角 `↗` 打开文件，`⌕` 在 Finder 中定位
6. 顶部 `⚙` 打开工作区设置

## Agent 工具

插件会注册 `memory_dock` 工具：

- `action: "list"`：列出所有记忆卡和相对路径
- `action: "search", query: "..."`：全文搜索
- `action: "read", path: "01_身份/身份底稿.md"`：读取一张记忆卡

Agent 和 UI 共用同一套 Host 读取逻辑；UI 的插入动作只发生在用户点击或拖拽时。

## Host API

插件注册两个经过 `ctx.connection.requestRejection()` 校验的本地路由：

- `GET /memory-dock/api/state`
- `POST /memory-dock/api/action`

未认证或跨站请求会由 DSH 的连接信任栅栏拒绝。

## 文件结构

```text
dsh-plugin/
├── package.json         # dsh.bundle + dsh.client 声明
├── cordis.patch.yml     # 插入 memory-dock 行
├── index.js             # Host：工作区扫描、路由、工具
├── client.js            # Client：悬浮球、面板、输入框桥
├── locale/{zh,en}.json  # Plugin Manager 显示元数据
├── icon.svg             # 插件图标
└── README.md
```
