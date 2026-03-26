# AION2 Universal Game Optimizer

> TCP + NIC + CPU Affinity оптимизация для AION2 | TCP + NIC + CPU Affinity optimization for AION2

---

## Содержание / Table of Contents

- [Описание (RU)](#описание)
- [Description (EN)](#description)
- [Скачать / Download](#скачать--download)

---

## Описание

Универсальный оптимизатор для AION2, который автоматически определяет железо и применяет оптимальные настройки для максимальной производительности в игре. Работает на любом Intel/AMD процессоре и любой сетевой карте.

### Как запустить

1. Скачайте `AION2_Optimizer.bat` и `AION2_Optimizer.ps1` в одну папку
2. Запустите `AION2_Optimizer.bat` двойным кликом
3. Подтвердите запрос прав администратора (UAC)
4. Скрипт сам найдёт игру, Purple, и применит все настройки
5. Нажмите **Play** в Purple когда он откроется
6. После обнаружения `Aion2.exe` скрипт применит CPU-оптимизации
7. Окно закроется автоматически после выхода из игры

### Что оптимизируется

#### CPU — Привязка к ядрам

| Настройка | Что делает |
|---|---|
| Определение ядер | Автоматически находит физические и логические ядра |
| SMT/HT фильтрация | Привязывает игру **только к физическим ядрам**, пропуская виртуальные потоки SMT. Убирает конкуренцию потоков за ресурсы одного ядра, снижает микрофризы |
| X3D Multi-CCD | Для 7950X3D / 9950X3D — привязка к первым 8 ядрам (CCD с V-Cache) |
| Приоритет процесса | **HIGH** — планировщик Windows отдаёт игре процессорное время в первую очередь |

#### TCP стек — Реестр Windows

| Настройка | Значение | Что делает |
|---|---|---|
| TcpNoDelay | 1 | Отключает алгоритм Нейгла. По умолчанию Windows копит мелкие пакеты и отправляет пачкой (задержка до **200мс**). Теперь каждый пакет уходит мгновенно |
| TcpAckFrequency | 1 | ACK отправляется на каждый пакет сразу. По умолчанию Windows ждёт 2-й пакет или 200мс. Сервер получает подтверждение быстрее |
| TcpDelAckTicks | 0 | Нулевая задержка таймера ACK |
| ECN | Disabled | Некоторые роутеры/провайдеры неправильно обрабатывают ECN, вызывая ложный сброс пакетов |
| TcpTimedWaitDelay | 30 | Ускоренное переиспользование портов |

#### Сетевая карта — Аппаратные настройки

| Настройка | Что делает |
|---|---|
| Interrupt Moderation OFF | NIC перестаёт копить прерывания — каждый пакет доставляется CPU мгновенно (**-1-2мс**) |
| Recv Segment Coalescing OFF | NIC перестаёт склеивать TCP-сегменты — пакеты доставляются по одному |
| Large Send Offload OFF | Исходящие пакеты отправляются сразу, без сборки в большие блоки |
| Flow Control OFF | Убирает паузы при заполнении буферов |
| Энергосбережение OFF | Green Ethernet, Gigabit Lite, Power Saving, EEE — всё отключается |
| Wake-on-LAN OFF | Убирает лишнюю нагрузку от прослушивания WoL-пакетов |

#### GPU и электропитание

| Настройка | Что делает |
|---|---|
| DirectX GpuPreference | Устанавливает "Высокая производительность" для `Aion2.exe` |
| План электропитания | Переключает на максимальную производительность (Bitsum > Ultimate > High Performance) |

### Ожидаемый эффект

- Снижение задержки на пакет: **до 200мс** (Nagle + Delayed ACK)
- Снижение джиттера: **1-3мс** (Interrupt Moderation + RSC)
- Более стабильный фреймтайм (нет конкуренции SMT-потоков)
- Ощутимо в: PvP, осады, массовые бои, кастование скиллов

### Безопасность

- **НЕ** модифицирует файлы игры
- **НЕ** инжектит код в процесс
- **НЕ** использует драйверы или хуки (в отличие от Process Lasso)
- Все изменения через стандартные API Windows (реестр, PowerShell)
- **NCGuard / GameGuard НЕ блокирует** эти оптимизации
- TCP/NIC настройки сохраняются в реестре (переживают перезагрузку)
- CPU-привязка действует до закрытия игры

### Требования

- Windows 10 / 11
- Права администратора
- PowerShell 5.1+ (встроен в Windows 10/11)
- Установленный AION2 и Purple launcher

---

## Description

Universal optimizer for AION2 that auto-detects your hardware and applies optimal settings for maximum in-game performance. Works on any Intel/AMD CPU and any network adapter.

### How to run

1. Download `AION2_Optimizer.bat` and `AION2_Optimizer.ps1` into the same folder
2. Double-click `AION2_Optimizer.bat`
3. Approve the Administrator (UAC) prompt
4. The script will find the game, Purple, and apply all optimizations
5. Click **Play** in Purple when it opens
6. Once `Aion2.exe` is detected, CPU optimizations are applied
7. The window closes automatically when the game exits

### What it optimizes

#### CPU — Core Affinity

| Setting | What it does |
|---|---|
| Core detection | Automatically identifies physical vs logical cores |
| SMT/HT filtering | Pins the game to **physical cores only**, skipping SMT virtual threads. Eliminates thread contention on shared core resources, reduces microstutter |
| X3D Multi-CCD | For 7950X3D / 9950X3D — pins to first 8 cores (V-Cache CCD) |
| Process priority | **HIGH** — Windows scheduler prioritizes the game over background tasks |

#### TCP Stack — Windows Registry

| Setting | Value | What it does |
|---|---|---|
| TcpNoDelay | 1 | Disables Nagle's algorithm. By default Windows batches small packets together (up to **200ms** delay). Now each packet is sent immediately |
| TcpAckFrequency | 1 | ACK sent for every packet immediately. Default behavior waits for a 2nd packet or 200ms timer. Server gets the green light faster |
| TcpDelAckTicks | 0 | Zero timer-based ACK delay |
| ECN | Disabled | Some routers/ISPs mishandle ECN bits, causing false congestion and packet drops |
| TcpTimedWaitDelay | 30 | Faster port recycling |

#### Network Adapter — Hardware Settings

| Setting | What it does |
|---|---|
| Interrupt Moderation OFF | NIC stops batching interrupts — each packet delivered to CPU immediately (**-1-2ms**) |
| Recv Segment Coalescing OFF | NIC stops merging TCP segments — packets delivered individually |
| Large Send Offload OFF | Outgoing packets sent immediately without NIC-level batching |
| Flow Control OFF | No pause frames when buffers fill |
| Power Saving OFF | Green Ethernet, Gigabit Lite, Power Saving, EEE — all disabled |
| Wake-on-LAN OFF | Removes overhead from WoL packet monitoring |

#### GPU & Power Plan

| Setting | What it does |
|---|---|
| DirectX GpuPreference | Sets "High Performance" for `Aion2.exe` |
| Power plan | Switches to highest available (Bitsum > Ultimate > High Performance) |

### Expected impact

- Per-packet latency reduction: **up to 200ms** (Nagle + Delayed ACK)
- Jitter reduction: **1-3ms** (Interrupt Moderation + RSC)
- Smoother frame times (no SMT thread contention)
- Noticeable in: PvP, sieges, mass battles, skill casting

### Safety

- Does **NOT** modify game files
- Does **NOT** inject code into the process
- Does **NOT** use drivers or hooks (unlike Process Lasso)
- All changes via standard Windows APIs (registry, PowerShell)
- **NCGuard / GameGuard does NOT block** these optimizations
- TCP/NIC tweaks persist in registry (survive reboots)
- CPU affinity lasts until the game is closed

### Requirements

- Windows 10 / 11
- Administrator privileges
- PowerShell 5.1+ (built into Windows 10/11)
- AION2 and Purple launcher installed

---

## Скачать / Download

Вам нужны оба файла в одной папке / You need both files in the same folder:

- `AION2_Optimizer.bat` — лаунчер, запускайте его / launcher, run this one
- `AION2_Optimizer.ps1` — основной скрипт / main script
