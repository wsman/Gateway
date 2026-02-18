<#
.SYNOPSIS
    PageSkeleton Component - 基于OpenDoge PageSkeleton的骨架屏组件

.DESCRIPTION
    为PowerShell WinForms提供现代Web应用级别的骨架屏加载效果
    实现脉冲动画、多布局支持和响应式占位符

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
# PageSkeleton类定义
# ============================================================

<#
.SYNOPSIS
    PageSkeleton类 - 骨架屏加载效果控件
#>
class PageSkeleton : System.Windows.Forms.Panel {
    # 样式属性
    hidden [string]$SkeletonType
    hidden [bool]$ShowHeader
    hidden [bool]$ShowSidebar
    hidden [bool]$ShowMainContent
    hidden [object]$CustomContent
    hidden [bool]$IsActive
    hidden [System.Windows.Forms.Timer]$PulseTimer
    hidden [float]$PulseProgress
    hidden [bool]$PulseDirection
    hidden [int]$PulseSpeed = 1000  # 毫秒
    
    # 子控件集合
    hidden [System.Collections.ArrayList]$SkeletonElements
    
    # 构造函数
    PageSkeleton() : base() {
        $this.InitializeComponent()
    }
    
    # 带参数的构造函数
    PageSkeleton(
        [string]$Type = 'default',
        [bool]$ShowHeader = $true,
        [bool]$ShowSidebar = $true,
        [bool]$ShowMainContent = $true,
        [object]$CustomContent = $null
    ) : base() {
        $this.SkeletonType = $Type
        $this.ShowHeader = $ShowHeader
        $this.ShowSidebar = $ShowSidebar
        $this.ShowMainContent = $ShowMainContent
        $this.CustomContent = $CustomContent
        
        $this.InitializeComponent()
    }
    
