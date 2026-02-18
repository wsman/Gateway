<#
.SYNOPSIS
    RollingNumber Component - 基于OpenDoge RollingNumber的数字滚动动画组件

.DESCRIPTION
    为PowerShell WinForms提供现代Web应用级别的数字滚动动画效果
    实现平滑数字过渡、逐字符动画、方向指示和格式化支持

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
# RollingNumber类定义
# ============================================================

<#
.SYNOPSIS
    RollingNumber类 - 数字滚动动画控件
#>
class RollingNumber : System.Windows.Forms.Label {
    # 动画属性
    hidden [float]$CurrentValue
    hidden [float]$TargetValue
    hidden [float]$PreviousValue
    hidden [bool]$IsAnimating
    hidden [bool]$IsIncreasing
    hidden [System.Windows.Forms.Timer]$AnimationTimer
    hidden [int]$AnimationDuration
    hidden [string]$EasingType
    hidden [datetime]$AnimationStartTime
    
    # 格式化属性
    hidden [hashtable]$FormatOptions
    hidden [int]$Decimals
    hidden [string]$Prefix
    hidden [string]$Suffix
    hidden [string]$DisplayFormat
    hidden [bool]$ShowDirectionIndicator
    hidden [string]$IndicatorSize
    
    # 状态跟踪
    hidden [System.Collections.ArrayList]$CharacterAnimations
    hidden [System.Drawing.Font]$BaseFont
    hidden [System.Drawing.Color]$BaseColor
    hidden [System.Drawing.Color]$IncreaseColor
    hidden [System.Drawing.Color]$DecreaseColor
    
    # 构造函数
    RollingNumber() : base() {
        $this.InitializeComponent()
    }
    
    # 带参数的构造函数
    RollingNumber(
        [float]$Value = 0,
        [hashtable]$FormatOptions = $null,
        [int]$Decimals = 2,
        [string]$Prefix = '',
        [string]$Suffix = '',
        [bool]$Animate = $true,
        [int]$Duration = 500,
        [string]$Easing = 'easeOut',
        [bool]$ShowDirectionIndicator = $true,
        [string]$IndicatorSize = 'sm'
    ) : base() {
        $this.CurrentValue = $Value
        $this.TargetValue = $Value
        $this.PreviousValue = $Value
        $this.AnimationDuration = $Duration
        $this.EasingType = $Easing
        
        $this.FormatOptions = if ($FormatOptions) { $FormatOptions } else { @{} }
        $this.Decimals = $Decimals
        $this.Prefix = $Prefix
        $this.Suffix = $Suffix
        $this.ShowDirectionIndicator = $ShowDirectionIndicator
        $this.IndicatorSize = $IndicatorSize
        
        $this.InitializeComponent()
    }
    
    # 初始化组件
    hidden [void] InitializeComponent() {
        # 基础样式设置
        $this.AutoSize = $true
        $this.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $this.Text = $this.FormatValue($this.CurrentValue)
        
        # 保存基础字体和颜色
        $this.BaseFont = $this.Font
        $this.BaseColor = $this.ForeColor
        $this.IncreaseColor = $global:NordicTheme.StatusSuccess
        $this.DecreaseColor = $global:NordicTheme.StatusError
        
        # 初始化字符动画集合
        $this.CharacterAnimations = [System.Collections.ArrayList]::new()
        
        # 初始化动画定时器
        $this.AnimationTimer = New-Object System.Windows.Forms.Timer
        $this.AnimationTimer.Interval = 16  # ~60 FPS
        $this.AnimationTimer.add_Tick({
            $this.UpdateAnimation()
        })
        
        # 设置绘制事件
        $this.Add_Paint($this.OnPaint)
        
        Write-SilentLog "RollingNumber initialized: $($this.Name) [Value: $($this.CurrentValue)]" 'DEBUG'
    }
    
    # ============================================================
    # 格式化功能
    # ============================================================
    
