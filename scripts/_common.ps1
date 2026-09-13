$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

function Write-Status($msg, $type = "INFO") {
    if ($Silent) { return }
    [Console]::WriteLine("[$type] $msg")
}

function Write-Detail($item) {
    if ($Silent) { return }
    [Console]::WriteLine("[DEL] $item")
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$SUSPECT_KEYWORDS = @(
    "cheat", "hack", "aimbot", "wallhack", "esp",
    "trainer", "injector", "weapons.meta", "explosive",
    "pccheck", "cheatengine", "processhacker",
    "playertargetting", "triggerbot", "godmode",
    "speedhack", "teleport", "noclip", "fly*hack",
    "radar*hack", "dll*inject", "process*hack",
    "memory*edit", "game*hack", "mod*menu",
    "bhop", "spinbot", "ragebot", "legitbot",
    "backtrack", "resolver", "fakelag", "antiaim",
    "doubletap", "silent*aim", "auto*shoot",
    "rage*config", "legit*config",
    "workshop*hack", "steam*cheat", "overlay*hack",
    "overlay*cheat", "fivem*script", "redm*script",
    "samp*hack", "mtasa*mod", "wemod",
    "loader", "spoofer", "hwid*spoof", "unban",
    "exploit", "bypass", "dumper", "keygen",
    "cracked", "patcher", "external", "internal"
)

# Whitelist - Anti-Cheat & legitime Sicherheits-Software
# Wenn ein Name eines dieser Keywords enthaelt, wird er NIE als verdaechtig markiert
# Wichtig: EasyAntiCheat enthaelt "cheat" - ohne Whitelist wuerde es sonst geloescht!
$WHITELIST_KEYWORDS = @(
    "easyanticheat", "eac_", "eac-",
    "battleye", "beservice", "bedaisy", "beclient",
    "vanguard", "vgc.exe", "vgk.sys",
    "faceit", "esea",
    "punkbuster", "pnkbstr",
    "hackshield", "ahnlab",
    "xigncode",
    "ricochet",
    "gameguard", "npgg",
    "denuvo",
    "anti-cheat", "anticheat", "anti_cheat",
    "windows defender", "defender platform",
    "malwarebytes", "kaspersky", "bitdefender",
    "riot client", "riotgames",
    # Windows System Services - NIEMALS stoppen/loeschen
    "appinfo", "dcomlaunch", "eventlog", "rpcss", "cryptsvc",
    "dnscache", "lsass", "winlogon", "csrss", "wininit",
    "smss", "services.exe", "svchost", "dwm.exe", "explorer.exe",
    "taskhost", "sihost", "runtimebroker",
    "wuauserv", "bits", "trustedinstaller", "msiexec",
    "windows update", "windows installer",
    "shell experience", "startmenuexperience",
    "system idle", "system interrupts"
)

function Test-IsWhitelisted([string]$name) {
    if (-not $name) { return $false }
    $lower = $name.ToLower()
    foreach ($kw in $WHITELIST_KEYWORDS) {
        if ($lower -like "*$kw*") { return $true }
    }
    return $false
}

# Bekannte legitime App-Ordner - Files hier drin werden nie als verdaechtig markiert
$WHITELIST_PATHS = @(
    # Windows-Systempfade - alles hier drin ist per Definition legitim
    "\windows\system32\", "\windows\syswow64\", "\windows\winsxs\",
    "\windows\servicing\", "\windows\microsoft.net\",
    "\windows\assembly\", "\windows\globalization\",
    "\windows\immersivecontrolpanel\", "\windows\shellexperiences\",
    "\windows\systemapps\", "\windows\systemresources\",
    "\windows\inf\", "\windows\fonts\",
    # Programm-Ordner allgemein (bekannte Software liegt hier)
    "\program files\", "\program files (x86)\", "\programdata\",
    # Bekannte Hersteller
    "\microsoft\", "\microsoftedge\", "\edge\", "\edgewebview\", "\ebwebview\",
    "\google\", "\chrome\", "\chromium\",
    "\mozilla\", "\firefox\",
    "\adobe\", "\creative cloud\",
    "\nvidia corporation\", "\nvidia\", "\nvidia gfe\",
    "\amd\", "\intel\", "\realtek\", "\logitech\", "\razer\", "\corsair\",
    "\steam\", "\steamapps\", "\valve\",
    "\discord\",
    "\epic games\", "\epicgameslauncher\",
    "\rockstar games\", "\rockstar games launcher\", "\launcherpatcher",
    "\ubisoft\", "\ea games\", "\electronic arts\",
    "\battle.net\", "\blizzard\",
    "\gamingservices\", "\gamemanagerservice\", "\gameinputredist\",
    "\obs studio\", "\obs-studio\",
    "\zoom\", "\slack\", "\microsoft teams\",
    "\spotify\",
    "\packages\microsoft.", "\windowsapps\",
    "\onedrive\", "\dropbox\",
    "\java\", "\jdk\", "\jre\",
    "\python\", "\nodejs\", "\dotnet\",
    "\visualstudio\", "\visual studio\", "\vscode\", "\code\",
    "\git\", "\github\",
    "\notion\", "\telegram\", "\whatsapp\"
)

function Test-IsPathWhitelisted([string]$path) {
    if (-not $path) { return $false }
    $lower = $path.ToLower()
    foreach ($p in $WHITELIST_PATHS) {
        if ($lower -like "*$p*") { return $true }
    }
    return $false
}

# Fuer Files mit vollem Pfad - checkt Name-Whitelist UND Path-Whitelist
function Test-IsSuspiciousFile([string]$name, [string]$fullPath) {
    if (Test-IsPathWhitelisted $fullPath) { return $false }
    return Test-IsSuspicious $name
}

# Loose match - fuer Dateinamen, Prozessnamen, Registry-Wertnamen
# Substring-Match: "esp.dll" matched, aber "response.dll" auch (Kompromiss)
function Test-IsSuspicious([string]$name) {
    if (-not $name) { return $false }
    if (Test-IsWhitelisted $name) { return $false }
    $lower = $name.ToLower()
    foreach ($kw in $SUSPECT_KEYWORDS) {
        if ($lower -like "*$kw*") { return $true }
    }
    return $false
}

# Strict match - fuer Text-Inhalte (History-Zeilen, Registry-Werte, Kommentare)
# Wort-Grenzen via regex \b: "esp" matched als eigenes Wort, aber NICHT in "gesperrt"
$SUSPECT_TEXT_PATTERNS = $SUSPECT_KEYWORDS | ForEach-Object {
    $p = $_ -replace '\.', '\.' -replace '\*', '\S*'
    '\b' + $p + '\b'
}

function Test-IsSuspiciousText([string]$text) {
    if (-not $text) { return $false }
    if (Test-IsWhitelisted $text) { return $false }
    $lower = $text.ToLower()
    foreach ($pat in $SUSPECT_TEXT_PATTERNS) {
        if ($lower -match $pat) { return $true }
    }
    return $false
}