    # 初始化组件
    hidden [void] InitializeComponent() {
        # 基础样式设置
        $this.BackColor = $global:NordicTheme.BackgroundPrimary
        $this.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        $this.AutoScroll = $true
        
        # 启用双缓冲以减少闪烁
        $this.GetType().GetProperty("DoubleBuffered", 
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($this, $true, $null)
        
        # 初始化骨架元素集合
        $this.SkeletonElements = [System.Collections.ArrayList]::new()
        
        # 初始化脉冲定时器
        $this.PulseTimer = New-Object System.Windows.Forms.Timer
        $this.PulseTimer.Interval = 16  # ~60 FPS
        $this.PulseProgress = 0
        $this.PulseDirection = $true  # true = 增加, false = 减少
        $this.PulseTimer.add_Tick({
            $this.UpdatePulse()
        })
        
        # 设置绘制事件
        $this.Add_Paint($this.OnPaint)
        
        # 生成骨架内容
        $this.GenerateSkeleton()
        
        Write-SilentLog "PageSkeleton initialized: $($this.Name) [$($this.SkeletonType)]" 'DEBUG'
    }
    
    # 生成骨架内容
    hidden [void] GenerateSkeleton() {
        # 清除现有内容
        $this.Controls.Clear()
        $this.SkeletonElements.Clear()
        
        # 如果有自定义内容，直接使用
        if ($null -ne $this.CustomContent) {
            if ($this.CustomContent -is [System.Windows.Forms.Control]) {
                $this.Controls.Add($this.CustomContent)
            } elseif ($this.CustomContent -is [string]) {
                $label = New-Object System.Windows.Forms.Label
                $label.Text = $this.CustomContent
                $label.AutoSize = $true
                Apply-NordicLabel -Label $label
                $this.Controls.Add($label)
            }
            return
        }
        
        # 根据类型生成骨架
        switch ($this.SkeletonType) {
            'dashboard' {
                $this.GenerateDashboardSkeleton()
            }
            'market' {
                $this.GenerateMarketSkeleton()
            }
            default {
                $this.GenerateDefaultSkeleton()
            }
        }
        
        # 启动脉冲动画
        $this.StartPulseAnimation()
    }
    
    # 生成仪表板骨架
    hidden [void] GenerateDashboardSkeleton() {
        $currentY = 10
        $padding = 10
        
        # 标题区域（如果显示）
        if ($this.ShowHeader) {
            # 标题占位符
            $titlePanel = $this.CreateSkeletonElement('header-title', 200, 32)
            $titlePanel.Location = New-Object System.Drawing.Point($padding, $currentY)
            $this.Controls.Add($titlePanel)
            $this.SkeletonElements.Add($titlePanel)
            
            # 操作按钮区域
            $actionsPanel = $this.CreateSkeletonElement('header-actions', 100, 32)
            $actionsPanel.Location = New-Object System.Drawing.Point($this.Width - 110 - $padding, $currentY)
            $this.Controls.Add($actionsPanel)
            $this.SkeletonElements.Add($actionsPanel)
            
            $currentY += $titlePanel.Height + $padding * 2
        }
        
        # 主内容区域（如果显示）
        if ($this.ShowMainContent) {
            # 数据卡片区域（4个卡片）
            $cardGridWidth = $this.Width - ($padding * 2)
            $cardWidth = ($cardGridWidth - ($padding * 3)) / 4  # 4个卡片，3个间距
            
            for ($i = 0; $i -lt 4; $i++) {
                $cardX = $padding + ($i * ($cardWidth + $padding))
                $card = $this.CreateSkeletonElement("card-$i", $cardWidth, 80)
                $card.Location = New-Object System.Drawing.Point($cardX, $currentY)
                $this.Controls.Add($card)
                $this.SkeletonElements.Add($card)
            }
            
            $currentY += 90 + $padding * 2
            
            # 主内容网格（3个区域）
            $mainGridHeight = 400
            $mainGridWidth = $this.Width - ($padding * 2)
            $mainColumnWidth = ($mainGridWidth - ($padding * 2)) / 3
            
            for ($i = 0; $i -lt 3; $i++) {
                $columnX = $padding + ($i * ($mainColumnWidth + $padding))
                $column = $this.CreateSkeletonElement("main-$i", $mainColumnWidth, $mainGridHeight)
                $column.Location = New-Object System.Drawing.Point($columnX, $currentY)
                $this.Controls.Add($column)
                $this.SkeletonElements.Add($column)
            }
            
            $currentY += $mainGridHeight + $padding
        }
        
        # 设置容器高度
        $this.Height = $currentY + $padding
    }
    
    # 生成市场骨架
    hidden [void] GenerateMarketSkeleton() {
        $currentY = 10
        $padding = 10
        
        # 标题区域（如果显示）
        if ($this.ShowHeader) {
            # 标题占位符
            $titlePanel = $this.CreateSkeletonElement('market-title', 150, 28)
            $titlePanel.Location = New-Object System.Drawing.Point($padding, $currentY)
            $this.Controls.Add($titlePanel)
            $this.SkeletonElements.Add($titlePanel)
            
            # 操作按钮区域（2个按钮）
            $buttonWidth = 80
            $buttonSpacing = 5
            
            for ($i = 0; $i -lt 2; $i++) {
                $buttonX = $this.Width - ($buttonWidth * (2 - $i)) - ($buttonSpacing * (1 - $i)) - $padding
                $button = $this.CreateSkeletonElement("market-button-$i", $buttonWidth, 32)
                $button.Location = New-Object System.Drawing.Point($buttonX, $currentY)
                $this.Controls.Add($button)
                $this.SkeletonElements.Add($button)
            }
            
            $currentY += 38 + $padding
        }
        
        # 市场表格骨架（如果显示）
        if ($this.ShowMainContent) {
            $rowHeight = 120
            $rowWidth = $this.Width - ($padding * 2)
            
            for ($i = 0; $i -lt 10; $i++) {  # 10行数据
                $row = $this.CreateSkeletonElement("market-row-$i", $rowWidth, $rowHeight)
                $row.Location = New-Object System.Drawing.Point($padding, $currentY)
                $this.Controls.Add($row)
                $this.SkeletonElements.Add($row)
                
                $currentY += $rowHeight + $padding
            }
            
            $currentY += $padding
        }
        
        # 设置容器高度
        $this.Height = $currentY + $padding
    }
    
    # 生成默认骨架
    hidden [void] GenerateDefaultSkeleton() {
        $currentY = 10
        $padding = 10
        
        # 标题区域（如果显示）
        if ($this.ShowHeader) {
            $header = $this.CreateSkeletonElement('default-header', $this.Width - ($padding * 2), 64)
            $header.Location = New-Object System.Drawing.Point($padding, $currentY)
            $this.Controls.Add($header)
            $this.SkeletonElements.Add($header)
            
            $currentY += 74 + $padding
        }
        
        # 侧边栏（如果显示）
        if ($this.ShowSidebar) {
            $sidebar = $this.CreateSkeletonElement('default-sidebar', 200, $this.Height - $currentY - $padding)
            $sidebar.Location = New-Object System.Drawing.Point($padding, $currentY)
            $this.Controls.Add($sidebar)
            $this.SkeletonElements.Add($sidebar)
        }
        
        # 主内容区域（如果显示）
        if ($this.ShowMainContent) {
            $sidebarWidth = if ($this.ShowSidebar) { 200 + $padding } else { 0 }
            $mainWidth = $this.Width - $sidebarWidth - ($padding * 2)
            $mainHeight = 600
            
            $main = $this.CreateSkeletonElement('default-main', $mainWidth, $mainHeight)
            $main.Location = New-Object System.Drawing.Point($sidebarWidth + $padding, $currentY)
            $this.Controls.Add($main)
            $this.SkeletonElements.Add($main)
            
            $currentY += $mainHeight + $padding
        }
        
        # 设置容器高度
        $this.Height = $currentY + $padding
    }
    
    # 创建骨架元素
    hidden [System.Windows.Forms.Panel] CreateSkeletonElement(
        [string]$name,
        [int]$width,
        [int]$height
    ) {
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Name = $name
        $panel.Width = $width
        $panel.Height = $height
        $panel.BackColor = $global:NordicTheme.BackgroundSecondary
        $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $panel.Padding = New-Object System.Windows.Forms.Padding(4)
        
        # 启用双缓冲
        $panel.GetType().GetProperty("DoubleBuffered", 
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($panel, $true, $null)
        
        # 添加绘制事件
        $panel.Add_Paint({
            param($sender, $e)
            $this.DrawSkeletonElement($sender, $e)
        })
        
        return $panel
    }
    
    # 绘制骨架元素
    hidden [void] DrawSkeletonElement(
        [System.Windows.Forms.Panel]$sender,
        [System.Windows.Forms.PaintEventArgs]$e
    ) {
        # 设置高质量渲染
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        
        # 计算脉冲颜色
        $baseColor = $sender.BackColor
        $pulseIntensity = $this.PulseProgress * 0.2  # 20%的最大亮度变化
        
        # 计算渐变颜色
        $gradientColor = [System.Drawing.Color]::FromArgb(
            $baseColor.A,
            [Math]::Min(255, [int]($baseColor.R * (1 + $pulseIntensity))),
            [Math]::Min(255, [int]($baseColor.G * (1 + $pulseIntensity))),
            [Math]::Min(255, [int]($baseColor.B * (1 + $pulseIntensity)))
        )
        
        # 创建渐变画刷
        $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $sender.ClientRectangle,
            $baseColor,
            $gradientColor,
            [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
        )
        
        # 绘制渐变背景
        $e.Graphics.FillRectangle($gradientBrush, $sender.ClientRectangle)
        
        # 绘制内部内容占位符（模拟骨架内部结构）
        $this.DrawInternalPlaceholder($sender, $e)
        
        # 清理资源
        $gradientBrush.Dispose()
    }
    
    # 绘制内部占位符
    hidden [void] DrawInternalPlaceholder(
        [System.Windows.Forms.Panel]$sender,
        [System.Windows.Forms.PaintEventArgs]$e
    ) {
        $padding = 8
        $rect = $sender.ClientRectangle
        $rect.Inflate(-$padding, -$padding)
        
        # 根据元素类型绘制不同的内部结构
        switch -Wildcard ($sender.Name) {
            'header-*' {
                # 标题区域内部简单线条
                $lineHeight = 4
                $lineY = $rect.Top + ($rect.Height - $lineHeight) / 2
                
                $lineBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                $e.Graphics.FillRectangle($lineBrush, $rect.Left, $lineY, $rect.Width, $lineHeight)
                $lineBrush.Dispose()
            }
            'card-*' {
                # 卡片内部结构：顶部标题 + 中间内容 + 底部状态
                $titleHeight = 12
                $contentHeight = 40
                $statusHeight = 8
                
                # 标题占位符
                $titleBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                $e.Graphics.FillRectangle($titleBrush, $rect.Left, $rect.Top, $rect.Width * 0.4, $titleHeight)
                $titleBrush.Dispose()
                
                # 内容占位符
                $contentBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                $e.Graphics.FillRectangle($contentBrush, $rect.Left, $rect.Top + $titleHeight + 10, $rect.Width, $contentHeight)
                $contentBrush.Dispose()
                
                # 状态占位符
                $statusBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                $e.Graphics.FillRectangle($statusBrush, $rect.Left, $rect.Bottom - $statusHeight, $rect.Width * 0.6, $statusHeight)
                $statusBrush.Dispose()
            }
            'main-*' {
                # 主内容区域：网格结构
                $gridSize = 20
                $gridSpacing = 5
                
                $gridBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                
                for ($row = 0; $row -lt [Math]::Floor($rect.Height / ($gridSize + $gridSpacing)); $row++) {
                    for ($col = 0; $col -lt [Math]::Floor($rect.Width / ($gridSize + $gridSpacing)); $col++) {
                        $x = $rect.Left + $col * ($gridSize + $gridSpacing)
                        $y = $rect.Top + $row * ($gridSize + $gridSpacing)
                        
                        if (($row + $col) % 3 -eq 0) {  # 创建不规则模式
                            $e.Graphics.FillRectangle($gridBrush, $x, $y, $gridSize, $gridSize)
                        }
                    }
                }
                
                $gridBrush.Dispose()
            }
            'market-*' {
                # 市场行内部：多个数据列
                $columnCount = 5
                $columnWidth = $rect.Width / $columnCount
                $columnHeight = 20
                $rowSpacing = 15
                
                $columnBrush = New-Object System.Drawing.SolidBrush($global:NordicTheme.BackgroundTertiary)
                
                for ($i = 0; $i -lt $columnCount; $i++) {
                    $x = $rect.Left + $i * $columnWidth + 10
                    
                    # 标签占位符（较短）
                    $e.Graphics.FillRectangle($columnBrush, $x, $rect.Top + 10, $columnWidth * 0.3, $columnHeight)
                    
                    # 数值占位符（较长）
                    $e.Graphics.FillRectangle($columnBrush, $x, $rect.Top + 10 + $columnHeight + 5, $columnWidth * 0.6, $columnHeight)
                    
                    # 状态占位符（圆形）
                    $circleSize = 12
                    $e.Graphics.FillEllipse($columnBrush, $x + $columnWidth * 0.7, $rect.Top + 10 + ($columnHeight - $circleSize) / 2, $circleSize, $circleSize)
                }
                
                $columnBrush.Dispose()
            }
            default {
                # 默认内部：简单对角线渐变
                $diagonalBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                    $rect,
                    [System.Drawing.Color]::Transparent,
                    $global:NordicTheme.BackgroundTertiary,
                    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
                )
                
                $e.Graphics.FillRectangle($diagonalBrush, $rect)
                $diagonalBrush.Dispose()
            }
        }
    }
    
    # ============================================================
    # 动画功能
    # ============================================================
    
    # 开始脉冲动画
    hidden [void] StartPulseAnimation() {
        if (-not $this.PulseTimer.Enabled) {
            $this.PulseTimer.Start()
            $this.IsActive = $true
            Write-SilentLog "Pulse animation started for $($this.Name)" 'DEBUG'
        }
    }
    
    # 停止脉冲动画
    hidden [void] StopPulseAnimation() {
        if ($this.PulseTimer.Enabled) {
            $this.PulseTimer.Stop()
            $this.IsActive = $false
            Write-SilentLog "Pulse animation stopped for $($this.Name)" 'DEBUG'
        }
    }
    
    # 更新脉冲动画
    hidden [void] UpdatePulse() {
        # 更新进度
        $increment = 16.0 / $this.PulseSpeed  # 基于定时器间隔和脉冲速度
        $increment = $increment * 2  # 加速动画
        
        if ($this.PulseDirection) {
            $this.PulseProgress += $increment
            if ($this.PulseProgress -ge 1) {
                $this.PulseProgress = 1
                $this.PulseDirection = $false
            }
        } else {
            $this.PulseProgress -= $increment
            if ($this.PulseProgress -le 0) {
                $this.PulseProgress = 0
                $this.PulseDirection = $true
            }
        }
        
        # 强制重绘所有骨架元素
        foreach ($element in $this.SkeletonElements) {
            $element.Invalidate()
        }
    }
    
    # 绘制事件
    hidden [void] OnPaint([object]$sender, [System.Windows.Forms.PaintEventArgs]$e) {
        # 调用基类绘制
        $this.base.OnPaint($e)
        
        # 如果有自定义绘制可以在这里添加
    }
    
    # ============================================================
    # 公共方法
    # ============================================================
    
    # 设置骨架类型
    [void] SetSkeletonType([string]$type) {
        $this.SkeletonType = $type
        $this.GenerateSkeleton()
    }
    
    # 设置显示选项
    [void] SetDisplayOptions(
        [bool]$showHeader,
        [bool]$showSidebar,
        [bool]$showMainContent
    ) {
        $this.ShowHeader = $showHeader
        $this.ShowSidebar = $showSidebar
        $this.ShowMainContent = $showMainContent
        $this.GenerateSkeleton()
    }
    
    # 设置自定义内容
    [void] SetCustomContent([object]$content) {
        $this.CustomContent = $content
        $this.GenerateSkeleton()
    }
    
    # 显示骨架屏
    [void] ShowSkeleton() {
        $this.Visible = $true
        $this.StartPulseAnimation()
    }
    
    # 隐藏骨架屏
    [void] HideSkeleton() {
        $this.Visible = $false
        $this.StopPulseAnimation()
    }
    
    # 设置脉冲速度
    [void] SetPulseSpeed([int]$speed) {
        $this.PulseSpeed = [Math]::Max(100, [Math]::Min(5000, $speed))  # 限制在100-5000毫秒之间
        Write-SilentLog "Pulse speed set to $($this.PulseSpeed)ms for $($this.Name)" 'DEBUG'
    }
    
    # 清理资源
    [void] Dispose() {
        try {
            # 停止脉冲动画
            $this.StopPulseAnimation()
            
            # 清理定时器
            if ($null -ne $this.PulseTimer) {
                $this.PulseTimer.Dispose()
            }
            
            # 清理骨架元素集合
            $this.SkeletonElements.Clear()
            
            Write-SilentLog "PageSkeleton disposed: $($this.Name)" 'DEBUG'
        }
        catch {
            Write-SilentLog "Failed to dispose PageSkeleton: $_" 'DEBUG'
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
    创建PageSkeleton实例
#>
function New-PageSkeleton {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('default', 'dashboard', 'market')]
        [string]$Type = 'default',
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowHeader = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowSidebar = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowMainContent = $true,
        
        [Parameter(Mandatory = $false)]
        [object]$CustomContent = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$Width = 800,
        
        [Parameter(Mandatory = $false)]
        [int]$Height = 600,
        
        [Parameter(Mandatory = $false)]
        [string]$Name = "PageSkeleton_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    try {
        $skeleton = [PageSkeleton]::new($Type, $ShowHeader, $ShowSidebar, $ShowMainContent, $CustomContent)
        $skeleton.Name = $Name
        $skeleton.Width = $Width
        $skeleton.Height = $Height
        
        Write-SilentLog "PageSkeleton created: $Name [$Type]" 'DEBUG'
        return $skeleton
    }
    catch {
        Write-SilentLog "Failed to create PageSkeleton: $_" 'ERROR'
        throw "Failed to create PageSkeleton: $_"
    }
}

<#
.SYNOPSIS
    创建全屏加载骨架
#>
function New-FullPageSkeleton {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('default', 'dashboard', 'market')]
        [string]$Type = 'default',
        
        [Parameter(Mandatory = $false)]
        [int]$ParentWidth = 800,
        
        [Parameter(Mandatory = $false)]
        [int]$ParentHeight = 600
    )
    