    # 格式化数字
    hidden [string] FormatValue([float]$value) {
        $formattedValue = $value.ToString("F$($this.Decimals)")
        
        # 应用千位分隔符
        if ($this.FormatOptions.ContainsKey('UseGrouping') -and $this.FormatOptions.UseGrouping) {
            $formattedValue = $this.AddThousandSeparator($formattedValue)
        }
        
        # 应用百分比格式
        if ($this.FormatOptions.ContainsKey('Style') -and $this.FormatOptions.Style -eq 'percent') {
            $formattedValue = ($value * 100).ToString("F$($this.Decimals)") + '%'
        }
        
        # 应用货币格式
        if ($this.FormatOptions.ContainsKey('Style') -and $this.FormatOptions.Style -eq 'currency') {
            $currencySymbol = if ($this.FormatOptions.ContainsKey('Currency')) { $this.FormatOptions.Currency } else { '$' }
            $formattedValue = $currencySymbol + $formattedValue
        }
        
        # 添加前缀和后缀
        $result = $this.Prefix + $formattedValue + $this.Suffix
        
        return $result
    }
    
    # 添加千位分隔符
    hidden [string] AddThousandSeparator([string]$value) {
        # 分离整数和小数部分
        $parts = $value.Split('.')
        $integerPart = $parts[0]
        $decimalPart = if ($parts.Count -gt 1) { '.' + $parts[1] } else { '' }
        
        # 添加千位分隔符
        $result = ''
        $count = 0
        
        for ($i = $integerPart.Length - 1; $i -ge 0; $i--) {
            $result = $integerPart[$i] + $result
            $count++
            
            if ($count -eq 3 -and $i -gt 0) {
                $result = ',' + $result
                $count = 0
            }
        }
        
        return $result + $decimalPart
    }
    
    # ============================================================
    # 动画功能
    # ============================================================
    
    # 设置新值（启动动画）
    [void] SetValue([float]$newValue, [bool]$animate = $true) {
        if ($newValue -eq $this.TargetValue) {
            return
        }
        
        $this.PreviousValue = $this.CurrentValue
        $this.TargetValue = $newValue
        $this.IsIncreasing = $newValue -gt $this.CurrentValue
        
        if ($animate) {
            $this.StartAnimation()
        } else {
            $this.CurrentValue = $newValue
            $this.Text = $this.FormatValue($newValue)
            $this.Invalidate()
        }
        
        Write-SilentLog "RollingNumber value set: $($this.Name) from $($this.PreviousValue) to $newValue" 'DEBUG'
    }
    
    # 开始动画
    hidden [void] StartAnimation() {
        if ($this.IsAnimating) {
            $this.AnimationTimer.Stop()
            $this.IsAnimating = $false
        }
        
        $this.AnimationStartTime = [DateTime]::Now
        $this.IsAnimating = $true
        $this.AnimationTimer.Start()
        
        # 初始化字符动画
        $this.InitializeCharacterAnimations()
        
        Write-SilentLog "Animation started for $($this.Name)" 'DEBUG'
    }
    
    # 停止动画
    hidden [void] StopAnimation() {
        if ($this.IsAnimating) {
            $this.AnimationTimer.Stop()
            $this.IsAnimating = $false
            $this.CurrentValue = $this.TargetValue
            $this.Text = $this.FormatValue($this.CurrentValue)
            
            Write-SilentLog "Animation stopped for $($this.Name)" 'DEBUG'
        }
    }
    
    # 更新动画
    hidden [void] UpdateAnimation() {
        $elapsedTime = ([DateTime]::Now - $this.AnimationStartTime).TotalMilliseconds
        $progress = [Math]::Min($elapsedTime / $this.AnimationDuration, 1.0)
        
        # 应用缓动函数
        $easedProgress = $this.ApplyEasing($progress)
        
        # 计算当前值
        $this.CurrentValue = $this.PreviousValue + ($this.TargetValue - $this.PreviousValue) * $easedProgress
        
        # 更新显示文本
        $this.Text = $this.FormatValue($this.CurrentValue)
        
        # 更新字符动画
        $this.UpdateCharacterAnimations($easedProgress)
        
        # 重绘控件
        $this.Invalidate()
        
        # 检查动画是否完成
        if ($progress -ge 1.0) {
            $this.StopAnimation()
            
            # 触发完成事件
            if ($null -ne $this.OnAnimationComplete) {
                $this.OnAnimationComplete.Invoke($this, [System.EventArgs]::Empty)
            }
        }
    }
    
