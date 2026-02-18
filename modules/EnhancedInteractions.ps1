<#
.SYNOPSIS
    Enhanced Interactions Module - 高级交互体验优化模块

.DESCRIPTION
    基于OpenDoge MotionButton、PageSkeleton、RollingNumber组件的深度集成
    为PowerShell WinForms提供现代Web应用的交互体验

.VERSION
    1.0.0
.CREATED
    2026-02-16
.LAST_UPDATED
    2026-02-16
#>

# ============================================================
# 动画引擎配置和全局状态
# ============================================================

$script:AnimationConfig = @{
    FrameRate = 60  # 目标帧率 (FPS)
    UseDoubleBuffering = $true
    MaxConcurrentAnimations = 10
    DefaultDuration = 250  # 默认动画时长 (毫秒)
    IsInitialized = $false
}

# 全局动画引擎实例
$script:AnimationEngine = $null

# 动画队列和状态跟踪
$script:ActiveAnimations = @{}
$script:AnimationQueue = [System.Collections.Queue]::new()

# ============================================================
# 动画引擎核心类
# ============================================================

<#
.SYNOPSIS
    动画引擎类 - 管理所有动画的创建、执行和销毁
#>
class AnimationEngine {
    [System.Windows.Forms.Timer]$timer
    [hashtable]$animations
    [int]$frameCount
    [datetime]$lastUpdateTime
    [float]$fps
    [bool]$isRunning
    
    # 构造函数
    AnimationEngine() {
        $this.timer = New-Object System.Windows.Forms.Timer
        $this.timer.Interval = 1000 / $script:AnimationConfig.FrameRate
        $this.animations = @{}
        $this.frameCount = 0
        $this.lastUpdateTime = [DateTime]::Now
        $this.fps = 0
        $this.isRunning = $false
        
        # 设置定时器回调
        $this.timer.add_Tick({
            $this.UpdateAnimations()
        })
    }
    
    # 启动动画引擎
    [void] Start() {
        if (-not $this.isRunning) {
            $this.timer.Start()
            $this.isRunning = $true
            Write-SilentLog "Animation engine started at $($script:AnimationConfig.FrameRate) FPS" 'DEBUG'
        }
    }
    
    # 停止动画引擎
    [void] Stop() {
        if ($this.isRunning) {
            $this.timer.Stop()
            $this.isRunning = $false
            Write-SilentLog "Animation engine stopped" 'DEBUG'
        }
    }
    
    # 更新所有动画
    [void] UpdateAnimations() {
        $currentTime = [DateTime]::Now
        $deltaTime = ($currentTime - $this.lastUpdateTime).TotalSeconds
        
        # 计算FPS
        $this.frameCount++
        if (($currentTime - $this.lastUpdateTime).TotalSeconds >= 1) {
            $this.fps = $this.frameCount / ($currentTime - $this.lastUpdateTime).TotalSeconds
            $this.frameCount = 0
            $this.lastUpdateTime = $currentTime
        }
        
        # 更新所有活跃动画
        $animationsToRemove = @()
        foreach ($animationId in $this.animations.Keys) {
            $animation = $this.animations[$animationId]
            
            if (-not $animation.IsComplete) {
                $animation.Update($deltaTime)
                
                # 检查动画是否完成
                if ($animation.IsComplete) {
                    $animationsToRemove += $animationId
                    $animation.OnComplete.Invoke()
                }
            } else {
                $animationsToRemove += $animationId
            }
        }
        
        # 移除已完成的动画
        foreach ($animationId in $animationsToRemove) {
            $this.animations.Remove($animationId)
        }
        
        # 从队列中添加新动画
        while ($script:AnimationQueue.Count -gt 0 -and $this.animations.Count -lt $script:AnimationConfig.MaxConcurrentAnimations) {
            $queuedAnimation = $script:AnimationQueue.Dequeue()
            $this.AddAnimation($queuedAnimation.Id, $queuedAnimation)
        }
    }
    
