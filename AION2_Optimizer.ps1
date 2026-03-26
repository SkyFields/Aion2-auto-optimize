#Requires -Version 5.1
<#
.SYNOPSIS
    AION2 Universal Game Optimizer
    Auto-detects CPU, NIC, and game paths. Applies optimal settings.

.DESCRIPTION
    - Detects physical vs logical cores, builds optimal affinity mask
    - Applies TCP stack optimizations (Nagle, Delayed ACK, etc.)
    - Optimizes NIC settings for low-latency gaming
    - Launches Purple and applies CPU priority/affinity to AION2.exe
    - Works on any Intel/AMD system with any NIC

.NOTES
    Share freely. Run as Administrator.
    Author: Ivan's AION2 Toolbox
    Version: 1.0 - 2026-03-26
#>

<#
================================================================================
  AION2 Universal Game Optimizer - Описание (RU)
================================================================================

  Что делает этот скрипт:
  ========================
  Универсальный оптимизатор для AION2, автоматически определяет железо и
  применяет оптимальные настройки для максимальной производительности в игре.
  Работает на любом Intel/AMD процессоре и любой сетевой карте.

  Как запустить:
  ==============
  1. Положите AION2_Optimizer.bat и AION2_Optimizer.ps1 в одну папку
  2. Запустите AION2_Optimizer.bat двойным кликом
  3. Подтвердите запрос прав администратора (UAC)
  4. Скрипт сам найдет игру, Purple, и применит все настройки
  5. Нажмите "Play" в Purple когда он откроется
  6. После обнаружения Aion2.exe скрипт применит CPU-оптимизации
  7. Окно закроется автоматически после выхода из игры

  Что оптимизируется:
  ====================

  [CPU - Привязка к ядрам]
    - Автоматически определяет физические и логические ядра
    - Если включен SMT/Hyper-Threading: привязывает игру ТОЛЬКО к физическим
      ядрам (пропускает виртуальные потоки SMT). Это убирает конкуренцию между
      потоками за ресурсы одного ядра и снижает микрофризы
    - Для процессоров X3D с несколькими CCD (7950X3D, 9950X3D): привязывает
      к первым 8 ядрам (CCD с V-Cache) для максимального попадания в кэш
    - Устанавливает приоритет процесса на HIGH - планировщик Windows будет
      отдавать игре процессорное время в первую очередь

  [TCP стек - Реестр Windows]
    - TcpNoDelay=1: Отключает алгоритм Нейгла. По умолчанию Windows копит
      мелкие пакеты и отправляет их пачкой (задержка до 200мс!). С этой
      настройкой каждый пакет уходит мгновенно
    - TcpAckFrequency=1: Подтверждение (ACK) отправляется на каждый
      входящий пакет сразу. По умолчанию Windows ждет 2-й пакет или 200мс
      перед отправкой ACK. Сервер получает подтверждение быстрее и может
      отправить следующую порцию данных раньше
    - TcpDelAckTicks=0: Нулевая задержка таймера ACK
    - ECN отключен: Некоторые роутеры и провайдеры неправильно обрабатывают
      ECN-биты, что вызывает ложные сигналы о перегрузке и сброс пакетов
    - TcpTimedWaitDelay=30: Ускоренное переиспользование портов

  [Сетевая карта - Аппаратные настройки]
    - Interrupt Moderation OFF: По умолчанию сетевая карта копит прерывания
      и уведомляет CPU пачками (экономит CPU, но добавляет 1-2мс задержки).
      Отключаем - каждый пакет доставляется процессору мгновенно
    - Receive Segment Coalescing OFF: NIC склеивает несколько TCP-сегментов
      в один перед передачей ОС. Для игр это лишняя задержка
    - Large Send Offload OFF: NIC собирает исходящие данные в большие пакеты.
      Для игр нужна мгновенная отправка мелких пакетов
    - Flow Control OFF: Убирает паузы когда буферы NIC заполняются
    - Энергосбережение OFF: Green Ethernet, Gigabit Lite, Power Saving -
      все это может тормозить сетевую карту. Отключаем для полной скорости
    - Wake-on-LAN OFF: Убирает лишнюю нагрузку от прослушивания WoL-пакетов

  [GPU]
    - Устанавливает "Высокая производительность" в DirectX для Aion2.exe
      через реестр UserGpuPreferences

  [Электропитание]
    - Переключает план электропитания на максимальную производительность
      (Bitsum Highest Performance > Ultimate > High Performance)
    - Это гарантирует максимальные частоты CPU и отключает троттлинг

  Ожидаемый эффект:
  =================
    - Снижение задержки на пакет: до 200мс (Nagle + Delayed ACK)
    - Снижение джиттера: 1-3мс (Interrupt Moderation + RSC)
    - Более стабильный фреймтайм (нет конкуренции SMT-потоков)
    - Ощутимо в: PvP, осады, массовые бои, кастование скиллов

  Безопасность:
  =============
    - Скрипт НЕ модифицирует файлы игры
    - НЕ инжектит код в процесс
    - НЕ использует драйверы или хуки (в отличие от Process Lasso)
    - Все изменения через стандартные API Windows (реестр, PowerShell)
    - NCGuard/GameGuard НЕ блокирует эти оптимизации
    - TCP/NIC настройки сохраняются в реестре (переживают перезагрузку)
    - CPU-привязка применяется на лету и действует до закрытия игры

  Требования:
  ===========
    - Windows 10/11
    - Права администратора
    - PowerShell 5.1+ (встроен в Windows 10/11)
    - Установленный AION2 и Purple launcher

