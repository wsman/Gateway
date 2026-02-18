<#
.SYNOPSIS
    端口冲突解决模块 - 智能端口管理和自动冲突解决

.DESCRIPTION
    提供智能端口冲突检测、自动端口查找和配置更新功能
    当指定端口被占用时，自动尝试查找相邻可用端口

.VERSION
    1.0.0
.CREATED
    2026-02-16
.LAST_UPDATED
    2026-02-16
#>

# Error logging function for PortConflictResolver module
function Write-PortResolverErrorLog {
    param(
        [string]$Message,
        [string]$Operation = "PortResolver"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = Join-Path $env:TEMP "GatewayLauncher_errors.log"
    $logEntry = "[$timestamp] [PortResolver] $Operation - $Message`n"
    try {
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

<#
.SYNOPSIS
    智能端口冲突解决 - 自动查找可用端口

.DESCRIPTION
    当指定端口被占用时，自动尝试查找相邻可用端口
    支持端口范围扫描和智能端口选择

.PARAMETER BasePort
    基础端口号，从此端口开始检查

.PARAMETER MaxAttempts
    最大尝试次数，默认10次

.PARAMETER PortRange
    端口扫描范围，默认检查相邻端口

.OUTPUTS
    System.Int32 - 可用的端口号
#>
function Find-AvailablePort {
    param(
        [Parameter(Mandatory=$true)]
        [int]$BasePort,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxAttempts = 10,
        
        [Parameter(Mandatory=$false)]
        [int]$PortRange = 100
    )
    
    try {
        # 检查基础端口
        $portCheck = Test-NetworkPort -Port $BasePort
        if (-not $portCheck.IsInUse) {
            Write-SilentLog "端口 $BasePort 可用" 'INFO'
            return $BasePort
        }
        
        Write-SilentLog "端口 $BasePort 已被占用，正在查找可用端口..." 'INFO'
        
        # 在端口范围内查找可用端口
        $attempt = 0
        $port = $BasePort
        
        while ($attempt -lt $MaxAttempts) {
            # 优先尝试常用端口偏移量
            $offset = switch ($attempt) {
                0 { 1 }   # +1
                1 { -1 }  # -1
                2 { 10 }  # +10
                3 { -10 } # -10
                4 { 2 }   # +2
                5 { -2 }  # -2
                6 { 5 }   # +5
                7 { -5 }  # -5
                8 { 100 } # +100
                9 { -100 }# -100
                default { 0 }
            }
            
            $port = $BasePort + $offset
            
            # 确保端口在有效范围内 (1024-65535)
            if ($port -lt 1024 -or $port -gt 65535) {
                $port = Get-Random -Minimum 49152 -Maximum 65535  # 使用动态端口范围
                Write-SilentLog "使用随机动态端口: $port" 'INFO'
            }
            
            Write-SilentLog "尝试端口: $port" 'DEBUG'
            
            # 检查端口是否被占用
            $portCheck = Test-NetworkPort -Port $port
            
            if (-not $portCheck.IsInUse) {
                Write-SilentLog "找到可用端口: $port" 'INFO'
                Write-PortResolverErrorLog -Message "端口 $BasePort 被占用，自动切换到端口 $port" -Operation "Find-AvailablePort"
                Show-AppErrorDialog -Message "端口 $BasePort 已被占用，已自动切换到端口 $port" -Title "端口冲突解决" -Suggestions @(
                    "新的网关地址: http://localhost:$port",
                    "可以在设置中修改默认端口",
                    "如果需要使用特定端口，请确保端口未被其他应用占用"
                )
                return $port
            }
            
            $attempt++
        }
        
        # 如果未找到可用端口，使用随机端口
        $randomPort = Get-Random -Minimum 49152 -Maximum 65535
        Write-SilentLog "在范围内未找到可用端口，使用随机端口: $randomPort" 'INFO'
        Write-PortResolverErrorLog -Message "无法在 $MaxAttempts 次尝试内找到可用端口，使用随机端口 $randomPort" -Operation "Find-AvailablePort"
        Show-AppErrorDialog -Message "无法找到可用端口，已使用随机端口: $randomPort" -Title "端口冲突警告" -Suggestions @(
            "新的网关地址: http://localhost:$randomPort",
            "建议在设置中配置一个固定端口范围",
            "检查是否有其他应用占用了大量端口"
        )
        return $randomPort
    }
    catch {
        Write-PortResolverErrorLog -Message "端口查找失败: $_" -Operation "Find-AvailablePort"
        Write-SilentLog "端口查找失败，使用基础端口: $BasePort" 'INFO'
        return $BasePort
    }
}

<#
.SYNOPSIS
    检查网络端口状态

.DESCRIPTION
    检查指定端口是否被占用

.PARAMETER Port
    要检查的端口号

.OUTPUTS
    PSCustomObject - 包含端口状态信息
#>
function Test-NetworkPort {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    $result = [PSCustomObject]@{
        Port = $Port
        IsInUse = $false
        ProcessInfo = $null
    }
    
    try {
        # 使用netstat检查端口状态
        $conns = netstat -ano 2>$null | Select-String ":$Port" | Select-String "LISTENING"
        
        if ($conns) {
            $result.IsInUse = $true
            
            # 尝试获取进程信息
            foreach ($c in $conns) {
                $id = ($c -split '\s+')[-1]
                if ($id -match '^\d+$') {
                    try {
                        $process = Get-Process -Id $id -ErrorAction SilentlyContinue
                        if ($process) {
                            $result.ProcessInfo = @{
                                PID = $id
                                Name = $process.ProcessName
                                Path = $process.Path
                            }
                            break
                        }
                    }
                    catch {
                        # 无法获取进程详情，继续下一个
                    }
                }
            }
        }
    }
    catch {
        # 如果检查失败，假设端口不可用
        $result.IsInUse = $true
    }
    
    return $result
}

<#
.SYNOPSIS
    智能启动网关 - 自动处理端口冲突

.DESCRIPTION
    启动网关前检查端口冲突，自动切换到可用端口
    支持配置更新和端口重试逻辑

.PARAMETER StartMethod
    启动方法: "Foreground" 或 "Background"

.PARAMETER GatewayPort
    网关端口号（引用类型，可能被修改）

.PARAMETER ProjectPath
    项目路径

.PARAMETER MaxRetries
    最大重试次数，默认3次

.PARAMETER ConfigPath
    配置文件路径，用于更新端口配置

.OUTPUTS
    System.Boolean - 启动是否成功
#>
function Start-GatewaySmart {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Foreground", "Background")]
        [string]$StartMethod,
        
        [Parameter(Mandatory=$true)]
        [ref]$GatewayPort,
        
        [Parameter(Mandatory=$true)]
        [string]$ProjectPath,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = $null
    )
    
    $retryCount = 0
    $success = $false
    
    while (-not $success -and $retryCount -lt $MaxRetries) {
        try {
            # 获取当前端口配置
            $currentPort = $GatewayPort.Value
            
            # 检查端口并尝试解决冲突
            $portInUse = Test-NetworkPort -Port $currentPort
            
            if ($portInUse.IsInUse) {
                Write-SilentLog "检测到端口 $currentPort 被占用，正在查找可用端口..." 'INFO'
                $newPort = Find-AvailablePort -BasePort $currentPort
                
                # 更新端口引用
                $GatewayPort.Value = $newPort
                
                # 如果提供了配置文件路径，更新配置
                if (-not [string]::IsNullOrEmpty($ConfigPath) -and (Test-Path $ConfigPath)) {
                    try {
                        $config = Get-Content $ConfigPath | ConvertFrom-Json
                        $config.GatewayPort = $newPort
                        $config | ConvertTo-Json | Set-Content $ConfigPath
                        Write-SilentLog "已更新配置文件端口为: $newPort" 'INFO'
                    }
                    catch {
                        Write-PortResolverErrorLog -Message "更新配置文件失败: $_" -Operation "Start-GatewaySmart"
                    }
                }
                
                Write-SilentLog "已更新网关端口为: $newPort" 'INFO'
                
                # 返回更新后的端口号
                return @{
                    Success = $true
                    Port = $newPort
                    WasChanged = $true
                    OriginalPort = $currentPort
                }
            }
            
            # 端口可用，直接返回
            return @{
                Success = $true
                Port = $currentPort
                WasChanged = $false
                OriginalPort = $currentPort
            }
        }
        catch {
            $retryCount++
            Write-SilentLog "端口检查失败 (尝试 $retryCount/$MaxRetries): $_" 'WARN'
            
            if ($retryCount -ge $MaxRetries) {
                Write-PortResolverErrorLog -Message "端口检查失败，已达到最大重试次数: $retryCount" -Operation "Start-GatewaySmart"
                Show-AppErrorDialog -Message "端口检查失败，已达到最大重试次数。请检查网络设置。" -Title "端口检查失败" -Suggestions @(
                    "检查网络连接",
                    "确认防火墙设置",
                    "尝试重启应用程序"
                )
                return @{
                    Success = $false
                    Port = $GatewayPort.Value
                    WasChanged = $false
                    OriginalPort = $GatewayPort.Value
                    Error = $_.Exception.Message
                }
            }
            
            # 等待后重试
            Start-Sleep -Seconds 2
        }
    }
    
    return @{
        Success = $false
        Port = $GatewayPort.Value
        WasChanged = $false
        OriginalPort = $GatewayPort.Value
        Error = "达到最大重试次数"
    }
}

<#
.SYNOPSIS
    清理指定端口的所有连接

.DESCRIPTION
    强制终止占用指定端口的所有进程

.PARAMETER Port
    要清理的端口号

.PARAMETER Force
    是否强制终止进程（默认：true）

.OUTPUTS
    System.Int32 - 终止的进程数量
#>
function Clean-PortProcesses {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port,
        
        [Parameter(Mandatory=$false)]
        [bool]$Force = $true
    )
    
    $killedCount = 0
    
    try {
        # 查找监听指定端口的进程
        $conns = netstat -ano 2>$null | Select-String ":$Port" | Select-String "LISTENING"
        
        if ($conns) {
            Write-SilentLog "找到 $($conns.Count) 个占用端口 $Port 的进程" 'INFO'
            
            foreach ($c in $conns) {
                $id = ($c -split '\s+')[-1]
                if ($id -match '^\d+$') {
                    try {
                        # 获取进程信息
                        $process = Get-Process -Id $id -ErrorAction SilentlyContinue
                        $processName = if ($process) { $process.ProcessName } else { "未知进程" }
                        
                        if ($Force) {
                            # 强制终止进程
                            taskkill /PID $id /F 2>$null | Out-Null
                            Write-SilentLog "已终止进程 $id ($processName)" 'INFO'
                            $killedCount++
                        }
                        else {
                            Write-SilentLog "发现进程 $id ($processName) 占用端口 $Port" 'WARN'
                        }
                    }
                    catch {
                        Write-PortResolverErrorLog -Message "无法终止进程 ${id}: $_" -Operation "Clean-PortProcesses"
                    }
                }
            }
        }
        else {
            Write-SilentLog "没有发现占用端口 $Port 的进程" 'INFO'
        }
    }
    catch {
        Write-PortResolverErrorLog -Message "清理端口进程失败: $_" -Operation "Clean-PortProcesses"
    }
    
    return $killedCount
}

<#
.SYNOPSIS
    验证端口配置

.DESCRIPTION
    检查端口配置是否有效，提供修复建议

.PARAMETER Port
    要验证的端口号

.OUTPUTS
    PSCustomObject - 验证结果和建议
#>
function Validate-PortConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    $validation = [PSCustomObject]@{
        Port = $Port
        IsValid = $true
        Warnings = @()
        Suggestions = @()
    }
    
    # 检查端口范围
    if ($Port -lt 1024) {
        $validation.IsValid = $false
        $validation.Warnings += "端口 $Port 是系统保留端口（<1024）"
        $validation.Suggestions += "建议使用大于1024的端口"
    }
    elseif ($Port -gt 65535) {
        $validation.IsValid = $false
        $validation.Warnings += "端口 $Port 超出有效范围（>65535）"
        $validation.Suggestions += "端口号必须在1-65535之间"
    }
    elseif ($Port -ge 49152 -and $Port -le 65535) {
        # 动态/私有端口范围
        $validation.Warnings += "端口 $Port 在动态/私有端口范围（49152-65535）"
        $validation.Suggestions += "建议使用固定端口范围（1024-49151）以避免冲突"
    }
    
    # 检查端口是否被占用
    $portCheck = Test-NetworkPort -Port $Port
    if ($portCheck.IsInUse) {
        $validation.IsValid = $false
        $processInfo = if ($portCheck.ProcessInfo) {
            "进程: $($portCheck.ProcessInfo.Name) (PID: $($portCheck.ProcessInfo.PID))"
        } else {
            "未知进程"
        }
        $validation.Warnings += "端口 $Port 已被占用 - $processInfo"
        $validation.Suggestions += "使用 Find-AvailablePort 函数查找可用端口"
        $validation.Suggestions += "使用 Clean-PortProcesses 函数清理占用进程"
    }
    
    return $validation
}

# ============================================================
# Module Initialization
# ============================================================

Write-SilentLog "端口冲突解决模块 v1.0.0 已加载" 'INFO'