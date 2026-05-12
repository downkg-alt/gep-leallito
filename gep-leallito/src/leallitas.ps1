# =================================================================================
# Projekt: Windows gépek távoli leállítása / újraindítása / kijelentkeztetése
# Verzió: 1.1.2
# Dátum: 2026-05-12
# Szerző: Kapos Gábor
#
# Leírás:
# - Indításkor választható:
#   1. Teszt mód vagy éles mód
#   2. Leállítás, újraindítás vagy kijelentkeztetés
# - Progress bar mutatja a feldolgozás állapotát
#
# Futtatás:
# .\leallitas.ps1
#
# Megjegyzések:
# - Saját gépre engedélyezés: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# - Letöltött fájl feloldása: Unblock-File .\leallitas.ps1
# - Teljes mappa feloldása: Get-ChildItem -Path . -Recurse | Unblock-File
# =================================================================================

# =================================================================================
# ALAP BEÁLLÍTÁSOK
# =================================================================================

# A script saját mappája
# Ez azért fontos, mert ütemezett futtatásnál nem biztos, hogy a PowerShell ugyanabból a mappából indul
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Bemeneti fájlok
# Gépnevek fájl
$gepekFile = Join-Path $scriptDir "gepek.txt"

# Kivétel lista (nem kezelendő gépek)
$kivetelFile = Join-Path $scriptDir "kivetelek.txt"

# Log mappa
$logDir = Join-Path $scriptDir "logs"

# Ha a logs mappa nem létezik, létrehozzuk
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Időbélyeg a log fájlok nevéhez
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Log fájlok a logs mappában
# Log fájl (szöveges)
$logFile = Join-Path $logDir "leallitas_$timestamp.log"

# CSV log (Excelhez)
$csvFile = Join-Path $logDir "leallitas_$timestamp.csv"

# Ping próbálkozások száma gépenként
$pingProbak = 3

# Leállítás / újraindítás késleltetése másodpercben
$shutdownDelay = 60

# Alkalmazások kényszerített bezárása leállításkor/újraindításkor
# $false = kíméletesebb, kisebb adatvesztési kockázat
# $true  = erőltetett bezárás (/f), ha biztosan ezt akarod
$forceApplications = $false

# Felhasználónak megjelenő üzenetek
# Dinamikusan épülnek fel a $shutdownDelay értékéből, így nem kell kézzel frissíteni őket.
$shutdownMessage = "A gep $shutdownDelay masodperc mulva leallitasra kerul. Kerlek mentsd el a munkadat..."
$restartMessage  = "A gep $shutdownDelay masodperc mulva ujraindul. Kerlek mentsd el a munkadat..."

# =================================================================================
# FUTTATÁSI MÓD VÁLASZTÁS
# =================================================================================

# Külön változókat használunk, nem [switch] paramétereket.
# Így elkerüljük a SwitchParameter konvertálási hibát.
# $IsEles mindig $IsTeszt ellentéte, ezért külön nem tároljuk.
$IsTeszt = $false

Write-Host ""
Write-Host "Válaszd ki a futtatási módot:" -ForegroundColor Cyan
Write-Host "1 - Teszt mód (nem hajt végre műveletet)"
Write-Host "2 - Éles mód (végrehajtja a választott műveletet)"

$modValasz = Read-Host "Add meg a számot (1-2)"