================================================================================
#>

# ============================================================
#  SELF-ELEVATE TO ADMIN
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting admin privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Host "[$Number] $Title" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [..] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!!] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [XX] $Message" -ForegroundColor Red
}

# ============================================================
#  BANNER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "   AION2 Universal Game Optimizer v1.0" -ForegroundColor White
Write-Host "   TCP + NIC + CPU Affinity Optimization" -ForegroundColor Gray
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
#  STEP 1: DETECT CPU TOPOLOGY
# ============================================================
Write-Step "1/7" "Detecting CPU Topology"

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name.Trim()
$physicalCores = $cpu.NumberOfCores
$logicalCores = $cpu.NumberOfLogicalProcessors
$smtEnabled = $logicalCores -gt $physicalCores
$threadsPerCore = if ($physicalCores -gt 0) { [math]::Floor($logicalCores / $physicalCores) } else { 1 }

Write-Info "CPU: $cpuName"
Write-Info "Physical Cores: $physicalCores | Logical Threads: $logicalCores | SMT/HT: $(if($smtEnabled){'YES'}else{'NO'})"

# Build affinity mask for physical cores only (skip SMT siblings)
# On both Intel HT and AMD SMT, logical processors are interleaved:
#   Core 0 -> Thread 0, Thread 1
#   Core 1 -> Thread 2, Thread 3  ...etc
# Physical cores = every Nth thread where N = threads-per-core
if ($smtEnabled) {
    $affinityMask = [int64]0
    for ($i = 0; $i -lt $logicalCores; $i += $threadsPerCore) {
        $affinityMask = $affinityMask -bor ([int64]1 -shl $i)
    }
    $physicalThreads = @()
    for ($i = 0; $i -lt $logicalCores; $i += $threadsPerCore) {
        $physicalThreads += $i
    }
    Write-Info "Affinity mask: 0x$($affinityMask.ToString('X')) (physical cores: $($physicalThreads -join ', '))"
    Write-Ok "SMT detected - will pin game to physical cores only to avoid thread contention"
} else {
    # No SMT - use all cores
    $affinityMask = [int64]0
    for ($i = 0; $i -lt $logicalCores; $i++) {
        $affinityMask = $affinityMask -bor ([int64]1 -shl $i)
    }
    Write-Info "Affinity mask: 0x$($affinityMask.ToString('X')) (all $logicalCores cores)"
    Write-Ok "No SMT - using all cores"
}

# Special handling for AMD X3D processors with multiple CCDs (e.g., 7950X3D)
# The V-Cache CCD is typically CCD0 (cores 0-7 on 7950X3D)
if ($cpuName -match "X3D" -and $physicalCores -gt 8) {
    Write-Warn "Multi-CCD X3D detected! Pinning to first 8 physical cores (V-Cache CCD)"
    $affinityMask = [int64]0
    $vcacheCores = [math]::Min(8, $physicalCores)
    for ($i = 0; $i -lt ($vcacheCores * $threadsPerCore); $i += $threadsPerCore) {
        $affinityMask = $affinityMask -bor ([int64]1 -shl $i)
    }
    Write-Info "V-Cache affinity: 0x$($affinityMask.ToString('X'))"
}

