# Mochi

给 [Claude Code](https://claude.ai/code) 用的极轻量桌面通知工具。当 Claude Code 准备调用工具、执行完毕、请求确认或完成响应时，屏幕右下角会弹出一个小窗口提醒你。

**仅限 Windows** | **零依赖** | **4 个文件安装，删除即卸载**

## 效果

深色圆角小窗口从屏幕右下角丝滑滑入（淡入+上滑动画），显示 Claude Code 正在使用的工具名称和操作的文件路径。5 秒后自动淡出消失，点击窗口任意位置立即淡出关闭。

## 环境要求

- Windows 10 或 11
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview)（已安装并可通过 `claude` 命令进入交互）
- PowerShell 5.1+（Windows 自带，无需额外安装）
- .NET Framework 4.6+（Windows 自带）

## 安装

### 第一步：复制脚本文件

将 `mochi.ps1` 放到你的项目根目录下：

```powershell
# 例如项目在 D:\my-project
cp mochi.ps1 D:\my-project\
```

### 第二步：获取项目路径

Hook 命令需要 `mochi.ps1` 的**绝对路径**。如果你的路径不含空格，直接用普通路径即可。如果路径包含空格（如 `D:\code files\...`），需要获取 8.3 短路径：

```powershell
# 获取短路径（在 PowerShell 中运行）
(New-Object -ComObject Scripting.FileSystemObject).GetFolder('D:\code files\cc mochi').ShortPath
# 输出类似：D:\CODEFI~1\CCMOCH~1
```

### 第三步：配置 Hook

在项目根目录创建 `.claude` 文件夹，然后将 `settings.example.json` 复制进去并改名为 `settings.json`：

```powershell
mkdir D:\你的项目\.claude
cp .claude\settings.example.json D:\你的项目\.claude\settings.json
```

打开 `.claude\settings.json`，将两处 `YOUR_PROJECT_PATH` 换成你的实际路径：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"你的路径/mochi.ps1\"",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"你的路径/mochi.ps1\"",
            "timeout": 30
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"你的路径/mochi.ps1\"",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"你的路径/mochi.ps1\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

> **注意**：修改 `settings.json` 后必须**重启 Claude Code 会话**，Hook 配置在启动时加载。

### 第四步：验证

在项目目录下启动 Claude Code，输入一个会触发工具调用的指令：

```
> 帮我创建一个 test.txt，内容是 hello world
```

当 Claude Code 准备调用 Write 工具时，屏幕右下角应该弹出一个深色窗口，显示 "Tool: Write" 和文件路径。

也可以手动验证脚本是否正常：

```powershell
echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt"}}' | powershell -ExecutionPolicy Bypass -File "你的路径/mochi.ps1"
```

如果能看见弹窗，说明脚本本身没问题。

## 全局安装（可选）

上述配置仅对当前项目生效。如果你希望**在任意目录下启动 Claude Code 都触发通知**，将 hooks 配置放入用户级设置文件：

```powershell
# 编辑全局配置
notepad $env:USERPROFILE\.claude\settings.json
```

把 `settings.example.json` 中的 `hooks` 块合并进去即可（路径同样改为绝对短路径）。

**注意**：如果同时配置了全局和项目级 hooks，每次事件会触发**两次**弹窗。建议只保留全局，删除项目级 `.claude/settings.json` 中的 hooks。

## Hook 事件说明

| 事件 | 触发时机 | 匹配规则 | 典型弹窗内容 |
|------|----------|----------|-------------|
| `PreToolUse` | 工具调用**前** | `Write\|Edit\|Bash` | "Tool: Write" + 文件路径 |
| `PostToolUse` | 工具执行**完毕** | `Write\|Edit\|Bash` | "Tool: Write" + 文件路径 |
| `Notification` | Claude Code 请求**确认/权限** | `""`（全部） | 显示 Claude Code 的提问内容 |
| `Stop` | Claude Code **完成一轮响应** | `""`（全部） | "Response complete" |

可在 `settings.json` 的 `matcher` 字段增减工具名。例如只想在写文件时通知，可以改为 `"matcher": "Write"`。

