## 說明

<!-- 這個 PR 做了什麼、為什麼 -->

## 完成的定義

- [ ] 目標分支正確(Git Flow;見 `docs/conventions.md` §分支與 PR)
- [ ] `./tool/check.sh` 本機全綠
- [ ] bloc 事件 → 狀態轉換有測試
- [ ] repository 轉換與錯誤映射有測試
- [ ] page 三態(loading/success/error)渲染有測試
- [ ] 新增 `// ignore:` 皆附原因
- [ ] 未動 `tool/`、`analysis_options.yaml`、`.github/`(或已於下方說明並經 CODEOWNERS 核可)
- [ ] 文案變更皆走 ARB(`packages/localization/lib/src/arb/*.arb`)+ `flutter gen-l10n` regen

## 護欄變更說明(若適用)

<!-- 若本 PR 觸及 tool/、analysis_options.yaml、.github/、docs/adr/、.fvmrc,說明變更原因 -->
