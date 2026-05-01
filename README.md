# 🖥️ Remote Computer Control Script (PowerShell)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-blue)
![Mode](https://img.shields.io/badge/Modes-Interactive-green)
![Logging](https://img.shields.io/badge/Logging-Enabled-success)
![Status](https://img.shields.io/badge/Status-Stable-brightgreen)

---

## 📌 Leírás

Ez a PowerShell script lehetővé teszi több hálózati gép **távoli vezérlését**:

- 🚀 Teszt mód (ellenőrzés, végrehajtás nélkül)
- ⚡ Éles mód (művelet végrehajtása)
- 🔌 Leállítás
- 🔄 Újraindítás
- 👤 Kijelentkeztetés

---

## 🎯 Fő jellemzők

- 📋 géplista fájlból (`gepek.txt`)
- 🚫 kivétellista támogatás (`kivetelek.txt`)
- 🌐 ping ellenőrzés (több próbálkozással)
- 📊 CSV log (Excel kompatibilis)
- 📝 részletes log fájl
- 📁 automatikus `logs/` mappa létrehozás
- 🎛️ interaktív menü (nincs paraméterezés)

---

## 📁 Projekt struktúra

```text
📦 gep-leallito
 ┣ 📜 leallitas.ps1
 ┣ 📄 gepek.txt
 ┣ 🚫 kivetelek.txt
 ┣ 📊 logs/
 ┃ ┣ 📄 leallitas_*.log
 ┃ ┗ 📄 leallitas_*.csv
 ┗ 📘 README.md
```

---

## 🚀 Indítás

```powershell
.\leallitas.ps1
```

---

## 🎛️ Menü működés

Indítás után:

### 1️⃣ Futtatási mód

```
1 - Teszt mód
2 - Éles mód
```

---

### 2️⃣ Művelet

```
1 - Leállítás
2 - Újraindítás
3 - Kijelentkeztetés
```

---

## 🧪 Teszt mód

✔️ csak ellenőriz  
✔️ nem hajt végre műveletet  
✔️ logol  

---

## ⚡ Éles mód

✔️ végrehajtja a kiválasztott műveletet  
✔️ figyelmeztetést kér  
✔️ logol  

---

## 🔧 Használt parancsok

### Leállítás / Restart

```cmd
shutdown /m \\GEP /s /f /t 60
shutdown /m \\GEP /r /f /t 60
```

---

### Kijelentkeztetés

```cmd
query user /server:GEP
logoff SESSIONID /server:GEP
```

---

## 📂 Bemeneti fájlok

### 🖥️ gepek.txt

```text
PC01
PC02
PC03
```

---

### 🚫 kivetelek.txt

```text
SERVER01
NAS01
```

---

## 📊 Logok

📁 `logs/` mappa:

- 📄 `.log` → részletes napló  
- 📄 `.csv` → Excel kompatibilis  

---

## 📈 Példa eredmény

```text
Összes: 15
Elérhető: 12
Nem elérhető: 3
Sikeres: 11
Hibás: 1
```

---

## ⚠️ Követelmények

- 👑 admin jogosultság a célgépeken
- 🌐 hálózati elérés
- 🔥 tűzfal ne blokkolja
- 🖥️ Windows környezet
- használd kivétellistát szerverekhez