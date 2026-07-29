# How-to:新增語系

本文件示範在既有 `en`(範本)、`zh`(泛用中文)之外,新增一個地區化語系
——以繁體中文 `zh_Hant` 為例。權威來源見
[`docs/archive/specs/2026-07-11-flutter-app-template-design.md`](../archive/specs/2026-07-11-flutter-app-template-design.md)。
l10n 的基本操作(改既有 key、regen)見根 [`CLAUDE.md`](../../CLAUDE.md) 任務
路由表;本文件只涵蓋「新增一個語系」的額外步驟。

## 1. 新增 ARB 檔

在 [`packages/localization/lib/src/arb/`](../../packages/localization/lib/src/arb/)
新增 `app_zh_Hant.arb`,`@@locale` 設為 `zh_Hant`,並複製
[`app_en.arb`](../../packages/localization/lib/src/arb/app_en.arb)(template-arb-file,
見 [`l10n.yaml`](../../packages/localization/l10n.yaml))
的完整 key 清單逐一翻譯:

```json
{
  "@@locale": "zh_Hant",
  "authEmailLabel": "電子郵件",
  "authLoginButton": "登入",
  ...
}
```

key 集合必須與 `app_en.arb` 完全一致(gen-l10n 對缺 key 的非 template 檔會
用 template 值 fallback,但不應依賴這個行為——缺 key 就是待補的翻譯債)。

## 2. Regen

```
cd packages/localization && fvm flutter gen-l10n
```

`gen-l10n` 會依 `arb-dir` 下所有 `app_*.arb` 檔重新產生
`lib/src/generated/`,新增 `AppLocalizationsZhHant` 類別。

## 3. supportedLocales 自動擴充

[`packages/localization/lib/localization.dart`](../../packages/localization/lib/localization.dart)
匯出的 `AppLocalizations.supportedLocales`、`AppLocalizations.delegate` 由
`gen-l10n` 產生碼直接維護,新增 ARB 檔後這份清單會自動包含 `Locale('zh',
'Hant')`,[`app/lib/src/app.dart`](../../app/lib/src/app.dart) 的
`MaterialApp.router` 已用
`localizationsDelegates: AppLocalizations.localizationsDelegates` /
`supportedLocales: AppLocalizations.supportedLocales` 接住,**不需要**改
`app.dart`。

## 4. Locale resolution 與 zh / zh_Hant 的 fallback 關係

`app.dart` 未設定 `locale` 或 `localeResolutionCallback`,因此沿用 Flutter
`MaterialApp` 的預設解析:比對裝置語系與 `supportedLocales`,依
languageCode+countryCode 完整匹配優先、languageCode 匹配次之。實務含意:

- 裝置語系為 `zh_TW`/`zh_Hant_TW`(繁體地區)時,若清單同時有 `zh` 與
  `zh_Hant`,Flutter 會挑與裝置 script/country 更接近的 `zh_Hant`;純
  `zh_CN` 等簡體地區則落在泛用的 `zh`(除非另補 `zh_Hans`)。
- `zh.arb`(泛用中文,目前收簡體語感文案)與 `zh_Hant.arb` 是兩份獨立、平行
  的翻譯檔,彼此不互相 fallback——gen-l10n 只有「非 template 檔缺 key 時退
  回 template(`en`)值」這一種 fallback,不存在 `zh_Hant` 缺 key 退回
  `zh` 的機制。因此新增 `zh_Hant.arb` 時仍須翻好全部 key(見上方第 1 步),
  不能只放差異 key 指望從 `zh.arb` 補齊。
- 若要再加簡體 `zh_Hans.arb`,流程相同(複製 template、翻譯、regen),不需
  額外程式碼改動。

## 5. 驗證

```
./tool/check.sh
```

第 5 步「l10n 漂移檢查」會確認 ARB 改動後已重新 `gen-l10n`(見
[`tool/check.sh`](../../tool/check.sh));新語系本身沒有專屬測試,現有
widget 測試以 `AppLocalizationsEn()` 斷言文案(見
[`conventions.md` §8.2](../conventions.md)),不需要因新增語系而改動。