    try {
        $skeleton = New-PageSkeleton -Type $Type -Width $ParentWidth -Height $ParentHeight
        $skeleton.Dock = [System.Windows.Forms.DockStyle]::Fill
        $skeleton.BringToFront()
        
        Write-SilentLog "FullPageSkeleton created [$Type]" 'DEBUG'
        return $skeleton
    }
    catch {
        Write-SilentLog "Failed to create FullPageSkeleton: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    创建卡片式骨架
#>
function New-CardSkeleton {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Width = 300,
        
        [Parameter(Mandatory = $false)]
        [int]$Height = 200
    )
    
    try {
        # 创建简单的卡片骨架
        $card = New-Object System.Windows.Forms.Panel
        $card.Width = $Width
        $card.Height = $Height
        $card.BackColor = $global:NordicTheme.BackgroundSecondary
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $card.Padding = New-Object System.Windows.Forms.Padding(12)
        
        # 启用双缓冲
        $card.GetType().GetProperty("DoubleBuffered", 
            [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic).SetValue($card, $true, $null)
        
        # 添加脉冲动画定时器
        $pulseTimer = New-Object System.Windows.Forms.Timer
        $pulseTimer.Interval = 16
        $pulseProgress = 0
        $pulseDirection = $true
        
        $pulseTimer.add_Tick({
            # 更新脉冲进度
            if ($pulseDirection) {
                $pulseProgress += 0.02
                if ($pulseProgress -ge 1) {
                    $pulseProgress = 1
                    $pulseDirection = $false
                }
            } else {
                $pulseProgress -= 0.02
                if ($pulseProgress -le 0) {
                    $pulseProgress = 0
                    $pulseDirection = $true
                }
            }
            
            $card.Invalidate()
        })
        
        # 添加绘制事件
        $card.Add_Paint({
            param($sender, $e)
            
            # 计算脉冲颜色
            $baseColor = $sender.BackColor
            $pulseIntensity = $pulseProgress * 0.15
            
            $gradientColor = [System.Drawing.Color]::FromArgb(
                $baseColor.A,
                [Math]::Min(255, [int]($baseColor.R * (1 + $pulseIntensity))),
                [Math]::Min(255, [int]($baseColor.G * (1 + $pulseIntensity))),
                [Math]::Min(255, [int]($baseColor.B * (1 + $pulseIntensity)))
            )
            
            # 绘制渐变背景
            $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $sender.ClientRectangle,
                $baseColor,
                $gradientColor,
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            
            $e.Graphics.FillRectangle($gradientBrush, $sender.ClientRectangle)
            $gradientBrush.Dispose()
        })
        
        # 存储定时器引用
        $card | Add-Member -NotePropertyName 'PulseTimer' -NotePropertyValue $pulseTimer
        $card | Add-Member -MemberType ScriptMethod -Name 'StartPulse' -Value {
            $this.PulseTimer.Start()
        }
        $card | Add-Member -MemberType ScriptMethod -Name 'StopPulse' -Value {
            $this.PulseTimer.Stop()
        }
        $card | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value {
            if ($this.PulseTimer.Enabled) {
                $this.PulseTimer.Stop()
            }
            $this.PulseTimer.Dispose()
            $this.base.Dispose()
        }
        
        # 开始脉冲动画
        $pulseTimer.Start()
        
        Write-SilentLog "CardSkeleton created" 'DEBUG'
        return $card
    }
    catch {
        Write-SilentLog "Failed to create CardSkeleton: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    创建文本骨架
#>
function New-TextSkeleton {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Lines = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxWidth = 400
    )
    
    try {
        $container = New-Object System.Windows.Forms.Panel
        $container.AutoSize = $true
        $container.Padding = New-Object System.Windows.Forms.Padding(5)
        
        $lineHeight = 20
        $lineSpacing = 10
        $currentY = 0
        
        for ($i = 0; $i -lt $Lines; $i++) {
            # 每行随机宽度（70%-100%）
            $lineWidth = $MaxWidth * (0.7 + (Get-Random -Minimum 0 -Maximum 31) / 100)
            
            $linePanel = New-Object System.Windows.Forms.Panel
            $linePanel.Width = $lineWidth
            $linePanel.Height = $lineHeight
            $linePanel.BackColor = $global:NordicTheme.BackgroundSecondary
            $linePanel.Location = New-Object System.Drawing.Point(0, $currentY)
            
            # 启用双缓冲
            $linePanel.GetType().GetProperty("DoubleBuffered", 
                [System.Reflection.BindingFlags]::Instance -bor 
                [System.Reflection.BindingFlags]::NonPublic).SetValue($linePanel, $true, $null)
            
            # 添加脉冲动画
            $pulseTimer = New-Object System.Windows.Forms.Timer
            $pulseTimer.Interval = 16
            $pulseProgress = 0
            $pulseDirection = $true
            
            $pulseTimer.add_Tick({
                if ($pulseDirection) {
                    $pulseProgress += 0.02
                    if ($pulseProgress -ge 1) {
                        $pulseProgress = 1
                        $pulseDirection = $false
                    }
                } else {
                    $pulseProgress -= 0.02
                    if ($pulseProgress -le 0) {
                        $pulseProgress = 0
                        $pulseDirection = $true
                    }
                }
                
                $linePanel.Invalidate()
            })
            
            $linePanel.Add_Paint({
                param($sender, $e)
                
                $baseColor = $sender.BackColor
                $pulseIntensity = $pulseProgress * 0.2
                
                $gradientColor = [System.Drawing.Color]::FromArgb(
                    $baseColor.A,
                    [Math]::Min(255, [int]($baseColor.R * (1 + $pulseIntensity))),
                    [Math]::Min(255, [int]($baseColor.G * (1 + $pulseIntensity))),
                    [Math]::Min(255, [int]($baseColor.B * (1 + $pulseIntensity)))
                )
                
                $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                    $sender.ClientRectangle,
                    $baseColor,
                    $gradientColor,
                    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
                )
                
                $e.Graphics.FillRectangle($gradientBrush, $sender.ClientRectangle)
                $gradientBrush.Dispose()
            })
            
            # 存储定时器引用
            $linePanel | Add-Member -NotePropertyName 'PulseTimer' -NotePropertyValue $pulseTimer
            $linePanel | Add-Member -MemberType ScriptMethod -Name 'StartPulse' -Value {
                $this.PulseTimer.Start()
            }
            $linePanel | Add-Member -MemberType ScriptMethod -Name 'StopPulse' -Value {
                $this.PulseTimer.Stop()
            }
            
            $container.Controls.Add($linePanel)
            $currentY += $lineHeight + $lineSpacing
            
            # 延迟启动每行动画，创建波浪效果
            $delay = $i * 100  # 每行延迟100毫秒
            Start-Sleep -Milliseconds $delay
            $pulseTimer.Start()
        }
        
        $container.Height = $currentY
        
        Write-SilentLog "TextSkeleton created with $Lines lines" 'DEBUG'
        return $container
    }
    catch {
        Write-SilentLog "Failed to create TextSkeleton: $_" 'ERROR'
        throw
    }
}

# ============================================================
# 辅助函数
# ============================================================

<#
.SYNOPSIS
    显示加载骨架屏
#>
function Show-LoadingSkeleton {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Parent,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('default', 'dashboard', 'market')]
        [string]$Type = 'default',
        
        [Parameter(Mandatory = $false)]
        [string]$SkeletonName = "LoadingSkeleton_$(Get-Random -Minimum 1000 -Maximum 9999)"
    )
    