    # 应用缓动函数
    hidden [float] ApplyEasing([float]$progress) {
        switch ($this.EasingType) {
            'linear' {
                return $progress
            }
            'easeIn' {
                return $progress * $progress * $progress
            }
            'easeOut' {
                $progress = $progress - 1
                return $progress * $progress * $progress + 1
            }
            'easeInOut' {
                if ($progress < 0.5) {
                    return 4 * $progress * $progress * $progress
                } else {
                    $progress = $progress - 1
                    return 1 - (-2 * $progress) * (-2 * $progress) / 2
                }
            }
            'spring' {
                return 1 - [Math]::Exp(-0.5 * $progress) * [Math]::Cos($progress * 5)
            }
            default {
                return $progress
            }
        }
    }
    
    # ============================================================
    # 字符动画功能
    # ============================================================
    
    # 初始化字符动画
    hidden [void] InitializeCharacterAnimations() {
        $this.CharacterAnimations.Clear()
        
        $formattedText = $this.FormatValue($this.TargetValue)
        $characterCount = $formattedText.Length
        
        for ($i = 0; $i -lt $characterCount; $i++) {
            $animation = @{
                Index = $i
                Character = $formattedText[$i]
                OffsetY = if ($this.IsIncreasing) { 20 } else { -20 }
                Opacity = 0
                Scale = 0.8
                Delay = $i * 0.03  # 每个字符延迟30毫秒
                IsDigit = $false
            }
            
            # 检查是否为数字字符
            if ($formattedText[$i] -match '^[0-9\.\,\%\$]$') {
                $animation.IsDigit = $true
            }
            
            $this.CharacterAnimations.Add($animation) | Out-Null
        }
    }
    
    # 更新字符动画
    hidden [void] UpdateCharacterAnimations([float]$progress) {
        foreach ($animation in $this.CharacterAnimations) {
            # 计算字符动画进度（考虑延迟）
            $charProgress = [Math]::Max(0, ($progress - $animation.Delay) / (1 - $animation.Delay))
            
            if ($charProgress -gt 0) {
                # 应用弹簧动画效果
                $springProgress = 1 - [Math]::Exp(-5 * $charProgress) * [Math]::Cos($charProgress * 10)
                
                # 更新动画属性
                $animation.OffsetY = if ($this.IsIncreasing) { 
                    20 * (1 - $springProgress) 
                } else { 
                    -20 * (1 - $springProgress) 
                }
                
                $animation.Opacity = $springProgress
                $animation.Scale = 0.8 + (0.2 * $springProgress)
            }
        }
    }
    
    # ============================================================
    # 绘制功能
    # ============================================================
    
    # 绘制事件
    hidden [void] OnPaint([object]$sender, [System.Windows.Forms.PaintEventArgs]$e) {
        # 设置高质量渲染
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        
        # 清空背景
        $e.Graphics.Clear($this.BackColor)
        
        if ($this.IsAnimating -and $this.CharacterAnimations.Count -gt 0) {
            $this.DrawAnimatedCharacters($e.Graphics)
        } else {
            $this.DrawStaticText($e.Graphics)
        }
        
        # 绘制方向指示器
        if ($this.ShowDirectionIndicator -and $this.IsAnimating) {
            $this.DrawDirectionIndicator($e.Graphics)
        }
        
        # 绘制背景脉冲效果
        if ($this.IsAnimating) {
            $this.DrawPulseEffect($e.Graphics)
        }
    }
    
    # 绘制静态文本
    hidden [void] DrawStaticText([System.Drawing.Graphics]$graphics) {
        $textBrush = New-Object System.Drawing.SolidBrush($this.BaseColor)
        $graphics.DrawString($this.Text, $this.Font, $textBrush, 0, 0)
        $textBrush.Dispose()
    }
    