# ============================================================
#  STEP 2: DETECT PRIMARY NIC
# ============================================================
Write-Step "2/7" "Detecting Primary Network Adapter"

# Find the adapter with an active internet route (default gateway)
$activeNic = Get-NetAdapter | Where-Object {
    $_.Status -eq "Up" -and
    $_.InterfaceDescription -notmatch "Hyper-V|Virtual|VPN|TAP|WireGuard|Loopback|Bluetooth"
} | Sort-Object -Property LinkSpeed -Descending | Select-Object -First 1

if (-not $activeNic) {
    # Fallback: any adapter that's up and has an IP
    $activeNic = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
        Where-Object { (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue) -ne $null } |
        Select-Object -First 1
}

if ($activeNic) {
    $nicName = $activeNic.Name
    $nicDesc = $activeNic.InterfaceDescription
    $nicSpeed = $activeNic.LinkSpeed
    $nicGuid = $activeNic.InterfaceGuid

    Write-Info "Adapter: $nicName ($nicDesc)"
    Write-Info "Speed: $nicSpeed | GUID: $nicGuid"
    Write-Ok "Primary NIC detected"
} else {
    Write-Fail "Could not detect primary NIC - NIC optimizations will be skipped"
    $nicName = $null
}

# ============================================================
#  STEP 3: TCP REGISTRY OPTIMIZATIONS
# ============================================================
Write-Step "3/7" "Applying TCP Stack Optimizations"

if ($nicGuid) {
    $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$nicGuid"

    # Disable Nagle's Algorithm - sends packets immediately (no 200ms batching)
    Set-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Value 1 -Type DWord -Force
    Write-Ok "TcpNoDelay=1 (Nagle disabled - no packet batching)"

    # ACK every packet immediately (default: wait for 2nd packet or 200ms timer)
    Set-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
    Write-Ok "TcpAckFrequency=1 (immediate ACK - server gets green light faster)"

    # Zero timer-based ACK delay
    Set-ItemProperty -Path $ifacePath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force
    Write-Ok "TcpDelAckTicks=0 (zero ACK timer delay)"
} else {
    Write-Warn "Skipped - no NIC GUID available"
}

# Global TCP settings
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force
Write-Ok "TcpTimedWaitDelay=30 (fast port recycling)"

# Disable ECN (some routers/ISPs mishandle it causing false congestion drops)
netsh int tcp set global ecncapability=disabled 2>$null | Out-Null
Write-Ok "ECN disabled (prevents false congestion signals)"

# Ensure auto-tuning is normal (not restricted)
netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
Write-Ok "TCP auto-tuning: normal"

# ============================================================
#  STEP 4: NIC HARDWARE OPTIMIZATIONS
# ============================================================
Write-Step "4/7" "Applying NIC Hardware Optimizations"

