# Duplicate e-mail addresses on CalibratorProd

Measured 07/09/2026. **38 addresses, 79 accounts, every one of them active.**

`GetLoginUser` resolves by e-mail, so which account someone gets is arbitrary. That matters more now that order approval and OTP login both key off the address.

Each row is one account. Judge each block: the same person entered twice, or two people sharing a mailbox. For a real duplicate, deactivate the redundant id rather than deleting it - calibration history references these ids:

```sql
UPDATE dbo.Users SET IsActive = 0, UpdatedDate = SYSUTCDATETIME() WHERE ID = <redundant id>;
```

| e-mail | id | name | role | created | active |
|---|---|---|---|---|---|
| sales@gelectronic.co.il | 4131 | ישראל ינאי | 14 | 2026-05-19 | yes |
|  | 4132 | ישראל ינאי | 14 | 2026-05-19 | yes |
|  | 4133 | ישראל ינאי | 14 | 2026-05-19 | yes |
|  | 4141 | ישראל ינאי | 14 | 2026-05-19 | yes |
| lindar@hadassah.org.il | 2555 | ד"ר רסולי | 14 | 2026-05-19 | yes |
|  | 3551 | ד"ר רסולי | 14 | 2026-05-19 | yes |
|  | 3709 | ד"ר רסולי | 14 | 2026-05-19 | yes |
| amit@nim.co.il | 2896 | עמית שגב | 14 | 2026-05-19 | yes |
|  | 4012 | עמית שגב | 14 | 2026-05-19 | yes |
| amitf@cts.co.il | 2502 | עמית פינקלשטיין | 14 | 2026-05-19 | yes |
|  | 4164 | עמית פינקלשטיין | 14 | 2026-05-19 | yes |
| atali@avaya.com | 2535 | טל אלקון | 14 | 2026-05-19 | yes |
|  | 3296 | טל אלקון | 14 | 2026-05-19 | yes |
| bad_a@mac.org.il | 2444 | אלה בד | 14 | 2026-05-19 | yes |
|  | 2445 | אלה בד | 14 | 2026-05-19 | yes |
| calibration-lab@ditronprecision.com | 2686 | עדן דיקר | 14 | 2026-05-19 | yes |
|  | 4156 | עדן דיקר | 14 | 2026-05-19 | yes |
| dalia@gold-bar.co.il | 2356 |  | 14 | 2026-05-19 | yes |
|  | 3955 |  | 14 | 2026-05-19 | yes |
| danits@oftov.co.il | 2191 | דנית שמש | 14 | 2026-05-19 | yes |
|  | 3801 | דנית שמש | 14 | 2026-05-19 | yes |
| edi@edig.co.il | 3096 | אדי טפירו | 14 | 2026-05-19 | yes |
|  | 3919 | אדי טפירו | 14 | 2026-05-19 | yes |
| einav@kaliabiotech.com | 3517 | עינב שיק | 14 | 2026-05-19 | yes |
|  | 3708 | עינב שיק | 14 | 2026-05-19 | yes |
| elena@limat.co.il | 3088 | ילנה בלקוב | 14 | 2026-05-19 | yes |
|  | 3715 | ילנה בלקוב | 14 | 2026-05-19 | yes |
| fadi_d@usr.co.il | 2413 | פאדי דוחא | 14 | 2026-05-19 | yes |
|  | 3935 | פאדי דוחא | 14 | 2026-05-19 | yes |
| gil_s@trima.co.il | 2866 | גיל שמואל | 14 | 2026-05-19 | yes |
|  | 4169 | גיל שמואל | 14 | 2026-05-19 | yes |
| golan@meditec.co.il | 2850 | גולן לוריא | 14 | 2026-05-19 | yes |
|  | 3016 | גולן לוריא | 14 | 2026-05-19 | yes |
| guyam@willi-food.co.il | 3215 | גיא עמשלם | 14 | 2026-05-19 | yes |
|  | 3217 | גיא עמשלם | 14 | 2026-05-19 | yes |
| karink@pachmas.co.il | 2777 | קארין קפלן | 14 | 2026-05-19 | yes |
|  | 3465 | קארין קפלן | 14 | 2026-05-19 | yes |
| khaled.abushaban@sanmina.com | 2766 | חאלד שבן | 14 | 2026-05-19 | yes |
|  | 3949 | חאלד שבן | 14 | 2026-05-19 | yes |
| marinah@molitan.co.il | 2824 | מרינה חוטינוב | 14 | 2026-05-19 | yes |
|  | 3815 | מרינה חוטיינוב | 14 | 2026-05-19 | yes |
| meir_n@mac.org.il | 2656 | נאווה מאיר | 14 | 2026-05-19 | yes |
|  | 3036 | נאוה מאיר | 14 | 2026-05-19 | yes |
| michael.ducovny@gmail.com | 2561 | מיכאל דוחובני | 14 | 2026-05-19 | yes |
|  | 3625 | מיכאל דוחובני | 14 | 2026-05-19 | yes |
| mohamadm@henefeld.co.il | 2479 | מסארווה מוחמאד | 14 | 2026-05-19 | yes |
|  | 3744 |  | 14 | 2026-05-19 | yes |
| moshew@paz.co.il | 2181 | משה ויינשטיין | 14 | 2026-05-19 | yes |
|  | 3287 | משה וטשטיין | 14 | 2026-05-19 | yes |
| oded@springnow.com | 3077 | עודד מסה | 14 | 2026-05-19 | yes |
|  | 3371 | עודד מסה | 14 | 2026-05-19 | yes |
| origil123456@gmail.com | 4087 | אור גיל | 14 | 2026-05-19 | yes |
|  | 4153 | אור גיל | 14 | 2026-05-19 | yes |
| osnat@chrom.co.il | 2186 | אסנת טולדנו | 14 | 2026-05-19 | yes |
|  | 3752 | אוסנת טולדנו | 14 | 2026-05-19 | yes |
| qa1@noam.urim.org.il | 2378 | יואב כרמון | 14 | 2026-05-19 | yes |
|  | 2379 |  | 14 | 2026-05-19 | yes |
| salamaz@gmail.com | 3195 | צחי סלמה | 14 | 2026-05-19 | yes |
|  | 3580 | צחי סלמה | 14 | 2026-05-19 | yes |
| salit.kochavi@phlta.health.gov.il | 2579 | מגר' אזולאי-כוכבי | 14 | 2026-05-19 | yes |
|  | 3696 | מגר' אזולאי-כוכבי | 14 | 2026-05-19 | yes |
| shimrits@tavmedical.com | 2518 |  | 14 | 2026-05-19 | yes |
|  | 2910 |  | 14 | 2026-05-19 | yes |
| shina@zmf.co.il | 2545 | שינה חדיש | 14 | 2026-05-19 | yes |
|  | 4149 | שינה חדיש | 14 | 2026-05-19 | yes |
| svetlana-l@teldor.com | 2500 | סבטלנה לפלנד | 14 | 2026-05-19 | yes |
|  | 2787 | סבטה לפנד | 14 | 2026-05-19 | yes |
| vlad.shulman@meyeden.co.il | 2765 | ולד שולמן | 14 | 2026-05-19 | yes |
|  | 3950 | ולד שולמן | 14 | 2026-05-19 | yes |
| yair@dr-fischer.com | 2814 | יאיר כץ | 14 | 2026-05-19 | yes |
|  | 4167 | יאיר כץ | 14 | 2026-05-19 | yes |
| yogevb@perflow.com | 3771 | יוגב בלק | 14 | 2026-05-19 | yes |
|  | 4154 | יוגב בלק | 14 | 2026-05-19 | yes |
| yosi@lageen.com | 2118 | יוסי אלבז | 14 | 2026-05-19 | yes |
|  | 2360 | יוסי אלבז | 14 | 2026-05-19 | yes |
| z.h.r@zhrcar.co.il | 2930 |  | 14 | 2026-05-19 | yes |
|  | 3554 |  | 14 | 2026-05-19 | yes |
| z_shavit@walla.co.il | 2348 | זלמי שביט | 14 | 2026-05-19 | yes |
|  | 3411 | זלמי שביט | 14 | 2026-05-19 | yes |

