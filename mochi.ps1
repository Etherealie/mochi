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
# Animation settings
# ============================================================
$DisplaySeconds = 5
$EnterDuration  = 400   # ms, entrance slide + fade
$ExitDuration   = 250   # ms, exit fade

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
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$window = New-Object System.Windows.Window
$window.Width  = 340
$window.Height = 90
$window.WindowStyle = 'None'
$window.AllowsTransparency = $true
$window.Background = 'Transparent'
$window.Topmost = $true
$window.ShowInTaskbar = $false
$window.WindowStartupLocation = 'Manual'

# Target position: bottom-right of primary monitor
$workArea = [System.Windows.SystemParameters]::WorkArea
$targetLeft = $workArea.Width  - $window.Width  - 16
$targetTop  = $workArea.Height - $window.Height - 16

# Start below screen, invisible
$window.Left   = $targetLeft
$window.Top    = $workArea.Height + 40
$window.Opacity = 0

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
$window.Content = $border

# ============================================================
# Animation helpers
# ============================================================
function New-DoubleAnimation {
    param($From, $To, $DurationMs, [string]$Easing = 'EaseOut')
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
    $anim.From = $From
    $anim.To   = $To
    $anim.Duration = [TimeSpan]::FromMilliseconds($DurationMs)
    if ($Easing -eq 'EaseOut') {
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $anim.EasingFunction = $ease
    } elseif ($Easing -eq 'EaseIn') {
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseIn
        $anim.EasingFunction = $ease
    }
    return $anim
}

# Exit animation (fade out + slide down)
function Invoke-ExitAnimation {
    $slide = New-DoubleAnimation $window.Top ($workArea.Height + 40) $ExitDuration 'EaseIn'
    $fade  = New-DoubleAnimation $window.Opacity 0 $ExitDuration 'EaseIn'
    $propTop = New-Object System.Windows.PropertyPath("Top")
    $propOpacity = New-Object System.Windows.PropertyPath("Opacity")

    $sb = New-Object System.Windows.Media.Animation.Storyboard
    $sb.Children.Add($slide)
    $sb.Children.Add($fade)
    [System.Windows.Media.Animation.Storyboard]::SetTarget($slide, $window)
    [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($slide, $propTop)
    [System.Windows.Media.Animation.Storyboard]::SetTarget($fade, $window)
    [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fade, $propOpacity)
    $sb.Add_Completed({ $window.Close() })
    $sb.Begin()
}

# Entrance animation (slide up + fade in) on window loaded
$window.Add_Loaded({
    $slide = New-DoubleAnimation $window.Top $targetTop $EnterDuration 'EaseOut'
    $fade  = New-DoubleAnimation 0 1 $EnterDuration 'EaseOut'
    $propTop = New-Object System.Windows.PropertyPath("Top")
    $propOpacity = New-Object System.Windows.PropertyPath("Opacity")

    $sb = New-Object System.Windows.Media.Animation.Storyboard
    $sb.Children.Add($slide)
    $sb.Children.Add($fade)
    [System.Windows.Media.Animation.Storyboard]::SetTarget($slide, $window)
    [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($slide, $propTop)
    [System.Windows.Media.Animation.Storyboard]::SetTarget($fade, $window)
    [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fade, $propOpacity)
    $sb.Begin()
})

# Click to dismiss (with exit animation)
$border.Add_MouseLeftButtonDown({
    $timer.Stop()
    Invoke-ExitAnimation
})

# Auto-close timer
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds($DisplaySeconds)
$timer.Add_Tick({
    $timer.Stop()
    Invoke-ExitAnimation
})
$timer.Start()

# Show the window
$window.ShowDialog() | Out-Null

exit 0