    # 绘制动画字符
    hidden [void] DrawAnimatedCharacters([System.Drawing.Graphics]$graphics) {
        $currentX = 0
        $fontHeight = $this.Font.Height
        
        foreach ($animation in $this.CharacterAnimations) {
            # 创建字符字体
            $charFont = New-Object System.Drawing.Font(
                $this.Font.FontFamily,
                $this.Font.Size * $animation.Scale,
                $this.Font.Style
            )
            
            # 确定字符颜色
            $charColor = if ($animation.IsDigit) {
                # 数字字符使用方向颜色
                if ($this.IsIncreasing) {
                    $this.IncreaseColor
                } else {
                    $this.DecreaseColor
                }
            } else {
                # 非数字字符使用基础颜色
                $this.BaseColor
            }
            
            # 应用透明度
            $charColor = [System.Drawing.Color]::FromArgb(
                [int]($animation.Opacity * 255),
                $charColor.R,
                $charColor.G,
                $charColor.B
            )
            
            # 创建字符画笔
            $charBrush = New-Object System.Drawing.SolidBrush($charColor)
            
            # 计算字符位置
            $charSize = $graphics.MeasureString($animation.Character.ToString(), $charFont)
            $charY = $animation.OffsetY
            
            # 绘制字符
            $graphics.DrawString(
                $animation.Character.ToString(),
                $charFont,
                $charBrush,
                $currentX,
                $charY
            )
            
            # 绘制字符阴影（增强立体感）
            if ($animation.IsDigit) {
                $shadowColor = [System.Drawing.Color]::FromArgb(
                    [int]($animation.Opacity * 50),
                    0, 0, 0
                )
                
                $shadowBrush = New-Object System.Drawing.SolidBrush($shadowColor)
                $graphics.DrawString(
                    $animation.Character.ToString(),
                    $charFont,
                    $shadowBrush,
                    $currentX + 1,
                    $charY + 1
                )
                $shadowBrush.Dispose()
            }
            
            # 更新X位置
            $currentX += $charSize.Width
            
            # 清理资源
            $charBrush.Dispose()
            $charFont.Dispose()
        }
        
        # 更新控件宽度
        $this.Width = [Math]::Ceiling($currentX)
    }
    
    # 绘制方向指示器
    hidden [void] DrawDirectionIndicator([System.Drawing.Graphics]$graphics) {
        $indicatorSize = switch ($this.IndicatorSize) {
            'sm' { 12 }
            'md' { 16 }
            'lg' { 20 }
            default { 12 }
        }
        
        $indicatorX = $this.Width + 5
        $indicatorY = ($this.Height - $indicatorSize) / 2
        
        # 指示器字符
        $indicatorChar = if ($this.IsIncreasing) { '↑' } else { '↓' }
        
        # 指示器颜色
        $indicatorColor = if ($this.IsIncreasing) {
            $this.IncreaseColor
        } else {
            $this.DecreaseColor
        }
        
        # 创建指示器字体
        $indicatorFont = New-Object System.Drawing.Font(
            $this.Font.FontFamily,
            $indicatorSize,
            [System.Drawing.FontStyle]::Bold
        )
        
        # 创建指示器画笔
        $indicatorBrush = New-Object System.Drawing.SolidBrush($indicatorColor)
        
        # 绘制指示器
        $graphics.DrawString(
            $indicatorChar,
            $indicatorFont,
            $indicatorBrush,
            $indicatorX,
            $indicatorY
        )
        
        # 清理资源
        $indicatorBrush.Dispose()
        $indicatorFont.Dispose()
    }
    
    # 绘制脉冲效果
    hidden [void] DrawPulseEffect([System.Drawing.Graphics]$graphics) {
        $pulseProgress = ([DateTime]::Now - $this.AnimationStartTime).TotalMilliseconds / $this.AnimationDuration
        $pulseProgress = [Math]::Min($pulseProgress, 1.0)
        
        # 计算脉冲半径
        $pulseRadius = $this.Width * 0.1 + ($this.Width * 0.2 * $pulseProgress)
        $pulseX = $this.Width / 2
        $pulseY = $this.Height / 2
        
        # 计算脉冲颜色
        $pulseColor = if ($this.IsIncreasing) {
            $this.IncreaseColor
        } else {
            $this.DecreaseColor
        }
        
        $pulseColor = [System.Drawing.Color]::FromArgb(
            [int]((1 - $pulseProgress) * 30),
            $pulseColor.R,
            $pulseColor.G,
            $pulseColor.B
        )
        
        # 创建脉冲画笔
        $pulseBrush = New-Object System.Drawing.SolidBrush($pulseColor)
        
        # 绘制脉冲圆
        $graphics.FillEllipse(
            $pulseBrush,
            $pulseX - $pulseRadius / 2,
            $pulseY - $pulseRadius / 2,
            $pulseRadius,
            $pulseRadius
        )
        
        # 清理资源
        $pulseBrush.Dispose()
    }
    