switch ($modValasz) {
    "1" {
        $IsTeszt = $true
        $mod = "TESZT"
    }
    "2" {
        $IsTeszt = $false
        $mod = "ELES"
    }
    default {
        Write-Host "Érvénytelen választás! Kilépés." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Kiválasztott mód: $mod" -ForegroundColor Green

# =================================================================================
# MŰVELET VÁLASZTÁS
# =================================================================================

Write-Host ""
Write-Host "Válaszd ki a műveletet:" -ForegroundColor Cyan
Write-Host "1 - Leállítás"
Write-Host "2 - Újraindítás"
Write-Host "3 - Kijelentkeztetés"

$muveletValasz = Read-Host "Add meg a számot (1-3)"

switch ($muveletValasz) {
    "1" {
        $muvelet = "LEALLITAS"
        $muveletNev = "LEÁLLÍTÁS"
        $shutdownParam = "/s"
        $muveletMessage = $shutdownMessage
    }
    "2" {
        $muvelet = "RESTART"
        $muveletNev = "ÚJRAINDÍTÁS"
        $shutdownParam = "/r"
        $muveletMessage = $restartMessage
    }
    "3" {
        $muvelet = "LOGOFF"
        $muveletNev = "KIJELENTKEZTETÉS"
        $shutdownParam = $null
        $muveletMessage = "Távoli kijelentkeztetés"
    }
    default {
        Write-Host "Érvénytelen választás! Kilépés." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Kiválasztott művelet: $muveletNev" -ForegroundColor Green

# Éles mód esetén extra megerősítés
if (-not $IsTeszt) {
    Write-Host ""
    Write-Host "FIGYELEM! ÉLES módot választottál." -ForegroundColor Yellow
    Write-Host "Művelet: $muveletNev" -ForegroundColor Yellow
    $confirm = Read-Host "Biztosan folytatod? Írd be: IGEN"

    if ($confirm -ne "IGEN") {
        Write-Host "Megszakítva." -ForegroundColor Red
        exit 0
    }
}

# =================================================================================
# ADMIN ADATOK BEKÉRÉSE ÉLES MÓDBAN
# =================================================================================

$cred = $null
$plainPassword = $null
$bstrPassword = [IntPtr]::Zero

if (-not $IsTeszt) {
    Write-Host ""
    Write-Host "Add meg az összes célgépen érvényes admin felhasználót." -ForegroundColor Cyan
    Write-Host "Példa: DOMAIN\AdminUser vagy CELGEP\AdminUser" -ForegroundColor DarkCyan

    $cred = Get-Credential -Message "Célgépeken érvényes admin felhasználó"

    try {
        $bstrPassword = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstrPassword)
    }
    finally {
        if ($bstrPassword -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPassword)
        }
    }
}

# =================================================================================
# SEGÉDFÜGGVÉNY: IDEIGLENES ADMIN IPC$ KAPCSOLAT
# =================================================================================

function Connect-AdminIPC {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $ipcPath = "\\$ComputerName\IPC$"

    # 1219-es hiba megelőzése:
    # Ha ugyanahhoz a géphez már van kapcsolat más felhasználóval,
    # a Windows nem enged új hitelesítést. Ezért előbb bontjuk a tipikus admin kapcsolatokat.
    $knownShares = @("IPC$", "ADMIN$", "C$")
    foreach ($share in $knownShares) {
        & net.exe use "\\$ComputerName\$share" /delete /y 2>$null | Out-Null
    }

    & net.exe use $ipcPath "/user:$UserName" $Password "/persistent:no" 2>$null | Out-Null

    return $LASTEXITCODE
}

function Disconnect-AdminIPC {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $ipcPath = "\\$ComputerName\IPC$"

    # A net use /delete néha beragad, főleg akkor, ha közben a távoli gép már leállás alatt van.
    # Ezért külön folyamatban futtatjuk, és rövid timeout után továbblépünk.
    $deleteArgs = @("use", $ipcPath, "/delete", "/y")
    $proc = Start-Process -FilePath "net.exe" -ArgumentList $deleteArgs -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\netuse_delete_out.txt" -RedirectStandardError "$env:TEMP\netuse_delete_err.txt"

    if (-not $proc.WaitForExit(5000)) {
        try {
            $proc.Kill()
        }
        catch {
            # Nem kritikus: a kapcsolat bontása csak takarítás.
        }

        return 1460  # Timeout
    }

    return $proc.ExitCode
}

# =================================================================================
# SEGÉDFÜGGVÉNY: TÁVOLI LOGOFF
# =================================================================================

function Invoke-RemoteLogoff {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # A shutdown.exe /l kapcsoló távoli géppel nem használható megbízhatóan.
    # Ezért a távoli bejelentkezett munkameneteket lekérdezzük, majd a session ID-kat kijelentkeztetjük.
    # Szükséges: admin jog a célgépen, RPC elérés, megfelelő tűzfalbeállítás.

    $sessionLines = @(query user /server:$ComputerName 2>$null)

    if ($LASTEXITCODE -ne 0 -or $sessionLines.Count -le 1) {
        return @{
            Success = $false
            ExitCode = $LASTEXITCODE
            Message = "Nem sikerült lekérdezni a munkameneteket, vagy nincs aktív felhasználó."
        }
    }

    $loggedOffCount = 0
    $errors = @()

    foreach ($line in $sessionLines | Select-Object -Skip 1) {
        $cleanLine = $line.Trim()

        # Robusztusabb regex: a session ID a 3. oszlopban szerepel a 'query user' kimenetében.
        # A minta figyelembe veszi az esetleges elcsúszott oszlopokat is.
        if ($cleanLine -match '^\S+\s+\S*\s+(\d+)\s+') {
            $sessionId = $matches[1]

            logoff $sessionId /server:$ComputerName 2>$null

            if ($LASTEXITCODE -eq 0) {
                $loggedOffCount++
            }
            else {
                $errors += "SessionID $sessionId hiba: $LASTEXITCODE"
            }
        }
    }

    if ($loggedOffCount -gt 0 -and $errors.Count -eq 0) {
        return @{
            Success = $true
            ExitCode = 0
            Message = "$loggedOffCount munkamenet kijelentkeztetve."
        }
    }
    elseif ($loggedOffCount -gt 0 -and $errors.Count -gt 0) {
        return @{
            Success = $true
            ExitCode = 0
            Message = "$loggedOffCount munkamenet kijelentkeztetve, de volt hiba: $($errors -join ', ')"
        }
    }
    else {
        return @{
            Success = $false
            ExitCode = 1
            Message = "Nem sikerült kijelentkeztetni munkamenetet. $($errors -join ', ')"
        }
    }
}

# =================================================================================
# ELLENŐRZÉSEK
# =================================================================================

if (-not (Test-Path $gepekFile)) {
    Write-Host "HIBA: Nem található a gepek.txt fájl!" -ForegroundColor Red
    Write-Host "Elvárt hely: $gepekFile" -ForegroundColor Red
    exit 1
}

$gepek = Get-Content $gepekFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }

$kivetelek = @()
if (Test-Path $kivetelFile) {
    $kivetelek = Get-Content $kivetelFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
}

$gepek = $gepek | Where-Object { $kivetelek -notcontains $_ }

if ($gepek.Count -eq 0) {
    Write-Host "Nincs feldolgozható gép a listában." -ForegroundColor Yellow
    "Nincs feldolgozható gép. Időpont: $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
    exit 0
}

# =================================================================================
# LOG KEZDÉS
# =================================================================================

"===== Futtatás kezdete: $(Get-Date) =====" | Out-File $logFile -Append -Encoding UTF8
"Mód: $mod" | Out-File $logFile -Append -Encoding UTF8
"Művelet: $muveletNev" | Out-File $logFile -Append -Encoding UTF8
"Gépfájl: $gepekFile" | Out-File $logFile -Append -Encoding UTF8
"Kivételfájl: $kivetelFile" | Out-File $logFile -Append -Encoding UTF8
"Log mappa: $logDir" | Out-File $logFile -Append -Encoding UTF8
"" | Out-File $logFile -Append -Encoding UTF8

"Idopont;Gep;Mod;Muvelet;Ping;Eredmeny;ExitCode;Megjegyzes" | Out-File $csvFile -Encoding UTF8

# =================================================================================
# SZÁMLÁLÓK
# =================================================================================

$elerheto = 0
$nemElerheto = 0
$sikeres = 0
$hibas = 0
$tesztOk = 0
$kihagyott = 0

# =================================================================================
# PROGRESS BAR ELŐKÉSZÍTÉS
# =================================================================================

$totalGepek = $gepek.Count
$index = 0

# =================================================================================
# FŐ CIKLUS
# =================================================================================

foreach ($gep in $gepek) {

    $index++
    $percent = [int](($index / $totalGepek) * 100)

    Write-Progress `
        -Activity "Gépek feldolgozása" `
        -Status "$gep ($index / $totalGepek) - $muveletNev" `
        -PercentComplete $percent

    Write-Host "Ellenőrzés: $gep ..." -ForegroundColor Cyan

    $pingOk = $false

    for ($i = 1; $i -le $pingProbak; $i++) {
        if (Test-Connection -ComputerName $gep -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $pingOk = $true
            break
        }

        Start-Sleep -Seconds 1
    }

    if ($pingOk) {

        $elerheto++

        if ($IsTeszt) {
            Write-Host "$gep ELÉRHETŐ → TESZT: $muveletNev lenne végrehajtva" -ForegroundColor Green

            "$gep TESZT OK - $muveletNev - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
            "$(Get-Date);$gep;TESZT;$muveletNev;OK;Nincs végrehajtás;;Teszt mód" | Out-File $csvFile -Append -Encoding UTF8

            $tesztOk++
        }

        if (-not $IsTeszt) {

            $ipcConnected = $false

            try {
                Write-Host "$gep admin kapcsolat létrehozása..." -ForegroundColor Cyan

                $ipcExitCode = Connect-AdminIPC -ComputerName $gep -UserName $cred.UserName -Password $plainPassword

                if ($ipcExitCode -ne 0) {
                    Write-Host "$gep HIBA: admin IPC kapcsolat nem sikerült. ExitCode: $ipcExitCode" -ForegroundColor Red

                    "$gep HIBA - admin IPC kapcsolat - ExitCode: $ipcExitCode - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
                    "$(Get-Date);$gep;ELES;$muveletNev;OK;Hiba;$ipcExitCode;Admin IPC kapcsolat nem sikerült" | Out-File $csvFile -Append -Encoding UTF8

                    $hibas++
                    continue
                }

                $ipcConnected = $true

                Write-Host "$gep ELÉRHETŐ → $muveletNev indítása..." -ForegroundColor Yellow

                if ($muvelet -eq "LOGOFF") {

                    $result = Invoke-RemoteLogoff -ComputerName $gep

                    if ($result.Success) {
                        Write-Host "$gep kijelentkeztetés sikeres: $($result.Message)" -ForegroundColor Green

                        "$gep OK - $muveletNev - $($result.Message) - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
                        "$(Get-Date);$gep;ELES;$muveletNev;OK;Sikeres;$($result.ExitCode);$($result.Message)" | Out-File $csvFile -Append -Encoding UTF8

                        $sikeres++
                    }
                    else {
                        Write-Host "$gep HIBA kijelentkeztetésnél: $($result.Message)" -ForegroundColor Red

                        "$gep HIBA - $muveletNev - $($result.Message) - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
                        "$(Get-Date);$gep;ELES;$muveletNev;OK;Hiba;$($result.ExitCode);$($result.Message)" | Out-File $csvFile -Append -Encoding UTF8

                        $hibas++
                    }

                }
                else {

                    $shutdownArgs = @("/m", "\\$gep", $shutdownParam, "/t", $shutdownDelay, "/c", $muveletMessage)

                    if ($forceApplications) {
                        $shutdownArgs += "/f"
                    }

                    & shutdown.exe @shutdownArgs

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "$gep sikeresen elküldve: $muveletNev" -ForegroundColor Green

                        "$gep OK - $muveletNev - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
                        "$(Get-Date);$gep;ELES;$muveletNev;OK;Sikeres;$LASTEXITCODE;Késleltetés: $shutdownDelay mp" | Out-File $csvFile -Append -Encoding UTF8

                        $sikeres++
                    }
                    else {
                        Write-Host "$gep HIBA a műveletnél. ExitCode: $LASTEXITCODE" -ForegroundColor Red

                        "$gep HIBA - $muveletNev - ExitCode: $LASTEXITCODE - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
                        "$(Get-Date);$gep;ELES;$muveletNev;OK;Hiba;$LASTEXITCODE;A művelet nem sikerült" | Out-File $csvFile -Append -Encoding UTF8

                        $hibas++
                    }
                }
            }
            finally {
                if ($ipcConnected) {
                    Write-Host "$gep admin kapcsolat bontása..." -ForegroundColor DarkGray

                    $disconnectCode = Disconnect-AdminIPC -ComputerName $gep

                    if ($disconnectCode -eq 1460) {
                        Write-Host "$gep admin kapcsolat bontása timeout miatt átugorva, a script folytatódik." -ForegroundColor Yellow
                    }
                }
            }
        }

    }
    else {
        Write-Host "$gep NEM ELÉRHETŐ ping alapján" -ForegroundColor Yellow

        "$gep NEM ELÉRHETŐ - $muveletNev - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
        "$(Get-Date);$gep;$mod;$muveletNev;NEM;Nincs művelet;;Ping sikertelen" | Out-File $csvFile -Append -Encoding UTF8

        $nemElerheto++
        $kihagyott++
    }

    Write-Host "$gep feldolgozva ($index/$totalGepek)" -ForegroundColor DarkGray
}

Write-Progress -Activity "Gépek feldolgozása" -Completed

# =================================================================================
# ÖSSZESÍTÉS
# =================================================================================

"" | Out-File $logFile -Append -Encoding UTF8
"===== ÖSSZESÍTÉS =====" | Out-File $logFile -Append -Encoding UTF8
"Mód: $mod" | Out-File $logFile -Append -Encoding UTF8
"Művelet: $muveletNev" | Out-File $logFile -Append -Encoding UTF8
$ossz = $elerheto + $nemElerheto
"Összes feldolgozott gép: $ossz" | Out-File $logFile -Append -Encoding UTF8
"Elérhető: $elerheto" | Out-File $logFile -Append -Encoding UTF8
"Nem elérhető: $nemElerheto" | Out-File $logFile -Append -Encoding UTF8
"Kihagyott: $kihagyott" | Out-File $logFile -Append -Encoding UTF8
"Tesztben OK: $tesztOk" | Out-File $logFile -Append -Encoding UTF8
"Sikeres művelet: $sikeres" | Out-File $logFile -Append -Encoding UTF8
"Hibás művelet: $hibas" | Out-File $logFile -Append -Encoding UTF8
"===== Futtatás vége: $(Get-Date) =====" | Out-File $logFile -Append -Encoding UTF8

Write-Host ""
Write-Host "===== ÖSSZESÍTÉS =====" -ForegroundColor Cyan
Write-Host "Mód: $mod"
Write-Host "Művelet: $muveletNev"
Write-Host "Összes gép: $ossz"
Write-Host "Elérhető: $elerheto" -ForegroundColor Green
Write-Host "Nem elérhető: $nemElerheto" -ForegroundColor Yellow
Write-Host "Kihagyott: $kihagyott" -ForegroundColor Yellow

if ($IsTeszt) {
    Write-Host "Tesztben végrehajtható lenne: $tesztOk" -ForegroundColor Green
}

if (-not $IsTeszt) {
    Write-Host "Sikeres művelet: $sikeres" -ForegroundColor Green
    Write-Host "Hibás művelet: $hibas" -ForegroundColor Red
}

Write-Host "Log fájl: $logFile" -ForegroundColor Cyan
Write-Host "CSV fájl: $csvFile" -ForegroundColor Cyan

$plainPassword = $null
$cred = $null
[System.GC]::Collect()