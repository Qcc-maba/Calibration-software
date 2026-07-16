# Agilent 34401A — פרוטוקול תקשורת (מאומת מול מכשיר חי)

מאומת ב-2026-07-16 מול יחידה פיזית (firmware `10-5-2`) דרך מתאם USB-to-Serial (Prolific PL2303).

## הגדרות פורט (RS-232)
| פרמטר | ערך |
|-------|-----|
| Baud | **9600** |
| Data / Parity / Stop | 8 / None / 1 |
| Flow control | **DTR/DSR** — חובה `DtrEnable=true`, `RtsEnable=true`. **לא** XON/XOFF. |
| Command terminator | `\r\n` |
| Response terminator | `\r\n` |
| זיהוי (`*IDN?`) | `HEWLETT-PACKARD,34401A,0,10-5-2` → טוקן זיהוי `HEWLETT` |

## רצף פקודות מאומת
```
*RST                      # reset
*CLS                      # clear status
SYST:REM                  # חובה! בלי זה כל קריאה מחזירה שגיאה 550 "Command not allowed in local"
CONF:VOLT:DC              # או CONF:RES (2W) / CONF:FRES (4W)
VOLT:DC:RANG:AUTO ON      # autorange (בלי רווחים! "VOLT: DC:..." לא חוקי)
READ?                     # מחזיר את הערך הנמדד
```

## תגובות READ? מאומתות
| מצב | פקודות | תגובה |
|-----|--------|-------|
| מתח DC (מובילים פתוחים) | `CONF:VOLT:DC` + `READ?` | `-1.72140000E-05` |
| התנגדות 2W (מעגל פתוח) | `CONF:RES` + `READ?` | `+9.90000000E+37` ← **OL/overload** |
| התנגדות 4W | `CONF:FRES` + `READ?` | `+4.35600000E-03` |
| תור שגיאות | `SYST:ERR?` | `+0,"No error"` |

## הערות מימוש ל-BL
- הערך חוזר ב-**scientific notation** (`±d.ddddddddE±dd`). לפרסר: `double.Parse(..., InvariantCulture)`.
- **`9.9E37` = overload / open** (מעל טווח) — לטפל כ-OL, לא כערך אמיתי.
- **טמפרטורה**: ה-34401A אינו מודד טמפ' ישירות — מודדים `FRES`/`RES` של RTD וממירים Ohm→°C (ראה `HydraCalculations.CalcConversionUnits`).
- פקודת הקריאה הנכונה היא `READ?` (לא `DATA:POIN?` — זו מחזירה מספר נקודות בזיכרון, לא ערך).
- לחזרה מהירה אפשר `INIT` ואז `FETC?`, או `READ?` בכל מחזור.