    # ============================================================
    # 公共方法
    # ============================================================
    
    # 获取当前值
    [float] GetValue() {
        return $this.CurrentValue
    }
    
    # 获取目标值
    [float] GetTargetValue() {
        return $this.TargetValue
    }
    
    # 设置动画持续时间
    [void] SetAnimationDuration([int]$duration) {
        $this.AnimationDuration = [Math]::Max(100, [Math]::Min(5000, $duration))
        Write-SilentLog "Animation duration set to $($this.AnimationDuration)ms for $($this.Name)" 'DEBUG'
    }
    
    # 设置缓动类型
    [void] SetEasingType([string]$easing) {
        $validEasingTypes = @('linear', 'easeIn', 'easeOut', 'easeInOut', 'spring')
        if ($validEasingTypes -contains $easing) {
            $this.EasingType = $easing
            Write-SilentLog "Easing type set to $easing for $($this.Name)" 'DEBUG'
        } else {
            Write-SilentLog "Invalid easing type: $easing. Using default (easeOut)." 'WARN'
            $this.EasingType = 'easeOut'
        }
    }
    
    # 设置格式化选项
    [void] SetFormatOptions(
        [hashtable]$options,
        [int]$decimals = $null,
        [string]$prefix = $null,
        [string]$suffix = $null
    ) {
        if ($options) {
            $this.FormatOptions = $options
        }
        
        if ($null -ne $decimals) {
            $this.Decimals = $decimals
        }
        
        if ($null -ne $prefix) {
            $this.Prefix = $prefix
        }
        
        if ($null -ne $suffix) {
            $this.Suffix = $suffix
        }
        
        # 更新显示
        $this.Text = $this.FormatValue($this.CurrentValue)
        $this.Invalidate()
        
        Write-SilentLog "Format options updated for $($this.Name)" 'DEBUG'
    }
    
    # 设置方向指示器
    [void] SetDirectionIndicator([bool]$show, [string]$size = $null) {
        $this.ShowDirectionIndicator = $show
        
        if ($null -ne $size) {
            $validSizes = @('sm', 'md', 'lg')
            if ($validSizes -contains $size) {
                $this.IndicatorSize = $size
            }
        }
        
        $this.Invalidate()
        Write-SilentLog "Direction indicator updated for $($this.Name)" 'DEBUG'
    }
    
    # 设置颜色主题
    [void] SetColorTheme(
        [System.Drawing.Color]$increaseColor = $null,
        [System.Drawing.Color]$decreaseColor = $null
    ) {
        if ($null -ne $increaseColor) {
            $this.IncreaseColor = $increaseColor
        }
        
        if ($null -ne $decreaseColor) {
            $this.DecreaseColor = $decreaseColor
        }
        
        $this.Invalidate()
        Write-SilentLog "Color theme updated for $($this.Name)" 'DEBUG'
    }
    
    # 清理资源
    [void] Dispose() {
        try {
            # 停止动画
            $this.StopAnimation()
            
            # 清理定时器
            if ($null -ne $this.AnimationTimer) {
                $this.AnimationTimer.Dispose()
            }
            
            # 清理字符动画集合
            $this.CharacterAnimations.Clear()
            
            Write-SilentLog "RollingNumber disposed: $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to dispose RollingNumber: $_" 'DEBUG'
        }
        
        # 调用基类清理
        $this.base.Dispose()
    }
    
    # 动画完成事件
    [System.EventHandler]$OnAnimationComplete
}

# ============================================================
# 工厂函数
# ============================================================

<#
.SYNOPSIS
    创建RollingNumber实例
