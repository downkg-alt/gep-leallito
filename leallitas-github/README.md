# ⚡ leallitas.ps1

![Verzió](https://img.shields.io/badge/verzió-1.1.2-blue?style=flat-square)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square&logo=windows&logoColor=white)
![Licenc](https://img.shields.io/badge/licenc-belső-gray?style=flat-square)

> Windows gépek tömeges **távoli leállítására**, **újraindítására** és **kijelentkeztetésére** készült PowerShell script. Interaktív módban fut, teszt és éles üzemmódot egyaránt támogat, és minden műveletről részletes log fájlt készít.

---

## 📋 Tartalomjegyzék

- [Előfeltételek](#-előfeltételek)
- [Fájlstruktúra](#-fájlstruktúra)
- [Futtatás](#-futtatás)
- [Interaktív menü](#-interaktív-menü)
- [Beállítható paraméterek](#-beállítható-paraméterek)
- [Működés](#-működés)
- [Log fájlok](#-log-fájlok)
- [Biztonsági megjegyzések](#-biztonsági-megjegyzések)
- [Verziónapló](#-verziónapló)

---

## ✅ Előfeltételek

| # | Követelmény |
|---|-------------|
| 1 | 🖥️ Windows rendszer **PowerShell 5.1** vagy újabb verzióval |
| 2 | 🔑 Admin jogosultság a célgépeken (domain vagy helyi admin) |
| 3 | 🌐 A célgépek elérhetők legyenek hálózaton (ping, RPC, tűzfal) |
| 4 | 🛠️ A `shutdown.exe` és `net.exe` eszközök elérhetők legyenek (alapértelmezetten igen) |

---

## 📁 Fájlstruktúra

A scriptnek ugyanabban a mappában kell lennie az alábbi fájlokkal:

```
📄 leallitas.ps1       ← maga a script
📄 gepek.txt           ← feldolgozandó gépek listája (soronként egy gépnév)
📄 kivetelek.txt       ← kihagyandó gépek listája (opcionális)
📂 logs\               ← automatikusan létrejön futtatáskor
```

<details>
<summary>📄 <strong>gepek.txt</strong> – példa</summary>

```
IRODA-PC-01
IRODA-PC-02
SZERVER-TEST
```

</details>

<details>
<summary>📄 <strong>kivetelek.txt</strong> – példa</summary>

```
SZERVER-TEST
SAJAT-GEPEM
```

</details>

---

## ▶️ Futtatás

### 🔓 Engedélyezés (első alkalommal)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Ha letöltött fájlról van szó, fel kell oldani:

```powershell
Unblock-File .\leallitas.ps1

# vagy a teljes mappa:
Get-ChildItem -Path . -Recurse | Unblock-File
```

### 🚀 Indítás

```powershell
.\leallitas.ps1
```

> 💡 A script saját könyvtárát automatikusan felismeri, így ütemezett feladatként is megbízhatóan futtatható.

---

## 🖱️ Interaktív menü

Indítás után a script két kérdést tesz fel:

### 1️⃣ Futtatási mód

| Választás | Mód | Leírás |
|-----------|-----|--------|
| `1` | 🟢 **Teszt mód** | Csak ellenőrzi az elérhetőséget, műveletet nem hajt végre |
| `2` | 🟠 **Éles mód** | Ténylegesen végrehajtja a választott műveletet |

### 2️⃣ Művelet

| Választás | Művelet | Leírás |
|-----------|---------|--------|
| `1` | 🔴 **Leállítás** | Késleltetett leállítást küld a célgépekre |
| `2` | 🔵 **Újraindítás** | Késleltetett újraindítást küld a célgépekre |
| `3` | 🟣 **Kijelentkeztetés** | Az összes aktív munkamenetet kijelentkezteti |

> ⚠️ **Éles módban** a script extra megerősítést kér (`IGEN` beírásával), majd admin hitelesítő adatokat kér be.

---

## ⚙️ Beállítható paraméterek

A script elején a következő változók módosíthatók:

| Változó | Alapérték | Leírás |
|---------|-----------|--------|
| `$pingProbak` | `3` | Ping próbálkozások száma gépenként |
| `$shutdownDelay` | `60` | Leállítás/újraindítás késleltetése másodpercben |
| `$forceApplications` | `$false` | `$true` esetén kényszeríti az alkalmazások bezárását (`/f` kapcsoló) |

> 💡 A felhasználónak megjelenő értesítő üzenet automatikusan a `$shutdownDelay` értékéből épül fel — ha módosítod a késleltetést, az üzenet magától frissül.

---

## 🔄 Működés

```
gepek.txt beolvasása
       │
       ▼
kivetelek.txt szűrése
       │
       ▼
┌─────────────────────┐
│  Gépenként (ciklus) │
└──────────┬──────────┘
           │
      Ping ellenőrzés
      /           \
   ❌ NEM          ✅ IGEN
  elérhető        elérhető
     │                │
  Naplóz          ┌───┴────────────┐
  Kihagyja        │                │
                🟢 TESZT        🟠 ÉLES
                  │                │
               Naplóz         IPC$ kapcsolat
               (nincs         végrehajtás
               művelet)       kapcsolat bontása
                  │                │
                  └───────┬────────┘
                          │
                    Összesítő + log
```

**Lépések részletesen:**

1. 📂 Beolvassa a `gepek.txt` tartalmát, eltávolítja a `kivetelek.txt`-ben szereplő gépeket
2. 📡 Minden gépen ping-ellenőrzést végez (`$pingProbak` próbálkozással), progress bar-ral
3. ❌ Nem elérhető gépeket naplózza és kihagyja
4. ✅ Elérhető gépeken:
   - 🟢 **Teszt módban:** csak naplózza, hogy a művelet végrehajtható lenne
   - 🟠 **Éles módban:** admin IPC$ kapcsolatot épít fel, végrehajtja a műveletet, majd bontja a kapcsolatot
5. 👤 Kijelentkeztetésnél a `query user` kimenetéből azonosítja az aktív munkameneteket, és session ID alapján jelentkezteti ki őket
6. 📊 Futás végén összesítőt ír a konzolra és a log fájlba

---

## 📊 Log fájlok

Minden futtatáshoz időbélyeges fájlok keletkeznek a `logs\` mappában:

| Fájl | Típus | Leírás |
|------|-------|--------|
| `leallitas_YYYY-MM-DD_HH-mm-ss.log` | 📄 Szöveg | Emberi olvasásra, eseményenként egy sor |
| `leallitas_YYYY-MM-DD_HH-mm-ss.csv` | 📊 CSV | Strukturált napló, Excel-kompatibilis (`;` elválasztóval) |

### CSV oszlopok

```
Idopont ; Gep ; Mod ; Muvelet ; Ping ; Eredmeny ; ExitCode ; Megjegyzes
```

---

## 🔒 Biztonsági megjegyzések

> ⚠️ **Jelszókezelés**
>
> A jelszó a `net use` hitelesítéshez szükség esetén átmenetileg plain text változóban tárolódik — ez a `net.exe` technikai korlátja. A script futás végén törli (`$null`), majd `[System.GC]::Collect()` hívással segíti a memóriából való eltávolítást.

> ✅ **1219-es hiba megelőzése**
>
> Az IPC$ kapcsolat létrehozása előtt a script törli az esetlegesen meglévő kapcsolatokat, megelőzve a Windows 1219-es hibáját (ütköző hitelesítési adatok).

> ✅ **Timeout védelem**
>
> A kapcsolat bontása külön folyamatban, 5 másodperces timeouttal történik, hogy egy leálló gép ne akassza meg a többi feldolgozását.

---

## 📝 Verziónapló

| Verzió | Dátum | Változások |
|--------|-------|------------|
| `1.1.2` | 2026-05-12 | Dinamikus shutdown üzenetek; `$IsEles` eltávolítva; `$ossz` egyszerűsítve; logoff regex javítva; `GC.Collect()` a jelszó törlése után |
| `1.1.1` | 2026-05-02 | Első kiadás |

---

<div align="center">
  <sub>Szerző: <strong>Kapos Gábor</strong> · 2026</sub>
</div>
