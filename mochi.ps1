# mochi.ps1 - Claude Code Win11-style Notification via WPF

# ============================================================
# CUSTOMIZE notification content
#   $ToolName     - e.g. "Write", "Edit", "Bash"
#   $FilePath     - file path (may be "")
#   $EventMessage - raw message from Claude Code (may be "")
# ============================================================
$Title = "Mochi"

function Get-Body {
    param($ToolName, $FilePath, $EventMessage)
    if ($ToolName) {
        $text = "Tool: $ToolName"
        if ($FilePath) { $text += "`nFile: $FilePath" }
        return $text
    }
    if ($EventMessage) { return $EventMessage }
    return "Response complete"
}

# ============================================================
# Implementation
# ============================================================

# Read event JSON from stdin
$rawInput = [Console]::In.ReadToEnd()
$ToolName     = ""
$FilePath     = ""
$EventMessage = ""

if ($rawInput) {
    try {
        $data = $rawInput | ConvertFrom-Json
        if ($data.tool_name) { $ToolName = $data.tool_name }
        if ($data.tool_input -and $data.tool_input.file_path) {
            $FilePath = $data.tool_input.file_path
        }
        if ($data.message) { $EventMessage = $data.message }
    } catch {}
}

$bodyText = Get-Body -ToolName $ToolName -FilePath $FilePath -EventMessage $EventMessage

# WPF mini notification window
Add-Type -AssemblyName PresentationFramework, WindowsBase

$window = New-Object System.Windows.Window
$window.Width  = 340
$window.Height = 90
$window.WindowStyle = 'None'
$window.AllowsTransparency = $true
$window.Background = 'Transparent'
$window.Topmost = $true
$window.ShowInTaskbar = $false
$window.WindowStartupLocation = 'Manual'

# Position at bottom-right of primary monitor
$workArea = [System.Windows.SystemParameters]::WorkArea
$window.Left = $workArea.Width  - $window.Width  - 16
$window.Top  = $workArea.Height - $window.Height - 16

# Build the visual tree
$border = New-Object System.Windows.Controls.Border
$border.CornerRadius = New-Object System.Windows.CornerRadius(8)
$border.Background = New-Object System.Windows.Media.SolidColorBrush("#E81A1A1A")
$border.BorderBrush = New-Object System.Windows.Media.SolidColorBrush("#33FFFFFF")
$border.BorderThickness = New-Object System.Windows.Thickness(1)

$stack = New-Object System.Windows.Controls.StackPanel
$stack.Margin = New-Object System.Windows.Thickness(16, 12, 16, 12)

$titleBlock = New-Object System.Windows.Controls.TextBlock
$titleBlock.Text = $Title
$titleBlock.Foreground = New-Object System.Windows.Media.SolidColorBrush("#FFFFFF")
$titleBlock.FontWeight = 'Bold'
$titleBlock.FontSize = 13

$bodyBlock = New-Object System.Windows.Controls.TextBlock
$bodyBlock.Text = $bodyText
$bodyBlock.Foreground = New-Object System.Windows.Media.SolidColorBrush("#CCCCCC")
$bodyBlock.FontSize = 12
$bodyBlock.TextWrapping = 'Wrap'
$bodyBlock.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
$bodyBlock.MaxHeight = 50

$stack.AddChild($titleBlock) | Out-Null
$stack.AddChild($bodyBlock)  | Out-Null
$border.Child = $stack
# Click to dismiss
$border.Add_MouseLeftButtonDown({ $window.Close() })
$window.Content = $border

# Auto-close via a dispatcher timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({ $window.Close() })
$timer.Start()

# Show the window (blocks PowerShell until timer closes it, but returns immediately for Claude Code)
$window.ShowDialog() | Out-Null

exit 0
