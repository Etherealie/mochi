# mochi.ps1 - Claude Code Win11-style Notification via WPF

# ============================================================
# CUSTOMIZE
# ============================================================
$Title = "Mochi"
$DisplaySeconds = 5
$EnterDuration  = 400
$ExitDuration   = 250
$Sound = $false                 # set to $true to play a system sound on notification

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
# Read stdin
# ============================================================
$rawInput = [Console]::In.ReadToEnd()

# ============================================================
# Parse event JSON
# ============================================================
$ToolName     = ""
$FilePath     = ""
$EventMessage = ""

if ($rawInput -and $rawInput.Trim()) {
    try {
        $data = $rawInput | ConvertFrom-Json -ErrorAction Stop
        if ($data.tool_name) { $ToolName = $data.tool_name }
        if ($data.tool_input -and $data.tool_input.file_path) {
            $FilePath = $data.tool_input.file_path
        }
        if ($data.message) { $EventMessage = $data.message }
    } catch {
        $EventMessage = $rawInput.Substring(0, [Math]::Min(80, $rawInput.Length))
    }
}

$bodyText = Get-Body -ToolName $ToolName -FilePath $FilePath -EventMessage $EventMessage

# ============================================================
# WPF window
# ============================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Position near cursor (multi-monitor aware), DPI aware
Add-Type -AssemblyName System.Windows.Forms
$cursor  = [System.Windows.Forms.Cursor]::Position
$screen  = [System.Windows.Forms.Screen]::FromPoint($cursor)
$wa      = $screen.WorkingArea

# DPI factor: WinForms is in physical pixels, WPF is in logical units
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$dpiX = $g.DpiX / 96.0
$dpiY = $g.DpiY / 96.0
$g.Dispose()

$workWidth  = $wa.Width  / $dpiX
$workHeight = $wa.Height / $dpiY
$workLeft   = $wa.Left   / $dpiX
$workTop    = $wa.Top    / $dpiY

$window = New-Object System.Windows.Window
$window.Width  = 340
$window.Height = 90
$window.WindowStyle = 'None'
$window.AllowsTransparency = $true
$window.Background = 'Transparent'
$window.Topmost = $true
$window.ShowInTaskbar = $false
$window.WindowStartupLocation = 'Manual'

$targetLeft = $workLeft + $workWidth  - $window.Width  - 16
$targetTop  = $workTop  + $workHeight - $window.Height - 16

$window.Left   = $targetLeft
$window.Top    = $workTop + $workHeight + 40
$window.Opacity = 0

# Build visual tree
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

$stack.Children.Add($titleBlock) | Out-Null
$stack.Children.Add($bodyBlock)  | Out-Null
$border.Child = $stack
$window.Content = $border

# ============================================================
# Animation
# ============================================================
function New-DoubleAnimation {
    param($From, $To, $DurationMs, [string]$Easing = 'EaseOut')
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
    $anim.From = $From
    $anim.To   = $To
    $anim.Duration = [TimeSpan]::FromMilliseconds($DurationMs)
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = if ($Easing -eq 'EaseIn') {
        [System.Windows.Media.Animation.EasingMode]::EaseIn
    } else {
        [System.Windows.Media.Animation.EasingMode]::EaseOut
    }
    $anim.EasingFunction = $ease
    return $anim
}

$exiting = $false

function Invoke-ExitAnimation {
    if ($exiting) { return }
    $exiting = $true
    $timer.Stop()
    $slide = New-DoubleAnimation $window.Top ($workTop + $workHeight + 40) $ExitDuration 'EaseIn'
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

$window.Add_Loaded({
    if ($Sound) { [System.Media.SystemSounds]::Asterisk.Play() }
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

$border.Add_MouseLeftButtonDown({ Invoke-ExitAnimation })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds($DisplaySeconds)
$timer.Add_Tick({ Invoke-ExitAnimation })
$timer.Start()

$window.ShowDialog() | Out-Null
# Cleanup: process exits here, so event handlers don't strictly need unbinding,
# but explicit cleanup prevents edge cases with lingering dispatcher frames.
$timer.Stop()
$timer = $null
$window = $null
exit 0