    try {
        $skeleton = New-FullPageSkeleton -Type $Type -ParentWidth $Parent.Width -ParentHeight $Parent.Height
        $skeleton.Name = $SkeletonName
        $Parent.Controls.Add($skeleton)
        $skeleton.BringToFront()
        
        Write-SilentLog "Loading skeleton shown: $SkeletonName" 'DEBUG'
        return $skeleton
    }
    catch {
        Write-SilentLog "Failed to show loading skeleton: $_" 'ERROR'
        throw
    }
}

<#
.SYNOPSIS
    隐藏加载骨架屏
#>
function Hide-LoadingSkeleton {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Parent,
        
        [Parameter(Mandatory = $false)]
        [string]$SkeletonName
    )
    
    try {
        if ($SkeletonName) {
            $skeleton = $Parent.Controls[$SkeletonName]
            if ($null -ne $skeleton) {
                $skeleton.Dispose()
                $Parent.Controls.Remove($skeleton)
                Write-SilentLog "Loading skeleton hidden: $SkeletonName" 'DEBUG'
            }
        } else {
            # 移除所有骨架屏
            $skeletons = $Parent.Controls | Where-Object { $_.GetType().Name -eq 'PageSkeleton' }
            foreach ($skeleton in $skeletons) {
                $skeleton.Dispose()
                $Parent.Controls.Remove($skeleton)
            }
            Write-SilentLog "All loading skeletons hidden" 'DEBUG'
        }
        
        return $true
    }
    catch {
        Write-SilentLog "Failed to hide loading skeleton: $_" 'ERROR'
        return $false
    }
}

# ============================================================
# 模块初始化
# ============================================================

try {
    Write-SilentLog "PageSkeleton Module v1.0.0 loaded successfully" 'INFO'
}
catch {
    Write-SilentLog "Failed to initialize PageSkeleton module: $_" 'ERROR'
}

# 导出函数
$functionList = @(
    'New-PageSkeleton',
    'New-FullPageSkeleton',
    'New-CardSkeleton',
    'New-TextSkeleton',
    'Show-LoadingSkeleton',
    'Hide-LoadingSkeleton'
)