## 自定义

编辑 `mochi.ps1` 顶部的配置区域：

### 标题和默认文案

```powershell
$Title = "Mochi"           # 窗口标题

function Get-Body {
    param($ToolName, $FilePath, $EventMessage)

    if ($ToolName) {
        $text = "工具: $ToolName"
        if ($FilePath) { $text += "`n文件: $FilePath" }
        return $text
    }
    if ($EventMessage) { return $EventMessage }
    return "Response complete"    # 无具体信息时的默认文案
}
```

可用变量：

| 变量 | 来源 | 说明 |
|------|------|------|
| `$ToolName` | `tool_name` | 工具名（Write / Edit / Bash） |
| `$FilePath` | `tool_input.file_path` | 操作文件路径，可能为空 |
| `$EventMessage` | `message` | Claude Code 原始消息，可能为空 |

### 停留时间与动画

```powershell
$DisplaySeconds = 5           # 停留时间（默认 5 秒）
$EnterDuration  = 400         # 入场动画时长 ms
$ExitDuration   = 250         # 出场动画时长 ms
```

入场动画：窗口从屏幕外向上滑入 + 淡入（CubicEase 缓动）  
出场动画：窗口向下滑出 + 淡出（定时或点击触发）

### 声音

```powershell
$Sound = $false               # 设为 $true 弹窗时播放系统提示音
```

使用 Windows 内置的 `SystemSounds.Asterisk`，零依赖。可改为 `Hand`、`Beep`、`Question`。

### 外观

窗口颜色、大小、圆角等均可修改，见脚本中 WPF 相关部分（`#E81A1A1A` 为背景色，`#33FFFFFF` 为边框色）。

## 故障排查

| 现象 | 可能原因 | 解决 |
|------|----------|------|
| 完全没有弹窗 | Hook 配置未加载 | 确认已重启 Claude Code；检查 `.claude/settings.json` 是否存在 |
| 报错 "路径中具有非法字符" | 路径含空格被拆分 | 换用 8.3 短路径（见安装第二步） |
| 弹窗一闪而过 | 停留时间太短 | 增大 `$timer.Interval` |
| 弹窗不显示内容 | stdin JSON 解析失败 | 检查 `Get-Body` 函数逻辑 |
| 弹窗位置不对 | 多显示器 | 已支持跟随光标所在屏幕，DPI 自动适配 |

## 工作原理

```
Claude Code 触发 Hook 事件
        │
        ▼
  powershell.exe -File mochi.ps1       ← Hook 子进程
        │
        ├─ 从 stdin 读取事件 JSON       ← Claude Code 传入的上下文
        ├─ 提取 tool_name / file_path / message
        ├─ 自定义文案（Get-Body 函数）
        ├─ 用 WPF 渲染圆角深色窗口        ← .NET Framework 内置
        ├─ 定位到光标所在屏幕的右下角          ← 多显示器+DPI 适配
        ├─ 可选声音提示                    ← SystemSounds
        ├─ 入场动画：Storyboard 滑入+淡入  ← 400ms CubicEase
        ├─ 点击 → 出场动画（滑出+淡出）→ 关闭
        └─ 5 秒后 → 出场动画 → 自动关闭
        │
        ▼
  exit 0                                ← 始终放行，不阻塞 Claude Code
```

WPF 是 .NET Framework 的一部分，Windows 10/11 预装。整个过程不涉及任何第三方依赖、注册表写入或系统服务安装。

## 卸载

```bash
# 删除脚本
rm 你的项目路径/mochi.ps1

# 清空 hooks 配置（或直接把整个 hooks 块删掉）
# 编辑 .claude/settings.json，删除 hooks 相关配置
```

无任何残留文件、注册表项或后台进程。

## 文件结构

```
你的项目/
├── .claude/
│   ├── settings.example.json   ← Hook 配置模板（GitHub）
│   └── settings.json           ← 你的本地配置（gitignore 排除）
├── mochi.ps1                   ← 通知脚本
├── .gitignore
└── README.md
```

## License

MIT
