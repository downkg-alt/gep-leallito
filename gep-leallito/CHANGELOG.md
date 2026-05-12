# 📝 Verziónapló

A projekt összes jelentős változása itt kerül dokumentálásra.
A formátum a [Keep a Changelog](https://keepachangelog.com/hu/1.0.0/) ajánlást követi.

---

## [1.1.2] – 2026-05-12

### 🔧 Javítva
- Logoff session-azonosító regex robusztusabbá téve — hosszú felhasználóneveknél is helyesen működik
- `$ossz` számláló egyszerűsítve — mostantól `$elerheto + $nemElerheto` alapján számítódik, nem külön növeljük

### ♻️ Refaktorálva
- `$IsEles` változó eltávolítva — mindig `$IsTeszt` ellentéte volt, mostantól `-not $IsTeszt` helyettesíti
- Shutdown üzenetek dinamikussá téve — automatikusan a `$shutdownDelay` értékéből épülnek fel

### 🔒 Biztonság
- `[System.GC]::Collect()` hozzáadva a script végére, hogy a plain text jelszó mielőbb kikerüljön a memóriából

---

## [1.1.1] – 2026-05-02

### 🚀 Első kiadás
- Interaktív teszt / éles mód választás
- Leállítás, újraindítás, kijelentkeztetés támogatása
- Admin IPC$ kapcsolat kezelése 1219-es hiba megelőzésével
- Timeout-biztos kapcsolat bontás (5 másodperces limit)
- Progress bar a feldolgozás állapotának megjelenítéséhez
- Szöveges `.log` és Excel-kompatibilis `.csv` naplózás
- Kivétel lista (`kivetelek.txt`) támogatása
