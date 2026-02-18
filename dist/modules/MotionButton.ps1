<#
.SYNOPSIS
    MotionButton Component - 基于OpenDoge MotionButton的增强按钮组件

.DESCRIPTION
    为PowerShell WinForms提供现代Web应用级别的按钮交互体验
    集成涟漪效果、悬停动画、点击反馈和加载状态动画

.VERSION
    1.0.0
.CREATED
    2026-02-16
.LAST_UPDATED
    2026-02-16
#>

# ============================================================
# 模块依赖检查
# ============================================================

# 检查必需的模块
$requiredModules = @(
    'EnhancedInteractions',
    'Theme'
)

foreach ($module in $requiredModules) {
    $modulePath = Join-Path $PSScriptRoot "$module.ps1"
    if (-not (Test-Path $modulePath)) {
        Write-SilentLog "Required module not found: $module" 'ERROR'
        throw "Required module not found: $module"
    }
}

# ============================================================
# MotionButton类定义
# ============================================================

<#
.SYNOPSIS
    MotionButton类 - 增强的动画按钮控件
#>
class MotionButton : System.Windows.Forms.Button {
    # 动画属性
    hidden [string]$AnimationId
    hidden [bool]$IsAnimating
    hidden [System.Windows.Forms.Timer]$RippleTimer
    hidden [System.Collections.ArrayList]$Ripples
    hidden [int]$RippleDuration = 600
    
    # 样式属性
    hidden [string]$Variant
    hidden [string]$Size
    hidden [bool]$ShowRipple
    hidden [bool]$ShowHover
    hidden [bool]$ShowTap
    hidden [bool]$FullWidth
    hidden [bool]$Loading
    
    # 颜色缓存
    hidden [System.Drawing.Color]$OriginalBackgroundColor
    hidden [System.Drawing.Color]$OriginalBorderColor
    
    # 构造函数
    MotionButton() : base() {
        $this.InitializeComponent()
    }
    
    # 带参数的构造函数
    MotionButton(
        [string]$Text,
        [string]$Variant = 'Primary',
        [string]$Size = 'md',
        [bool]$ShowRipple = $true,
        [bool]$ShowHover = $true,
        [bool]$ShowTap = $true,
        [bool]$FullWidth = $false
    ) : base() {
        $this.Text = $Text
        $this.Variant = $Variant
        $this.Size = $Size
        $this.ShowRipple = $ShowRipple
        $this.ShowHover = $ShowHover
        $this.ShowTap = $ShowTap
        $this.FullWidth = $FullWidth
        
        $this.InitializeComponent()
    }
    