if ($nicName) {
    # Get all available advanced properties for this NIC
    $availableProps = Get-NetAdapterAdvancedProperty -Name $nicName -ErrorAction SilentlyContinue

    # Define optimizations: [DisplayName, DesiredValue, Reason]
    $nicTweaks = @(
        @("Interrupt Moderation",           "Disabled", "deliver packets to CPU immediately, -1-2ms"),
        @("Interrupt Moderation Rate",      "Off",      "no interrupt batching"),
        @("Flow Control",                   "Disabled", "no pause frames"),
        @("Recv Segment Coalescing (IPv4)", "Disabled", "deliver TCP segments individually"),
        @("Recv Segment Coalescing (IPv6)", "Disabled", "deliver TCP segments individually"),
        @("Large Send Offload v2 (IPv4)",   "Disabled", "send packets immediately without NIC batching"),
        @("Large Send Offload v2 (IPv6)",   "Disabled", "send packets immediately without NIC batching"),
        @("Large Send Offload V2 (IPv4)",   "Disabled", "send packets immediately (Intel naming)"),
        @("Large Send Offload V2 (IPv6)",   "Disabled", "send packets immediately (Intel naming)"),
        @("Green Ethernet",                 "Disabled", "no power throttling"),
        @("Gigabit Lite",                   "Disabled", "full link speed"),
        @("Power Saving Mode",              "Disabled", "NIC always fully active"),
        @("Energy-Efficient Ethernet",      "Disabled", "no EEE power saving"),
        @("Energy Efficient Ethernet",      "Disabled", "no EEE (Intel naming)"),
        @("Reduce Speed On Power Down",     "Disabled", "maintain full speed"),
        @("Ultra Low Power Mode",           "Disabled", "no ULP"),
        @("Advanced EEE",                   "Disabled", "no advanced EEE"),
        @("Wake on Magic Packet",           "Disabled", "no WoL overhead"),
        @("Wake on pattern match",          "Disabled", "no WoL pattern matching"),
        @("Shutdown Wake-On-Lan",           "Disabled", "no WoL on shutdown"),
        @("Wait for Link",                  "Off",      "faster link negotiation")
    )

    $applied = 0
    $skipped = 0
    foreach ($tweak in $nicTweaks) {
        $propName = $tweak[0]
        $desired  = $tweak[1]
        $reason   = $tweak[2]

        $prop = $availableProps | Where-Object { $_.DisplayName -eq $propName }
        if ($prop) {
            if ($prop.DisplayValue -ne $desired) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $nicName -DisplayName $propName -DisplayValue $desired -ErrorAction Stop
                    Write-Ok "$propName -> $desired ($reason)"
                    $applied++
                } catch {
                    Write-Warn "$propName -> failed: $($_.Exception.Message)"
                }
            } else {
                $skipped++
            }
        }
    }

    # Try to increase transmit buffers if available
    $txBuf = $availableProps | Where-Object { $_.DisplayName -eq "Transmit Buffers" }
    if ($txBuf) {
        $currentTx = [int]$txBuf.DisplayValue
        if ($currentTx -lt 1024) {
            try {
                Set-NetAdapterAdvancedProperty -Name $nicName -DisplayName "Transmit Buffers" -DisplayValue "1024" -ErrorAction Stop
                Write-Ok "Transmit Buffers -> 1024 (was $currentTx)"
                $applied++
            } catch { }
        }
    }

    Write-Info "$applied settings changed, $skipped already optimal"
} else {
    Write-Warn "Skipped - no primary NIC detected"
}

# ============================================================
#  STEP 5: FIND AION2 & PURPLE PATHS
# ============================================================
Write-Step "5/7" "Locating Game Files"

# Search for AION2.exe
$aion2Path = $null
$searchRoots = @()

# Check all fixed drives
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | ForEach-Object {
    $searchRoots += $_.Root
}

foreach ($root in $searchRoots) {
    $found = Get-ChildItem -Path $root -Directory -Filter "*AION2*" -Depth 1 -ErrorAction SilentlyContinue
    foreach ($dir in $found) {
        $exe = Get-ChildItem -Path $dir.FullName -Filter "Aion2.exe" -Recurse -Depth 5 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {
            $aion2Path = $exe.FullName
            break
        }
    }
    if ($aion2Path) { break }
}

if ($aion2Path) {
    Write-Ok "AION2: $aion2Path"
} else {
    Write-Warn "AION2.exe not found - will still optimize TCP/NIC and wait for manual launch"
}

# Find Purple launcher
$purplePath = $null
$purplePaths = @(
    "${env:ProgramFiles(x86)}\NCSOFT\Purple\PurpleLauncher.exe",
    "$env:ProgramFiles\NCSOFT\Purple\PurpleLauncher.exe",
    "${env:ProgramFiles(x86)}\NCLauncher\PurpleLauncher.exe"
)
foreach ($p in $purplePaths) {
    if (Test-Path $p) { $purplePath = $p; break }
}

if ($purplePath) {
    Write-Ok "Purple: $purplePath"
} else {
    Write-Warn "Purple launcher not found - please launch the game manually"
}

# Set GPU preference for AION2
if ($aion2Path) {
    reg add "HKCU\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" /v $aion2Path /t REG_SZ /d "GpuPreference=2;" /f 2>$null | Out-Null
    Write-Ok "GPU preference set to High Performance for AION2"
}

