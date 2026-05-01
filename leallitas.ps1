# =====================================================================
# Projekt: Windows gépek távoli leállítása / újraindítása / kijelentkeztetése
# Verzió: 1.1.0
# Dátum: 2026-05-01
# Szerző: Kapos Gábor
#
# Leírás:
# - Indításkor választható:
#   1. Teszt mód vagy éles mód
#   2. Leállítás, újraindítás vagy kijelentkeztetés
#
# Futtatás:
# .\leallitas.ps1
#
# Megjegyzések:
# - Saját gépre engedélyezés: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# - Letöltött fájl feloldása: Unblock-File .\leallitas.ps1
# - Teljes mappa feloldása: Get-ChildItem -Path . -Recurse | Unblock-File
# =====================================================================

# =========================
# ALAP BEÁLLÍTÁSOK
# =========================

# A script saját mappája
# Ez azért fontos, mert ütemezett futtatásnál nem biztos, hogy a PowerShell ugyanabból a mappából indul.
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

# Felhasználónak megjelenő üzenetek
$shutdownMessage = "A gep 1 perc mulva leallitasra kerul. Kerlek mentsd el a munkadat..."
$restartMessage  = "A gep 1 perc mulva ujraindul. Kerlek mentsd el a munkadat..."

# =========================
# FUTTATÁSI MÓD VÁLASZTÁS
# =========================

# Külön változókat használunk, nem [switch] paramétereket.
# Így elkerüljük a SwitchParameter konvertálási hibát.
$IsTeszt = $false
$IsEles = $false

Write-Host ""
Write-Host "Válaszd ki a futtatási módot:" -ForegroundColor Cyan
Write-Host "1 - Teszt mód (nem hajt végre műveletet)"
Write-Host "2 - Éles mód (végrehajtja a választott műveletet)"

$modValasz = Read-Host "Add meg a számot (1-2)"

