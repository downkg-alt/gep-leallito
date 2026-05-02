# 🖥️ Távoli Windows Leállító Script

Ez a PowerShell script lehetővé teszi egy távoli Windows gép biztonságos leállítását adminisztrátori jogosultsággal.

---

## 🚀 Funkciók

- 🔐 Admin (IPC$) kapcsolat létrehozása
- 📡 Távoli leállítás indítása
- 🔌 Biztonságos kapcsolat bontás
- ⏱️ Timeout kezelés (nem fagy be)
- 📋 Részletes naplózás

---

## ⚙️ Követelmények

- Windows PowerShell 5.1+
- Adminisztrátori jogosultság
- Engedélyezett hálózati elérés a céleszközön
- SMB / admin megosztás (IPC$) elérhető

---

## 📦 Használat

```powershell
.\leallitas.ps1
```

A script futása során:

1. Kapcsolódik a távoli géphez
2. Ellenőrzi az elérhetőséget
3. Elindítja a leállítást
4. Bontja a kapcsolatot (timeout védelemmel)

---

## 🧠 Működés röviden

Kapcsolat létrehozása → Leállítás küldése → Kapcsolat bontása

---

## 🔧 Testreszabás

A scriptben módosítható:

- Célszámítógép neve/IP címe
- Timeout idő (alap: ~5 mp)
- Naplózási szint

---

## 🛡️ Biztonsági megjegyzés

A script admin hozzáférést használ, ezért:

- Csak megbízható környezetben futtasd
- Ne tárold plain text jelszót
- Használj biztonságos hitelesítést

---

## 📄 Licenc

Szabadon használható oktatási és belső célokra.

---

## 👨‍💻 Szerző

Készítve PowerShell automatizálási célokra.