    # 初始化组件
    hidden [void] InitializeComponent() {
        # 基础样式设置
        $this.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $this.Cursor = [System.Windows.Forms.Cursors]::Hand
        $this.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $this.UseVisualStyleBackColor = $false
        
        # 启用双缓冲以减少闪烁
        $this.GetType().GetProperty("DoubleBuffered", 
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($this, $true, $null)
        
        # 初始化涟漪效果集合
        $this.Ripples = [System.Collections.ArrayList]::new()
        
        # 初始化涟漪定时器
        $this.RippleTimer = New-Object System.Windows.Forms.Timer
        $this.RippleTimer.Interval = 16  # ~60 FPS
        $this.RippleTimer.add_Tick({
            $this.UpdateRipples()
        })
        
        # 应用初始样式
        $this.ApplyStyle()
        
        # 设置事件处理器
        $this.Add_MouseEnter($this.OnMouseEnter)
        $this.Add_MouseLeave($this.OnMouseLeave)
        $this.Add_MouseDown($this.OnMouseDown)
        $this.Add_MouseUp($this.OnMouseUp)
        $this.Add_Click($this.OnClick)
        $this.Add_Paint($this.OnPaint)
        
        Write-SilentLog "MotionButton initialized: $($this.Name)" 'DEBUG'
    }
    
    # 应用样式
    hidden [void] ApplyStyle() {
        # 应用基础样式
        Apply-NordicButton -Button $this -Style $this.Variant
        
        # 保存原始颜色
        $this.OriginalBackgroundColor = $this.BackColor
        $this.OriginalBorderColor = $this.FlatAppearance.BorderColor
        
        # 应用尺寸
        switch ($this.Size) {
            'sm' {
                $this.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, $global:NordicTheme.FontSizeSm)
                $this.Padding = New-Object System.Windows.Forms.Padding(6, 3, 6, 3)
                $this.Height = 32
            }
            'md' {
                $this.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, $global:NordicTheme.FontSizeSm)
                $this.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 6)
                $this.Height = 40
            }
            'lg' {
                $this.Font = New-Object System.Drawing.Font($global:NordicTheme.FontDefault, $global:NordicTheme.FontSizeBase)
                $this.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)
                $this.Height = 48
            }
        }
        
        # 全宽设置
        if ($this.FullWidth) {
            $this.Dock = [System.Windows.Forms.DockStyle]::Fill
        }
    }
    
    # 鼠标进入事件
    hidden [void] OnMouseEnter([object]$sender, [System.EventArgs]$e) {
        if ($this.Loading -or -not $this.Enabled) {
            return
        }
        
        if ($this.ShowHover) {
            $this.StartHoverAnimation()
        }
    }
    
    # 鼠标离开事件
    hidden [void] OnMouseLeave([object]$sender, [System.EventArgs]$e) {
        if ($this.Loading -or -not $this.Enabled) {
            return
        }
        
        if ($this.ShowHover) {
            $this.EndHoverAnimation()
        }
    }
    
    # 鼠标按下事件
    hidden [void] OnMouseDown([object]$sender, [System.Windows.Forms.MouseEventArgs]$e) {
        if ($this.Loading -or -not $this.Enabled) {
            return
        }
        
        if ($this.ShowTap) {
            $this.StartTapAnimation()
        }
    }
    
    # 鼠标释放事件
    hidden [void] OnMouseUp([object]$sender, [System.Windows.Forms.MouseEventArgs]$e) {
        if ($this.Loading -or -not $this.Enabled) {
            return
        }
        
        if ($this.ShowTap) {
            $this.EndTapAnimation()
        }
    }
    
    # 点击事件
    hidden [void] OnClick([object]$sender, [System.EventArgs]$e) {
        if ($this.Loading -or -not $this.Enabled) {
            return
        }
        
        # 添加涟漪效果
        if ($this.ShowRipple) {
            $this.AddRipple($this.PointToClient([System.Windows.Forms.Control]::MousePosition))
        }
    }
    
    # 绘制事件（用于绘制涟漪效果）
    hidden [void] OnPaint([object]$sender, [System.Windows.Forms.PaintEventArgs]$e) {
        # 调用基类绘制
        $this.InvokePaintBackground($this, $e)
        $this.InvokePaint($this, $e)
        
        # 绘制涟漪效果
        $this.DrawRipples($e.Graphics)
        
        # 绘制加载状态
        if ($this.Loading) {
            $this.DrawLoadingState($e.Graphics)
        }
    }
    
    # ============================================================
    # 动画功能
    # ============================================================
    
    # 开始悬停动画
    hidden [void] StartHoverAnimation() {
        try {
            # 使用EnhancedInteractions模块创建动画
            $animationId = "hover_$($this.Name)_$(Get-Date -Format 'HHmmssfff')"
            
            $scaleAnimation = New-TransformAnimation `
                -Id "$animationId-scale" `
                -Target $this `
                -FromValues @{ Size = @{ Width = $this.Width; Height = $this.Height } } `
                -ToValues @{ Size = @{ Width = [Math]::Round($this.Width * 1.02); Height = [Math]::Round($this.Height * 1.02) } } `
                -Duration 150 `
                -Easing 'EaseOut'
            
            $colorAnimation = New-PropertyAnimation `
                -Id "$animationId-color" `
                -Target $this `
                -PropertyName 'BackColor' `
                -FromValue $this.OriginalBackgroundColor `
                -ToValue (Adjust-Brightness $this.OriginalBackgroundColor 15) `
                -Duration 150 `
                -Easing 'EaseOut'
            
            # 启动动画
            Start-Animation -Animation $scaleAnimation
            Start-Animation -Animation $colorAnimation
            
            $this.AnimationId = $animationId
            $this.IsAnimating = $true
            
            Write-SilentLog "Hover animation started for $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to start hover animation: $_" 'DEBUG'
        }
    }
    
    # 结束悬停动画
    hidden [void] EndHoverAnimation() {
        try {
            if ($this.IsAnimating) {
                # 停止之前的动画
                if ($this.AnimationId) {
                    Stop-Animation -AnimationId "$($this.AnimationId)-scale"
                    Stop-Animation -AnimationId "$($this.AnimationId)-color"
                }
                
                # 恢复到原始状态
                $restoreAnimation = New-PropertyAnimation `
                    -Id "restore_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                    -Target $this `
                    -PropertyName 'BackColor' `
                    -FromValue $this.BackColor `
                    -ToValue $this.OriginalBackgroundColor `
                    -Duration 150 `
                    -Easing 'EaseOut'
                
                $restoreSizeAnimation = New-TransformAnimation `
                    -Id "restore-size_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                    -Target $this `
                    -FromValues @{ Size = @{ Width = $this.Width; Height = $this.Height } } `
                    -ToValues @{ Size = @{ Width = [Math]::Round($this.Width / 1.02); Height = [Math]::Round($this.Height / 1.02) } } `
                    -Duration 150 `
                    -Easing 'EaseOut'
                
                Start-Animation -Animation $restoreAnimation
                Start-Animation -Animation $restoreSizeAnimation
                
                $this.IsAnimating = $false
                
                Write-SilentLog "Hover animation ended for $($this.Name)" 'DEBUG'
            }
        }
        catch {
            Write-SilentLog "Failed to end hover animation: $_" 'DEBUG'
        }
    }
    
    # 开始点击动画
    hidden [void] StartTapAnimation() {
        try {
            $tapAnimation = New-TransformAnimation `
                -Id "tap_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                -Target $this `
                -FromValues @{ Size = @{ Width = $this.Width; Height = $this.Height } } `
                -ToValues @{ Size = @{ Width = [Math]::Round($this.Width * 0.98); Height = [Math]::Round($this.Height * 0.98) } } `
                -Duration 100 `
                -Easing 'EaseOut'
            
            $colorAnimation = New-PropertyAnimation `
                -Id "tap-color_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                -Target $this `
                -PropertyName 'BackColor' `
                -FromValue $this.BackColor `
                -ToValue (Adjust-Brightness $this.BackColor -20) `
                -Duration 100 `
                -Easing 'EaseOut'
            
            Start-Animation -Animation $tapAnimation
            Start-Animation -Animation $colorAnimation
            
            Write-SilentLog "Tap animation started for $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to start tap animation: $_" 'DEBUG'
        }
    }
    
    # 结束点击动画
    hidden [void] EndTapAnimation() {
        try {
            # 恢复到悬停状态或原始状态
            if ($this.ClientRectangle.Contains($this.PointToClient([System.Windows.Forms.Control]::MousePosition))) {
                # 鼠标仍在按钮上，恢复到悬停状态
                $restoreAnimation = New-TransformAnimation `
                    -Id "tap-restore_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                    -Target $this `
                    -FromValues @{ Size = @{ Width = $this.Width; Height = $this.Height } } `
                    -ToValues @{ Size = @{ Width = [Math]::Round($this.Width / 0.98 * 1.02); Height = [Math]::Round($this.Height / 0.98 * 1.02) } } `
                    -Duration 100 `
                    -Easing 'EaseOut'
                
                $restoreColorAnimation = New-PropertyAnimation `
                    -Id "tap-restore-color_$($this.Name)_$(Get-Date -Format 'HHmmssfff')" `
                    -Target $this `
                    -PropertyName 'BackColor' `
                    -FromValue $this.BackColor `
                    -ToValue (Adjust-Brightness $this.OriginalBackgroundColor 15) `
                    -Duration 100 `
                    -Easing 'EaseOut'
                
                Start-Animation -Animation $restoreAnimation
                Start-Animation -Animation $restoreColorAnimation
            } else {
                # 鼠标已离开，恢复到原始状态
                $this.EndHoverAnimation()
            }
            
            Write-SilentLog "Tap animation ended for $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to end tap animation: $_" 'DEBUG'
        }
    }
    
    # ============================================================
    # 涟漪效果功能
    # ============================================================
    
    # 添加涟漪效果
    hidden [void] AddRipple([System.Drawing.Point]$location) {
        try {
            $ripple = @{
                Location = $location
                Radius = 0
                MaxRadius = [Math]::Max($this.Width, $this.Height) * 2
                Opacity = 0.3
                StartTime = [DateTime]::Now
                Id = [Guid]::NewGuid().ToString()
            }
            
            $this.Ripples.Add($ripple) | Out-Null
            
            # 启动涟漪定时器（如果未启动）
            if (-not $this.RippleTimer.Enabled) {
                $this.RippleTimer.Start()
            }
            
            Write-SilentLog "Ripple added at ($($location.X), $($location.Y))" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to add ripple: $_" 'DEBUG'
        }
    }
    
    # 更新涟漪效果
    hidden [void] UpdateRipples() {
        try {
            $currentTime = [DateTime]::Now
            $ripplesToRemove = @()
            
            # 更新每个涟漪
            for ($i = 0; $i -lt $this.Ripples.Count; $i++) {
                $ripple = $this.Ripples[$i]
                
                # 计算经过的时间
                $elapsedTime = ($currentTime - $ripple.StartTime).TotalMilliseconds
                $progress = $elapsedTime / $this.RippleDuration
                
                if ($progress -ge 1) {
                    # 涟漪已完成，标记为待移除
                    $ripplesToRemove += $i
                } else {
                    # 更新涟漪半径和透明度
                    $ripple.Radius = $ripple.MaxRadius * $progress
                    $ripple.Opacity = 0.3 * (1 - $progress)
                    
                    $this.Ripples[$i] = $ripple
                }
            }
            
            # 移除已完成的涟漪（从后往前移除以避免索引问题）
            for ($i = $ripplesToRemove.Count - 1; $i -ge 0; $i--) {
                $this.Ripples.RemoveAt($ripplesToRemove[$i])
            }
            
            # 重绘按钮以显示涟漪
            $this.Invalidate()
            
            # 如果没有涟漪了，停止定时器
            if ($this.Ripples.Count -eq 0) {
                $this.RippleTimer.Stop()
            }
        }
        catch {
            Write-SilentLog "Failed to update ripples: $_" 'DEBUG'
        }
    }
    
    # 绘制涟漪效果
    hidden [void] DrawRipples([System.Drawing.Graphics]$graphics) {
        if ($this.Ripples.Count -eq 0) {
            return
        }
        
        try {
            # 设置高质量渲染
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            
            foreach ($ripple in $this.Ripples) {
                # 创建涟漪画笔
                $rippleColor = [System.Drawing.Color]::FromArgb(
                    [int]($ripple.Opacity * 255),
                    $this.OriginalBackgroundColor.R,
                    $this.OriginalBackgroundColor.G,
                    $this.OriginalBackgroundColor.B
                )
                
                $rippleBrush = New-Object System.Drawing.SolidBrush($rippleColor)
                
                # 绘制涟漪圆圈
                $x = $ripple.Location.X - $ripple.Radius / 2
                $y = $ripple.Location.Y - $ripple.Radius / 2
                
                $graphics.FillEllipse($rippleBrush, $x, $y, $ripple.Radius, $ripple.Radius)
                
                # 释放资源
                $rippleBrush.Dispose()
            }
        }
        catch {
            Write-SilentLog "Failed to draw ripples: $_" 'DEBUG'
        }
    }
    
    # ============================================================
    # 加载状态功能
    # ============================================================
    
    # 设置加载状态
    [void] SetLoading([bool]$loading) {
        $this.Loading = $loading
        
        if ($loading) {
            # 禁用按钮交互
            $this.Enabled = $false
            $this.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            
            # 开始加载动画
            $this.StartLoadingAnimation()
        } else {
            # 启用按钮交互
            $this.Enabled = $true
            $this.Cursor = [System.Windows.Forms.Cursors]::Hand
            
            # 停止加载动画
            $this.StopLoadingAnimation()
        }
        
        # 重绘以显示/隐藏加载状态
        $this.Invalidate()
    }
    
    # 开始加载动画
    hidden [void] StartLoadingAnimation() {
        # 加载动画在绘制时处理
        Write-SilentLog "Loading animation started for $($this.Name)" 'DEBUG'
    }
    
    # 停止加载动画
    hidden [void] StopLoadingAnimation() {
        Write-SilentLog "Loading animation stopped for $($this.Name)" 'DEBUG'
    }
    
    # 绘制加载状态
    hidden [void] DrawLoadingState([System.Drawing.Graphics]$graphics) {
        try {
            # 创建半透明覆盖层
            $overlayBrush = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb(128, $this.BackColor)
            )
            
            $graphics.FillRectangle($overlayBrush, $this.ClientRectangle)
            $overlayBrush.Dispose()
            
            # 绘制旋转加载指示器
            $centerX = $this.Width / 2
            $centerY = $this.Height / 2
            $radius = [Math]::Min($this.Width, $this.Height) / 4
            
            # 计算旋转角度（基于时间）
            $angle = ([DateTime]::Now - [DateTime]::Today).TotalSeconds * 360 % 360
            
            # 创建加载指示器画笔
            $spinnerBrush = New-Object System.Drawing.SolidBrush($this.ForeColor)
            
            # 绘制旋转扇形
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.FillPie(
                $spinnerBrush,
                $centerX - $radius,
                $centerY - $radius,
                $radius * 2,
                $radius * 2,
                $angle,
                90  # 扇形角度
            )
            
            $spinnerBrush.Dispose()
        }
        catch {
            Write-SilentLog "Failed to draw loading state: $_" 'DEBUG'
        }
    }
    
    # ============================================================
    # 公共方法
    # ============================================================
    
    # 设置按钮变体
    [void] SetVariant([string]$variant) {
        $this.Variant = $variant
        $this.ApplyStyle()
    }
    
    # 设置按钮尺寸
    [void] SetSize([string]$size) {
        $this.Size = $size
        $this.ApplyStyle()
    }
    
    # 设置全宽
    [void] SetFullWidth([bool]$fullWidth) {
        $this.FullWidth = $fullWidth
        $this.ApplyStyle()
    }
    
    # 清理资源
    [void] Dispose() {
        try {
            # 停止所有动画
            if ($this.IsAnimating -and $this.AnimationId) {
                Stop-Animation -AnimationId "$($this.AnimationId)-scale"
                Stop-Animation -AnimationId "$($this.AnimationId)-color"
            }
            
            # 停止涟漪定时器
            if ($this.RippleTimer.Enabled) {
                $this.RippleTimer.Stop()
            }
            
            $this.RippleTimer.Dispose()
            
            # 清理涟漪集合
            $this.Ripples.Clear()
            
            Write-SilentLog "MotionButton disposed: $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to dispose MotionButton: $_" 'DEBUG'
        }
        
        # 调用基类清理
        $this.base.Dispose()
    }
}