    # 添加动画
    [void] AddAnimation([string]$id, [Animation]$animation) {
        if ($this.animations.Count -ge $script:AnimationConfig.MaxConcurrentAnimations) {
            # 队列已满，添加到等待队列
            $script:AnimationQueue.Enqueue(@{Id = $id; Animation = $animation})
            Write-SilentLog "Animation queue full, added to waiting queue: $id" 'DEBUG'
        } else {
            $this.animations[$id] = $animation
            Write-SilentLog "Animation added: $id" 'DEBUG'
        }
    }
    
    # 移除动画
    [void] RemoveAnimation([string]$id) {
        if ($this.animations.ContainsKey($id)) {
            $this.animations.Remove($id)
            Write-SilentLog "Animation removed: $id" 'DEBUG'
        }
    }
    
    # 暂停动画
    [void] PauseAnimation([string]$id) {
        if ($this.animations.ContainsKey($id)) {
            $this.animations[$id].IsPaused = $true
        }
    }
    
    # 恢复动画
    [void] ResumeAnimation([string]$id) {
        if ($this.animations.ContainsKey($id)) {
            $this.animations[$id].IsPaused = $false
        }
    }
    
    # 获取当前FPS
    [float] GetFPS() {
        return $this.fps
    }
    
    # 获取活跃动画数量
    [int] GetActiveAnimationCount() {
        return $this.animations.Count
    }
    
    # 获取队列中的动画数量
    [int] GetQueuedAnimationCount() {
        return $script:AnimationQueue.Count
    }
}

<#
.SYNOPSIS
    动画基类 - 所有动画类型的基类
#>
class Animation {
    [string]$Id
    [float]$Duration
    [float]$ElapsedTime
    [float]$Progress
    [bool]$IsComplete
    [bool]$IsPaused
    [scriptblock]$OnComplete
    [scriptblock]$OnUpdate
    
    # 构造函数
    Animation([string]$id, [float]$duration) {
        $this.Id = $id
        $this.Duration = $duration
        $this.ElapsedTime = 0
        $this.Progress = 0
        $this.IsComplete = $false
        $this.IsPaused = $false
        $this.OnComplete = {}
        $this.OnUpdate = {}
    }
    
    # 更新动画状态
    [void] Update([float]$deltaTime) {
        if ($this.IsPaused -or $this.IsComplete) {
            return
        }
        
        $this.ElapsedTime += $deltaTime
        $this.Progress = [Math]::Min($this.ElapsedTime / $this.Duration, 1.0)
        
        # 调用更新回调
        if ($null -ne $this.OnUpdate) {
            $this.OnUpdate.Invoke($this.Progress)
        }
        
        # 检查是否完成
        if ($this.Progress -ge 1.0) {
            $this.IsComplete = $true
        }
    }
    
    # 重置动画
    [void] Reset() {
        $this.ElapsedTime = 0
        $this.Progress = 0
        $this.IsComplete = $false
        $this.IsPaused = $false
    }
}

# ============================================================
# 缓动函数库
# ============================================================

<#
.SYNOPSIS
    线性缓动函数
#>
function Get-LinearEase {
    param([float]$t)
    return $t
}

<#
.SYNOPSIS
    缓入缓出函数 (ease-in-out)
#>
function Get-EaseInOut {
    param([float]$t)
    return if ($t < 0.5) { 2 * $t * $t } else { 1 - [Math]::Pow(-2 * $t + 2, 2) / 2 }
}

<#
.SYNOPSIS
    缓入函数 (ease-in)
#>
function Get-EaseIn {
    param([float]$t)
    return $t * $t * $t
}

<#
.SYNOPSIS
    缓出函数 (ease-out)
#>
function Get-EaseOut {
    param([float]$t)
    $t = $t - 1
    return $t * $t * $t + 1
}

<#
.SYNOPSIS
    弹性缓动函数 (spring)
#>
function Get-SpringEase {
    param([float]$t, [float]$stiffness = 0.5)
    return 1 - [Math]::Exp(-$stiffness * $t) * [Math]::Cos($t * 5)
}

<#
.SYNOPSIS
    反弹缓动函数 (bounce)
#>
function Get-BounceEase {
    param([float]$t)
    if ($t < 1 / 2.75) {
        return 7.5625 * $t * $t
    } elseif ($t < 2 / 2.75) {
        $t = $t - 1.5 / 2.75
        return 7.5625 * $t * $t + 0.75
    } elseif ($t < 2.5 / 2.75) {
        $t = $t - 2.25 / 2.75
        return 7.5625 * $t * $t + 0.9375
    } else {
        $t = $t - 2.625 / 2.75
        return 7.5625 * $t * $t + 0.984375
    }
}