#>
function New-RollingNumber {
    param(
        [Parameter(Mandatory = $false)]
        [float]$Value = 0,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$FormatOptions = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$Decimals = 2,
        
        [Parameter(Mandatory = $false)]
        [string]$Prefix = '',
        
        [Parameter(Mandatory = $false)]
        [string]$Suffix = '',
        
        [Parameter(Mandatory = $false)]
        [bool]$Animate = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$Duration = 500,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('linear', 'easeIn', 'easeOut', 'easeInOut', 'spring')]
        [string]$Easing = 'easeOut',
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowDirectionIndicator = $true,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('sm', 'md', 'lg')]
        [string]$IndicatorSize = 'sm',
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "RollingNumber_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    try {
        $rollingNumber = [RollingNumber]::new(
            $Value,
            $FormatOptions,
            $Decimals,
            $Prefix,
            $Suffix,
            $Animate,
            $Duration,
            $Easing,
            $ShowDirectionIndicator,
            $IndicatorSize
        )
        
        $rollingNumber.Name = $Name
        
        # 应用主题字体
        Apply-NordicFont -Control $rollingNumber
        
        Write-SilentLog "RollingNumber created: $Name [Value: $Value]" 'DEBUG'
        return $rollingNumber
    }
    catch {
        Write-SilentLog "Failed to create RollingNumber: $_" 'ERROR'
        throw "Failed to create RollingNumber: $_"
    }
}

<#
.SYNOPSIS
    创建货币格式的RollingNumber
#>
function New-CurrencyRollingNumber {
    param(
        [Parameter(Mandatory = $false)]
        [float]$Value = 0,
        
        [Parameter(Mandatory = $false)]
        [string]$Currency = '$',
        
        [Parameter(Mandatory = $false)]
        [int]$Decimals = 2,
        
        [Parameter(Mandatory = $false)]
        [bool]$UseGrouping = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "CurrencyRollingNumber_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    $formatOptions = @{
        Style = 'currency'
        Currency = $Currency
        UseGrouping = $UseGrouping
    }
    
    return New-RollingNumber `
        -Value $Value `
        -FormatOptions $formatOptions `
        -Decimals $Decimals `
        -Name $Name
}

<#
.SYNOPSIS
    创建百分比格式的RollingNumber