switch ($modValasz) {
    "1" {
        $IsTeszt = $true
        $IsEles = $false
        $mod = "TESZT"
    }
    "2" {
        $IsTeszt = $false
        $IsEles = $true
        $mod = "ELES"
    }
    default {
        Write-Host "Érvénytelen választás! Kilépés." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Kiválasztott mód: $mod" -ForegroundColor Green

# =========================
# MŰVELET VÁLASZTÁS
# =========================

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
if ($IsEles) {
    Write-Host ""
    Write-Host "FIGYELEM! ÉLES módot választottál." -ForegroundColor Yellow
    Write-Host "Művelet: $muveletNev" -ForegroundColor Yellow
    $confirm = Read-Host "Biztosan folytatod? Írd be: IGEN"

    if ($confirm -ne "IGEN") {
        Write-Host "Megszakítva." -ForegroundColor Red
        exit 0
    }
}

# =========================
# SEGÉDFÜGGVÉNY: TÁVOLI LOGOFF
# =========================

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

        # A query user kimenetben a session ID egy önálló szám.
        # Óvatos regex: a sorból az első önálló számot keresi, amely session ID-ként használható.
        $cleanLine = $line.Trim()

        if ($cleanLine -match '\s+(\d+)\s+') {
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

# =========================
# ELLENŐRZÉSEK
# =========================

# Ellenőrizzük, hogy létezik-e a gepek.txt
if (-not (Test-Path $gepekFile)) {
    Write-Host "HIBA: Nem található a gepek.txt fájl!" -ForegroundColor Red
    Write-Host "Elvárt hely: $gepekFile" -ForegroundColor Red
    exit 1
}

# Gépnevek beolvasása, szóközök levágása, üres sorok kiszűrése
$gepek = Get-Content $gepekFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }

# Kivétellista betöltése, ha létezik
$kivetelek = @()
if (Test-Path $kivetelFile) {
    $kivetelek = Get-Content $kivetelFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
}

# Kivételben szereplő gépek eltávolítása a feldolgozandó listából
$gepek = $gepek | Where-Object { $kivetelek -notcontains $_ }

# Ha nincs feldolgozható gép, kilépés
if ($gepek.Count -eq 0) {
    Write-Host "Nincs feldolgozható gép a listában." -ForegroundColor Yellow
    "Nincs feldolgozható gép. Időpont: $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
    exit 0
}

# =========================
# LOG KEZDÉS
# =========================

"===== Futtatás kezdete: $(Get-Date) =====" | Out-File $logFile -Append -Encoding UTF8
"Mód: $mod" | Out-File $logFile -Append -Encoding UTF8
"Művelet: $muveletNev" | Out-File $logFile -Append -Encoding UTF8
"Gépfájl: $gepekFile" | Out-File $logFile -Append -Encoding UTF8
"Kivételfájl: $kivetelFile" | Out-File $logFile -Append -Encoding UTF8
"Log mappa: $logDir" | Out-File $logFile -Append -Encoding UTF8
"" | Out-File $logFile -Append -Encoding UTF8

# CSV fejléc
"Idopont;Gep;Mod;Muvelet;Ping;Eredmeny;ExitCode;Megjegyzes" | Out-File $csvFile -Encoding UTF8

# =========================
# SZÁMLÁLÓK
# =========================

$ossz = 0
$elerheto = 0
$nemElerheto = 0
$sikeres = 0
$hibas = 0
$tesztOk = 0
$kihagyott = 0

# =========================
# FŐ CIKLUS
# =========================

foreach ($gep in $gepek) {

    $ossz++
    Write-Host "Ellenőrzés: $gep ..." -ForegroundColor Cyan

    # Ping ellenőrzés több próbálkozással
    $pingOk = $false

    for ($i = 1; $i -le $pingProbak; $i++) {
        if (Test-Connection -ComputerName $gep -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $pingOk = $true
            break
        }

        Start-Sleep -Seconds 1
    }

    # Ha a gép elérhető
    if ($pingOk) {

        $elerheto++

        # TESZT mód: csak jelzi, hogy mit csinálna
        if ($IsTeszt) {
            Write-Host "$gep ELÉRHETŐ → TESZT: $muveletNev lenne végrehajtva" -ForegroundColor Green

            "$gep TESZT OK - $muveletNev - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
            "$(Get-Date);$gep;TESZT;$muveletNev;OK;Nincs végrehajtás;;Teszt mód" | Out-File $csvFile -Append -Encoding UTF8

            $tesztOk++
        }

        # ÉLES mód: tényleges művelet
        if ($IsEles) {

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

                shutdown /m \\$gep $shutdownParam /f /t $shutdownDelay /c "$muveletMessage"

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

    }
    else {
        # Ha ping alapján nem elérhető
        Write-Host "$gep NEM ELÉRHETŐ ping alapján" -ForegroundColor Yellow

        "$gep NEM ELÉRHETŐ - $muveletNev - $(Get-Date)" | Out-File $logFile -Append -Encoding UTF8
        "$(Get-Date);$gep;$mod;$muveletNev;NEM;Nincs művelet;;Ping sikertelen" | Out-File $csvFile -Append -Encoding UTF8

        $nemElerheto++
        $kihagyott++
    }
}

# =========================
# ÖSSZESÍTÉS
# =========================

"" | Out-File $logFile -Append -Encoding UTF8
"===== ÖSSZESÍTÉS =====" | Out-File $logFile -Append -Encoding UTF8
"Mód: $mod" | Out-File $logFile -Append -Encoding UTF8
"Művelet: $muveletNev" | Out-File $logFile -Append -Encoding UTF8
"Összes feldolgozott gép: $ossz" | Out-File $logFile -Append -Encoding UTF8
"Elérhető: $elerheto" | Out-File $logFile -Append -Encoding UTF8
"Nem elérhető: $nemElerheto" | Out-File $logFile -Append -Encoding UTF8
"Kihagyott: $kihagyott" | Out-File $logFile -Append -Encoding UTF8
"Tesztben OK: $tesztOk" | Out-File $logFile -Append -Encoding UTF8
"Sikeres művelet: $sikeres" | Out-File $logFile -Append -Encoding UTF8
"Hibás művelet: $hibas" | Out-File $logFile -Append -Encoding UTF8
"===== Futtatás vége: $(Get-Date) =====" | Out-File $logFile -Append -Encoding UTF8

# Konzol összesítés
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

if ($IsEles) {
    Write-Host "Sikeres művelet: $sikeres" -ForegroundColor Green
    Write-Host "Hibás művelet: $hibas" -ForegroundColor Red
}

Write-Host "Log fájl: $logFile" -ForegroundColor Cyan
Write-Host "CSV fájl: $csvFile" -ForegroundColor Cyan