# 缓动函数映射表
$script:EasingFunctions = @{
    Linear = { param($t) Get-LinearEase $t }
    EaseInOut = { param($t) Get-EaseInOut $t }
    EaseIn = { param($t) Get-EaseIn $t }
    EaseOut = { param($t) Get-EaseOut $t }
    Spring = { param($t) Get-SpringEase $t }
    Bounce = { param($t) Get-BounceEase $t }
}

# ============================================================
# 动画类型：属性动画
# ============================================================

<#
.SYNOPSIS
    属性动画类 - 动画化控件的属性值
#>
class PropertyAnimation : Animation {
    [object]$Target
    [string]$PropertyName
    [object]$FromValue
    [object]$ToValue
    [scriptblock]$EasingFunction
    
    PropertyAnimation(
        [string]$id,
        [object]$target,
        [string]$propertyName,
        [object]$fromValue,
        [object]$toValue,
        [float]$duration,
        [scriptblock]$easingFunction
    ) : base($id, $duration) {
        $this.Target = $target
        $this.PropertyName = $propertyName
        $this.FromValue = $fromValue
        $this.ToValue = $toValue
        $this.EasingFunction = $easingFunction
        
        # 设置更新回调
        $this.OnUpdate = {
            param($progress)
            $easedProgress = & $this.EasingFunction $progress
            
            # 计算当前值
            $currentValue = $null
            if ($this.FromValue -is [System.Drawing.Color] -and $this.ToValue -is [System.Drawing.Color]) {
                # 颜色插值
                $currentValue = Interpolate-Color -From $this.FromValue -To $this.ToValue -Progress $easedProgress
            } elseif ($this.FromValue -is [float] -or $this.FromValue -is [double] -or $this.FromValue -is [int]) {
                # 数值插值
                $currentValue = $this.FromValue + ($this.ToValue - $this.FromValue) * $easedProgress
            } else {
                # 默认使用线性插值
                $currentValue = $this.FromValue
                if ($easedProgress -ge 1.0) {
                    $currentValue = $this.ToValue
                }
            }
            
            # 更新属性值（使用UI线程）
            try {
                if ($this.Target -and $this.Target.InvokeRequired) {
                    $this.Target.BeginInvoke([System.Action]{
                        $this.Target.$($this.PropertyName) = $currentValue
                    }) | Out-Null
                } else {
                    $this.Target.$($this.PropertyName) = $currentValue
                }
            }
            catch {
                Write-SilentLog "Failed to update property $($this.PropertyName): $_" 'DEBUG'
            }
        }
    }
}

# ============================================================
# 动画类型：变换动画
# ============================================================

<#
.SYNOPSIS
    变换动画类 - 动画化控件的位置、大小等变换属性
#>
class TransformAnimation : Animation {
    [System.Windows.Forms.Control]$Target
    [hashtable]$FromValues
    [hashtable]$ToValues
    [scriptblock]$EasingFunction
    
    TransformAnimation(
        [string]$id,
        [System.Windows.Forms.Control]$target,
        [hashtable]$fromValues,
        [hashtable]$toValues,
        [float]$duration,
        [scriptblock]$easingFunction
    ) : base($id, $duration) {
        $this.Target = $target
        $this.FromValues = $fromValues
        $this.ToValues = $toValues
        $this.EasingFunction = $easingFunction
        
        $this.OnUpdate = {
            param($progress)
            $easedProgress = & $this.EasingFunction $progress
            
            try {
                # 更新所有变换属性
                foreach ($propertyName in $this.FromValues.Keys) {
                    if ($this.ToValues.ContainsKey($propertyName)) {
                        $fromValue = $this.FromValues[$propertyName]
                        $toValue = $this.ToValues[$propertyName]
                        
                        if ($fromValue -is [int] -and $toValue -is [int]) {
                            $currentValue = [Math]::Round($fromValue + ($toValue - $fromValue) * $easedProgress)
                            
                            # 使用UI线程更新
                            if ($this.Target.InvokeRequired) {
                                $this.Target.BeginInvoke([System.Action]{
                                    $this.Target.$propertyName = $currentValue
                                }) | Out-Null
                            } else {
                                $this.Target.$propertyName = $currentValue
                            }
                        }
                    }
                }
            }
            catch {
                Write-SilentLog "Failed to update transform: $_" 'DEBUG'
            }
        }
    }
}