## The mechanical 31

In **31 of the 38 groups every account carries the identical name and role** — the same person
entered more than once, not a shared mailbox. Keeping the lowest id in each (the oldest account,
the one calibration history is most likely to reference) and deactivating the rest covers 34
accounts.

Deactivating is reversible; the prior state is one column. Run it as one statement:

```sql
-- capture what you are about to change
SELECT ID, Email, FirstName, LastName, IsActive
INTO   dbo.Users_DuplicateBackup_20260907
FROM   dbo.Users
WHERE  ID IN (2360,2445,2910,3016,3217,3296,3371,3411,3465,3551,3554,3580,3625,3696,3708,3709,
              3715,3801,3919,3935,3949,3950,3955,4012,4132,4133,4141,4149,4153,4154,4156,4164,
              4167,4169);

-- refuse to run if any of these would leave no active account on that address
IF EXISTS (
    SELECT 1 FROM dbo.Users AS u
    WHERE u.ID IN (2360,2445,2910,3016,3217,3296,3371,3411,3465,3551,3554,3580,3625,3696,3708,
                   3709,3715,3801,3919,3935,3949,3950,3955,4012,4132,4133,4141,4149,4153,4154,
                   4156,4164,4167,4169)
      AND NOT EXISTS (SELECT 1 FROM dbo.Users AS k
                      WHERE LOWER(LTRIM(RTRIM(k.Email))) = LOWER(LTRIM(RTRIM(u.Email)))
                        AND k.ID < u.ID))
    THROW 50001, 'One of these ids has no lower-numbered account on the same address', 1;

UPDATE dbo.Users
SET    IsActive = 0, UpdatedDate = SYSUTCDATETIME()
WHERE  ID IN (2360,2445,2910,3016,3217,3296,3371,3411,3465,3551,3554,3580,3625,3696,3708,3709,
              3715,3801,3919,3935,3949,3950,3955,4012,4132,4133,4141,4149,4153,4154,4156,4164,
              4167,4169)
  AND  ISNULL(IsActive,0) = 1;
```

To undo:

```sql
UPDATE u SET u.IsActive = b.IsActive
FROM dbo.Users AS u JOIN dbo.Users_DuplicateBackup_20260907 AS b ON b.ID = u.ID;
```

## The seven that need your eye

These are spelling variants rather than exact matches, so judge them individually. All seven look
like the same person twice:

| address | accounts |
|---|---|
| marinah@molitan.co.il | 2824 מרינה חוטינוב / 3815 מרינה חוטיינוב |
| meir_n@mac.org.il | 2656 נאווה מאיר / 3036 נאוה מאיר |
| mohamadm@henefeld.co.il | 2479 מסארווה מוחמאד / 3744 *(no name)* |
| moshew@paz.co.il | 2181 משה ויינשטיין / 3287 משה וטשטיין |
| osnat@chrom.co.il | 2186 אסנת טולדנו / 3752 אוסנת טולדנו |
| qa1@noam.urim.org.il | 2378 יואב כרמון / 2379 *(no name)* |
| svetlana-l@teldor.com | 2500 סבטלנה לפלנד / 2787 סבטה לפנד |