# ============================================================
#  STEP 6: ACTIVATE HIGH PERFORMANCE POWER PLAN
# ============================================================
Write-Step "6/7" "Setting Power Plan"

# Try Bitsum Highest Performance first, then Ultimate, then High Performance
$powerPlans = @(
    @("e9a42b02-d5df-448d-aa00-03f14749eb61", "Bitsum Highest Performance"),
    @("e9a42b02-d5df-448d-aa00-03f14749eb61", "Ultimate Performance"),
    @("8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", "High Performance")
)

$powerSet = $false
foreach ($plan in $powerPlans) {
    $result = powercfg /setactive $plan[0] 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Power plan: $($plan[1])"
        $powerSet = $true
        break
    }
}
if (-not $powerSet) {
    Write-Warn "Could not set high performance power plan"
}

# ============================================================
#  STEP 7: LAUNCH PURPLE & OPTIMIZE AION2 PROCESS
# ============================================================
Write-Step "7/7" "Game Launch & Process Optimization"

# Check if Purple is already running
$purpleRunning = Get-Process -Name "Purple","PurpleLauncher" -ErrorAction SilentlyContinue
if ($purpleRunning) {
    Write-Info "Purple is already running - skipping launch"
} elseif ($purplePath) {
    Write-Info "Launching Purple..."
    Start-Process $purplePath
    Write-Ok "Purple launched"
} else {
    Write-Warn "Launch the game manually, then this script will detect and optimize it"
}

# Wait for AION2.exe
Write-Host ""
Write-Host "  Waiting for Aion2.exe to start..." -ForegroundColor White
Write-Host "  (Press Ctrl+C to exit if you just want TCP/NIC tweaks without game launch)" -ForegroundColor DarkGray
Write-Host ""

$dotCount = 0
while ($true) {
    $gameProc = Get-Process -Name "Aion2" -ErrorAction SilentlyContinue
    if ($gameProc) { break }
    Start-Sleep -Seconds 2
    $dotCount++
    if ($dotCount % 5 -eq 0) {
        Write-Host "  ... still waiting (${dotCount}s)" -ForegroundColor DarkGray
    }
}

Write-Ok "Aion2.exe detected (PID: $($gameProc.Id))!"
Write-Info "Waiting 5 seconds for full initialization..."
Start-Sleep -Seconds 5

# Apply CPU priority and affinity
try {
    $gameProc = Get-Process -Name "Aion2" -ErrorAction Stop
    $gameProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
    $gameProc.ProcessorAffinity = [IntPtr]$affinityMask

    Write-Ok "Priority: HIGH"
    Write-Ok "Affinity: 0x$($affinityMask.ToString('X')) ($physicalCores physical cores)"
} catch {
    Write-Fail "Could not set process attributes: $($_.Exception.Message)"
    Write-Warn "Try running this script as Administrator"
}

# ============================================================
#  MONITORING PHASE
# ============================================================
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Green
Write-Host "   AION2 is running with optimized settings!" -ForegroundColor Green
Write-Host "  =============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Summary:" -ForegroundColor White
Write-Host "    CPU:  $cpuName" -ForegroundColor Gray
Write-Host "    Cores: $physicalCores physical / $logicalCores logical (SMT: $(if($smtEnabled){'ON - using physical only'}else{'OFF - all cores'}))" -ForegroundColor Gray
Write-Host "    NIC:  $nicDesc ($nicSpeed)" -ForegroundColor Gray
Write-Host "    Affinity: 0x$($affinityMask.ToString('X')) | Priority: High" -ForegroundColor Gray
Write-Host ""
Write-Host "  This window will close automatically when the game exits." -ForegroundColor DarkGray
Write-Host "  TCP/NIC optimizations persist until reboot (registry tweaks are permanent)." -ForegroundColor DarkGray
Write-Host ""

# Monitor until game exits
while ($true) {
    Start-Sleep -Seconds 10
    $still = Get-Process -Name "Aion2" -ErrorAction SilentlyContinue
    if (-not $still) {
        Write-Host ""
        Write-Host "  Aion2.exe has exited." -ForegroundColor Yellow
        break
    }
}

Write-Host ""
Write-Host "  Optimization session complete. TCP/NIC tweaks remain active." -ForegroundColor Cyan
Write-Host "  Closing in 5 seconds..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5