#>
function New-PercentageRollingNumber {
    param(
        [Parameter(Mandatory = $false)]
        [float]$Value = 0,  # 0-1范围的小数
        
        [Parameter(Mandatory = $false)]
        [int]$Decimals = 1,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "PercentageRollingNumber_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    $formatOptions = @{
        Style = 'percent'
        UseGrouping = $false
    }
    
    # 将百分比值转换为小数（如果输入是0-100的范围）
    $displayValue = if ($Value -gt 1) { $Value / 100 } else { $Value }
    
    return New-RollingNumber `
        -Value $displayValue `
        -FormatOptions $formatOptions `
        -Decimals $Decimals `
        -Suffix '%' `
        -Name $Name
}

<#
.SYNOPSIS
    创建数字计数器
#>
function New-CounterRollingNumber {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Value = 0,
        
        [Parameter(Mandatory = $false)]
        [int]$Decimals = 0,
        
        [Parameter(Mandatory = $false)]
        [bool]$UseGrouping = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "CounterRollingNumber_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    $formatOptions = @{
        UseGrouping = $UseGrouping
    }
    
    return New-RollingNumber `
        -Value $Value `
        -FormatOptions $formatOptions `
        -Decimals $Decimals `
        -Name $Name
}

<#
.SYNOPSIS
    创建RollingNumber组
#>
function New-RollingNumberGroup {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Numbers,
        
        [Parameter(Mandatory = $false)]
        [int]$Spacing = 16,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('left', 'center', 'right')]
        [string]$Align = 'center',
        
        [Parameter(Mandatory = $false)]
        [bool]$Synchronized = $false
    )
    
    try {
        $container = New-Object System.Windows.Forms.Panel
        $container.AutoSize = $true
        
        # 计算总宽度
        $totalWidth = 0
        $maxHeight = 0
        
        foreach ($number in $Numbers) {
            if ($number -is [RollingNumber]) {
                $totalWidth += $number.Width
                $maxHeight = [Math]::Max($maxHeight, $number.Height)
            }
        }
        
        # 添加间距
        $totalWidth += ($Numbers.Count - 1) * $Spacing
        
        # 设置容器大小
        $container.Width = $totalWidth
        $container.Height = $maxHeight
        
        # 计算起始X位置（基于对齐方式）
        $startX = 0
        switch ($Align) {
            'left' {
                $startX = 0
            }
            'center' {
                # 容器已经设置了总宽度，从0开始
                $startX = 0
            }
            'right' {
                $startX = 0
            }
        }
        
        # 添加数字控件
        $currentX = $startX
        
        foreach ($number in $Numbers) {
            if ($number -is [RollingNumber]) {
                $number.Location = New-Object System.Drawing.Point($currentX, 0)
                
                # 如果启用同步，添加延迟效果
                if ($Synchronized) {
                    $number.SetAnimationDuration(300)  # 较短的动画时间
                }
                
                $container.Controls.Add($number)
                $currentX += $number.Width + $Spacing
            }
        }
        
        Write-SilentLog "RollingNumberGroup created with $($Numbers.Count) numbers" 'DEBUG'
        return $container
    }
    catch {
        Write-SilentLog "Failed to create RollingNumberGroup: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    批量更新RollingNumber组的值
#>
function Update-RollingNumberGroup {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Panel]$Group,
        
        [Parameter(Mandatory = $true)]
        [array]$Values,
        
        [Parameter(Mandatory = $false)]
        [bool]$Animate = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$Delay = 100  # 每个数字之间的延迟（毫秒）
    )
    
    try {
        $numbers = $Group.Controls | Where-Object { $_ -is [RollingNumber] }
        
        if ($numbers.Count -ne $Values.Count) {
            Write-SilentLog "Mismatch between number of controls and values" 'WARN'
            return $false
        }
        
        for ($i = 0; $i -lt $numbers.Count; $i++) {
            $number = $numbers[$i]
            $value = $Values[$i]
            
            if ($Delay -gt 0 -and $i -gt 0) {
                Start-Sleep -Milliseconds $Delay
            }
            
            $number.SetValue($value, $Animate)
        }
        
        Write-SilentLog "RollingNumberGroup updated with $($Values.Count) values" 'DEBUG'
        return $true
    }
    catch {
        Write-SilentLog "Failed to update RollingNumberGroup: $_" 'ERROR'
        return $false
    }
}

# ============================================================
# 辅助函数
# ============================================================

<#
.SYNOPSIS
    为控件创建RollingNumber显示
#>
function Add-RollingNumberToControl {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Parent,
        
        [Parameter(Mandatory = $false)]
        [float]$InitialValue = 0,
        
        [Parameter(Mandatory = $false)]
        [string]$Format = 'general',
        
        [Parameter(Mandatory = $false)]
        [int]$Decimals = 2,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "RollingNumber_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    try {
        $rollingNumber = switch ($Format) {
            'currency' {
                New-CurrencyRollingNumber -Value $InitialValue -Decimals $Decimals -Name $Name
            }
            'percentage' {
                New-PercentageRollingNumber -Value $InitialValue -Decimals $Decimals -Name $Name
            }
            'counter' {
                New-CounterRollingNumber -Value $InitialValue -Decimals $Decimals -Name $Name
            }
            default {
                New-RollingNumber -Value $InitialValue -Decimals $Decimals -Name $Name
            }
        }
        
        $Parent.Controls.Add($rollingNumber)
        
        Write-SilentLog "RollingNumber added to control: $Name" 'DEBUG'
        return $rollingNumber
    }
    catch {
        Write-SilentLog "Failed to add RollingNumber to control: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    创建简单的数字动画演示
#>
function Show-RollingNumberDemo {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Forms.Form]$ParentForm = $null
    )
    
    try {
        # 创建演示窗体
        $demoForm = New-Object System.Windows.Forms.Form
        $demoForm.Text = "RollingNumber Demo"
        $demoForm.Width = 400
        $demoForm.Height = 300
        $demoForm.StartPosition = 'CenterScreen'
        
        Apply-NordicTheme -Form $demoForm
        
        # 创建多个RollingNumber示例
        $yPos = 20
        
        # 1. 普通数字
        $label1 = New-Object System.Windows.Forms.Label
        $label1.Text = "普通数字:"
        $label1.Location = New-Object System.Drawing.Point(20, $yPos)
        $label1.Width = 80
        Apply-NordicLabel -Label $label1
        $demoForm.Controls.Add($label1)
        
        $number1 = New-RollingNumber -Value 1234.56 -Decimals 2 -Name "DemoNumber1"
        $number1.Location = New-Object System.Drawing.Point(110, $yPos)
        $demoForm.Controls.Add($number1)
        
        $yPos += 40
        
        # 2. 货币格式
        $label2 = New-Object System.Windows.Forms.Label
        $label2.Text = "货币格式:"
        $label2.Location = New-Object System.Drawing.Point(20, $yPos)
        $label2.Width = 80
        Apply-NordicLabel -Label $label2
        $demoForm.Controls.Add($label2)
        
        $number2 = New-CurrencyRollingNumber -Value 1234.56 -Decimals 2 -Name "DemoNumber2"
        $number2.Location = New-Object System.Drawing.Point(110, $yPos)
        $demoForm.Controls.Add($number2)
        
        $yPos += 40
        
        # 3. 百分比格式
        $label3 = New-Object System.Windows.Forms.Label
        $label3.Text = "百分比格式:"
        $label3.Location = New-Object System.Drawing.Point(20, $yPos)
        $label3.Width = 80
        Apply-NordicLabel -Label $label3
        $demoForm.Controls.Add($label3)
        
        $number3 = New-PercentageRollingNumber -Value 0.756 -Decimals 1 -Name "DemoNumber3"
        $number3.Location = New-Object System.Drawing.Point(110, $yPos)
        $demoForm.Controls.Add($number3)
        
        $yPos += 40
        
        # 4. 计数器
        $label4 = New-Object System.Windows.Forms.Label
        $label4.Text = "计数器:"
        $label4.Location = New-Object System.Drawing.Point(20, $yPos)
        $label4.Width = 80
        Apply-NordicLabel -Label $label4
        $demoForm.Controls.Add($label4)
        
        $number4 = New-CounterRollingNumber -Value 1234 -Name "DemoNumber4"
        $number4.Location = New-Object System.Drawing.Point(110, $yPos)
        $demoForm.Controls.Add($number4)
        
        $yPos += 60
        
        # 更新按钮
        $updateButton = New-Object System.Windows.Forms.Button
        $updateButton.Text = "随机更新所有数字"
        $updateButton.Location = New-Object System.Drawing.Point(20, $yPos)
        $updateButton.Width = 150
        Apply-NordicButton -Button $updateButton -Style Primary
        $demoForm.Controls.Add($updateButton)
        
        $updateButton.Add_Click({
            $random = New-Object System.Random
            
            $number1.SetValue($random.Next(1000, 10000) + $random.NextDouble())
            $number2.SetValue($random.Next(1000, 10000) + $random.NextDouble())
            $number3.SetValue($random.NextDouble())
            $number4.SetValue($random.Next(1000, 10000))
        })
        
        # 显示演示窗体
        if ($ParentForm) {
            $demoForm.ShowDialog($ParentForm) | Out-Null
        } else {
            $demoForm.ShowDialog() | Out-Null
        }
        
        Write-SilentLog "RollingNumber demo completed" 'INFO'
        return $true
    }
    catch {
        Write-SilentLog "Failed to show RollingNumber demo: $_" 'ERROR'
        return $false
    }
}

# ============================================================
# 模块初始化
# ============================================================

try {
    Write-SilentLog "RollingNumber Module v1.0.0 loaded successfully" 'INFO'
}
catch {
    Write-SilentLog "Failed to initialize RollingNumber module: $_" 'ERROR'
}

# 导出函数
$functionList = @(
    'New-RollingNumber',
    'New-CurrencyRollingNumber',
    'New-PercentageRollingNumber',
    'New-CounterRollingNumber',
    'New-RollingNumberGroup',
    'Update-RollingNumberGroup',
    'Add-RollingNumberToControl',
    'Show-RollingNumberDemo'
)