# ============================================================
# 工厂函数
# ============================================================

<#
.SYNOPSIS
    创建MotionButton实例
#>
function New-MotionButton {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Text = "Button",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Primary', 'Secondary', 'Ghost', 'Success', 'Warning', 'Error', 'Info')]
        [string]$Variant = 'Primary',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('sm', 'md', 'lg')]
        [string]$Size = 'md',
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowRipple = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowHover = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowTap = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$FullWidth = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "MotionButton_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    try {
        $button = [MotionButton]::new($Text, $Variant, $Size, $ShowRipple, $ShowHover, $ShowTap, $FullWidth)
        $button.Name = $Name
        
        Write-SilentLog "MotionButton created: $Name" 'DEBUG'
        return $button
    }
    catch {
        Write-SilentLog "Failed to create MotionButton: $_" 'ERROR'
        throw "Failed to create MotionButton: $_"
    }
}

<#
.SYNOPSIS
    创建图标按钮
#>
function New-MotionIconButton {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Icon = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$Label = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Primary', 'Secondary', 'Ghost', 'Success', 'Warning', 'Error', 'Info')]
        [string]$Variant = 'Primary',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('sm', 'md', 'lg')]
        [string]$Size = 'md'
    )
    
    try {
        $button = New-MotionButton -Variant $Variant -Size $Size
        
        # 如果有图标，添加到按钮
        if ($null -ne $Icon) {
            if ($Icon -is [System.Drawing.Image]) {
                $button.Image = $Icon
                $button.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
                $button.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
            }
        }
        
        # 设置文本
        if ($Label) {
            $button.Text = $Label
        }
        
        Write-SilentLog "MotionIconButton created: $($button.Name)" 'DEBUG'
        return $button
    }
    catch {
        Write-SilentLog "Failed to create MotionIconButton: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    创建按钮组
#>
function New-MotionButtonGroup {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Buttons,
        
        [Parameter(Mandatory = $false)]
        [int]$Spacing = 8,
        
        [Parameter(Mandatory = $false)]
        [bool]$Connected = $false
    )
    
    try {
        $container = New-Object System.Windows.Forms.Panel
        $container.AutoSize = $true
        
        $xPos = 0
        
        foreach ($button in $Buttons) {
            if ($button -is [MotionButton]) {
                $button.Location = New-Object System.Drawing.Point($xPos, 0)
                
                if ($Connected) {
                    # 移除边框重叠
                    $button.FlatAppearance.BorderSize = 1
                    
                    if ($xPos -gt 0) {
                        # 从第二个按钮开始，移除左侧圆角
                        $button.FlatAppearance.BorderColor = $button.OriginalBorderColor
                    }
                }
                
                $container.Controls.Add($button)
                $xPos += $button.Width + $Spacing
            }
        }
        
        # 调整容器大小
        $container.Width = $xPos - $Spacing
        $container.Height = if ($Buttons.Count -gt 0) { $Buttons[0].Height } else { 40 }
        
        Write-SilentLog "MotionButtonGroup created with $($Buttons.Count) buttons" 'DEBUG'
        return $container
    }
    catch {
        Write-SilentLog "Failed to create MotionButtonGroup: $_" 'ERROR'
        throw
    }
}

# ============================================================
# 辅助函数
# ============================================================

<#
.SYNOPSIS
    调整颜色亮度（复制自Theme.ps1以确保可用性）
#>
function Adjust-Brightness {
    param(
        [System.Drawing.Color]$Color,
        [int]$Percent
    )
    
    $percent = [Math]::Max(-100, [Math]::Min(100, $Percent))
    $factor = 1 + ($percent / 100.0)
    
    $r = [Math]::Min(255, [Math]::Max(0, [int]($Color.R * $factor)))
    $g = [Math]::Min(255, [Math]::Max(0, [int]($Color.G * $factor)))
    $b = [Math]::Min(255, [Math]::Max(0, [int]($Color.B * $factor)))
    
    return [System.Drawing.Color]::FromArgb($Color.A, $r, $g, $b)
}

# ============================================================
# 模块初始化
# ============================================================

try {
    Write-SilentLog "MotionButton Module v1.0.0 loaded successfully" 'INFO'
}
catch {
    Write-SilentLog "Failed to initialize MotionButton module: $_" 'ERROR'
}

# 导出函数
$functionList = @(
    'New-MotionButton',
    'New-MotionIconButton',
    'New-MotionButtonGroup'
)