# ============================================================
# 辅助函数
# ============================================================

<#
.SYNOPSIS
    插值计算两个颜色之间的中间色
#>
function Interpolate-Color {
    param(
        [System.Drawing.Color]$From,
        [System.Drawing.Color]$To,
        [float]$Progress
    )
    
    $r = [Math]::Round($From.R + ($To.R - $From.R) * $Progress)
    $g = [Math]::Round($From.G + ($To.G - $From.G) * $Progress)
    $b = [Math]::Round($From.B + ($To.B - $From.B) * $Progress)
    $a = [Math]::Round($From.A + ($To.A - $From.A) * $Progress)
    
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

<#
.SYNOPSIS
    创建属性动画
#>
function New-PropertyAnimation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        
        [Parameter(Mandatory = $true)]
        [object]$Target,
        
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        
        [Parameter(Mandatory = $true)]
        [object]$FromValue,
        
        [Parameter(Mandatory = $true)]
        [object]$ToValue,
        
        [int]$Duration = 250,
        
        [ValidateSet('Linear', 'EaseInOut', 'EaseIn', 'EaseOut', 'Spring', 'Bounce')]
        [string]$Easing = 'EaseInOut'
    )
    
    $easingFunction = $script:EasingFunctions[$Easing]
    if (-not $easingFunction) {
        $easingFunction = $script:EasingFunctions['EaseInOut']
    }
    
    return [PropertyAnimation]::new($Id, $Target, $PropertyName, $FromValue, $ToValue, ($Duration / 1000.0), $easingFunction)
}

<#
.SYNOPSIS
    创建变换动画
#>
function New-TransformAnimation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Target,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$FromValues,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ToValues,
        
        [int]$Duration = 250,
        
        [ValidateSet('Linear', 'EaseInOut', 'EaseIn', 'EaseOut', 'Spring', 'Bounce')]
        [string]$Easing = 'EaseInOut'
    )
    
    $easingFunction = $script:EasingFunctions[$Easing]
    if (-not $easingFunction) {
        $easingFunction = $script:EasingFunctions['EaseInOut']
    }
    
    return [TransformAnimation]::new($Id, $Target, $FromValues, $ToValues, ($Duration / 1000.0), $easingFunction)
}

<#
.SYNOPSIS
    启动动画
#>
function Start-Animation {
    param(
        [Parameter(Mandatory = $true)]
        [Animation]$Animation,
        
        [scriptblock]$OnComplete = $null
    )
    
    if ($null -eq $script:AnimationEngine) {
        Write-SilentLog "Animation engine not initialized" 'WARN'
        return $false
    }
    
    if ($OnComplete) {
        $Animation.OnComplete = $OnComplete
    }
    
    $script:AnimationEngine.AddAnimation($Animation.Id, $Animation)
    return $true
}

<#
.SYNOPSIS
    停止动画
#>
function Stop-Animation {
    param([string]$AnimationId)
    
    if ($null -eq $script:AnimationEngine) {
        return $false
    }
    
    $script:AnimationEngine.RemoveAnimation($AnimationId)
    return $true
}

<#
.SYNOPSIS
    暂停动画
#>
function Pause-Animation {
    param([string]$AnimationId)
    
    if ($null -eq $script:AnimationEngine) {
        return $false
    }
    
    $script:AnimationEngine.PauseAnimation($AnimationId)
    return $true
}

<#
.SYNOPSIS
    恢复动画
#>
function Resume-Animation {
    param([string]$AnimationId)
    
    if ($null -eq $script:AnimationEngine) {
        return $false
    }
    
    $script:AnimationEngine.ResumeAnimation($AnimationId)
    return $true
}

# ============================================================
# 双缓冲辅助函数
# ============================================================

<#
.SYNOPSIS
    启用控件的双缓冲
#>
function Enable-DoubleBuffering {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Control
    )
    
    try {
        # 使用反射设置双缓冲属性
        $control.GetType().GetProperty("DoubleBuffered", 
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($control, $true, $null)
        
        Write-SilentLog "Double buffering enabled for $($Control.Name)" 'DEBUG'
        return $true
    }
    catch {
        Write-SilentLog "Failed to enable double buffering: $_" 'DEBUG'
        return $false
    }
}

<#
.SYNOPSIS
    禁用控件的双缓冲
#>
function Disable-DoubleBuffering {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Control
    )
    
    try {
        $control.GetType().GetProperty("DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($control, $false, $null)
        
        Write-SilentLog "Double buffering disabled for $($Control.Name)" 'DEBUG'
        return $true
    }
    catch {
        Write-SilentLog "Failed to disable double buffering: $_" 'DEBUG'
        return $false
    }
}

# ============================================================
# 模块初始化函数
# ============================================================

<#
.SYNOPSIS
    初始化动画引擎
#>
function Initialize-AnimationEngine {
    try {
        if ($script:AnimationConfig.IsInitialized) {
            Write-SilentLog "Animation engine already initialized" 'DEBUG'
            return $true
        }
        
        # 创建动画引擎实例
        $script:AnimationEngine = [AnimationEngine]::new()
        
        # 启动动画引擎
        $script:AnimationEngine.Start()
        
        $script:AnimationConfig.IsInitialized = $true
        
        Write-SilentLog "Animation engine initialized successfully" 'INFO'
        return $true
    }
    catch {
        Write-SilentLog "Failed to initialize animation engine: $_" 'ERROR'
        return $false
    }
}

<#
.SYNOPSIS
    停止动画引擎
#>
function Stop-AnimationEngine {
    try {
        if ($null -ne $script:AnimationEngine) {
            $script:AnimationEngine.Stop()
            $script:AnimationEngine = $null
        }
        
        $script:AnimationConfig.IsInitialized = $false
        $script:ActiveAnimations = @{}
        $script:AnimationQueue.Clear()
        
        Write-SilentLog "Animation engine stopped" 'INFO'
        return $true
    }
    catch {
        Write-SilentLog "Failed to stop animation engine: $_" 'ERROR'
        return $false
    }
}

<#
.SYNOPSIS
    获取动画引擎状态
#>
function Get-AnimationEngineStatus {
    if (-not $script:AnimationConfig.IsInitialized) {
        return @{
            IsRunning = $false
            FPS = 0
            ActiveAnimations = 0
            QueuedAnimations = 0
            MaxConcurrent = $script:AnimationConfig.MaxConcurrentAnimations
        }
    }
    
    return @{
        IsRunning = $script:AnimationEngine.isRunning
        FPS = $script:AnimationEngine.GetFPS()
        ActiveAnimations = $script:AnimationEngine.GetActiveAnimationCount()
        QueuedAnimations = $script:AnimationEngine.GetQueuedAnimationCount()
        MaxConcurrent = $script:AnimationConfig.MaxConcurrentAnimations
    }
}

# ============================================================
# 模块导出函数
# ============================================================

# 初始化模块
try {
    # 尝试初始化动画引擎（但不在模块加载时自动启动）
    # 需要在主程序中显式调用 Initialize-AnimationEngine
    
    Write-SilentLog "Enhanced Interactions Module v1.0.0 loaded successfully" 'INFO'
}
catch {
    Write-SilentLog "Failed to initialize Enhanced Interactions module: $_" 'ERROR'
}

# 模块函数列表（用于文档）
$functionList = @(
    'Initialize-AnimationEngine',
    'Stop-AnimationEngine',
    'Get-AnimationEngineStatus',
    'New-PropertyAnimation',
    'New-TransformAnimation',
    'Start-Animation',
    'Stop-Animation',
    'Pause-Animation',
    'Resume-Animation',
    'Get-LinearEase',
    'Get-EaseInOut',
    'Get-EaseIn',
    'Get-EaseOut',
    'Get-SpringEase',
    'Get-BounceEase',
    'Interpolate-Color',
    'Enable-DoubleBuffering',
    'Disable-DoubleBuffering'
)