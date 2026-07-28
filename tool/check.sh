#!/usr/bin/env bash
# 與 CI 完全同構的本機檢查(spec §6.2)。本機過了,CI 就會過。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "── 0/11 pub get ──"
fvm flutter pub get

echo "── 1/11 format ──"
# 只掃第一方原始碼,不用 `.`(見 issue #40)。macOS 上 `flutter pub get` 會做
# iOS 端的 Swift Package Manager 解析,把第三方套件展開到 <package>/build/ios/
# SourcePackages/,`dart format .` 會走進去把別人的 code 一起格式化並 exit 1。
# `dart format` 沒有排除參數,只能自己列檔。
# `.dart_tool/` 也要排除:遞迴時 dart format 本來就跳過隱藏目錄,但這裡是把
# 路徑明確餵進去,不排除的話連 dart_plugin_registrant.dart 都會被格式化。
find app features packages tool -name "*.dart" \
  -not -path "*/build/*" -not -path "*/.dart_tool/*" -print0 |
  xargs -0 fvm dart format --set-exit-if-changed

echo "── 2/11 ignore 稽核(// ignore: 必須附 ' -- 原因')──"
# 生成產物豁免:/src/generated/ 與根 analysis_options.yaml 的
# analyzer.exclude 對齊;build/ 與 .dart_tool/ 為 build 產物,理由同 1/11(#40)
violations=$(grep -rn "// ignore" --include="*.dart" packages app features tool 2>/dev/null | grep -v "/src/generated/" | grep -v "/build/" | grep -v "/\.dart_tool/" | grep -v -- " -- " || true)
if [ -n "$violations" ]; then
  echo "✗ 未附原因的 ignore:"
  echo "$violations"
  exit 1
fi

echo "── 3/11 護欄稽核(稽核稽核者;見 tool/guard.sh)──"
bash tool/guard.sh

echo "── 4/11 pubspec 依賴稽核(features 不得互依,packages 不得依賴 feature/app)──"
# 僅比對 dependencies: 至 dev_dependencies: 之間的區段;依賴名為 '^  <name>:'。
feature_names=$(ls features)
dep_violations=""
for dir in features/*; do
  name=$(basename "$dir")
  forbidden="app"
  for other in $feature_names; do
    [ "$other" = "$name" ] && continue
    forbidden="$forbidden $other"
  done
  deps=$(awk '/^dependencies:/{f=1;next}/^dev_dependencies:/{f=0}f' "$dir/pubspec.yaml")
  for word in $forbidden; do
    hit=$(echo "$deps" | grep -E "^  ${word}:" || true)
    if [ -n "$hit" ]; then
      dep_violations="${dep_violations}${dir}/pubspec.yaml: ${hit}
"
    fi
  done
done
for dir in packages/*; do
  deps=$(awk '/^dependencies:/{f=1;next}/^dev_dependencies:/{f=0}f' "$dir/pubspec.yaml")
  for word in app $feature_names; do
    hit=$(echo "$deps" | grep -E "^  ${word}:" || true)
    if [ -n "$hit" ]; then
      dep_violations="${dep_violations}${dir}/pubspec.yaml: ${hit}
"
    fi
  done
done
if [ -n "$dep_violations" ]; then
  echo "✗ 違反依賴方向(feature 不得互依,package 不得依賴 feature/app):"
  printf '%s' "$dep_violations"
  exit 1
fi

echo "── 5/11 bloc 純度稽核(bloc/event/state 不得 import Flutter)──"
# conventions §2 第 6 條。grep 找不到東西時 exit 1,而本腳本有 set -euo pipefail,
# 故必須用 `|| true` 包住,否則「檢查通過」會變成「腳本中止」。
# --include 涵蓋 *_cubit.dart:目前庫裡沒有 cubit,#22 會引入,先寫進去免得漏。
bloc_violations=$(grep -rn -E "^import 'package:(flutter|flutter_bloc)/" \
  --include="*_bloc.dart" --include="*_cubit.dart" \
  --include="*_event.dart" --include="*_state.dart" \
  features packages app 2>/dev/null || true)
if [ -n "$bloc_violations" ]; then
  echo "✗ bloc/cubit/event/state 不得 import Flutter(規則見 docs/conventions.md §2 第 6 條):"
  echo "$bloc_violations"
  exit 1
fi

echo "── 6/11 分層方向稽核(presentation 不得 import data 層)──"
# conventions §1「層內依賴方向」:presentation → domain ← data。
# 路徑用 shell glob;某個 feature 若還沒有 presentation 目錄,2>/dev/null 吃掉錯誤,行為正確。
layer_violations=$(grep -rn -E "^import 'package:[a-z_]+/src/data/" \
  --include="*.dart" \
  features/*/lib/src/presentation 2>/dev/null || true)
if [ -n "$layer_violations" ]; then
  echo "✗ presentation 不得 import data 層(規則見 docs/conventions.md §1 層內依賴方向):"
  echo "$layer_violations"
  exit 1
fi

echo "── 7/11 Firebase 隔離稽核(app 與 core 不得直接依賴 firebase_*)──"
# ADR-0006:介面留在 core,Firebase 實作只能住在可選成員 packages/integrations,
# 「移除 Firebase」才能收斂成 docs/how-to/remove-firebase.md 的四步。
fb_violations=$(grep -rn -E "^import 'package:firebase_" --include="*.dart" \
  app/lib packages/core/lib 2>/dev/null || true)
if [ -n "$fb_violations" ]; then
  echo "✗ firebase_* 只能在 packages/integrations 內使用(見 docs/adr/0006):"
  echo "$fb_violations"
  exit 1
fi

echo "── 8/11 GetIt.instance 稽核(page 不得直接取全域容器)──"
# conventions §5:page 一律 context.read<GetIt>(),lib/ 內不得出現 GetIt.instance。
# 唯一例外是 app/lib/src/bootstrap.dart(容器的建立處),故排除該檔。
gi_violations=$(grep -rn "GetIt.instance" --include="*.dart" features packages app tool 2>/dev/null \
  | grep -v "/test/" | grep -v "/build/" | grep -v "app/lib/src/bootstrap.dart" || true)
if [ -n "$gi_violations" ]; then
  echo "✗ lib 內不得使用 GetIt.instance,請改用 context.read<GetIt>()(規則見 docs/conventions.md §5):"
  echo "$gi_violations"
  exit 1
fi

echo "── 9/11 l10n 漂移檢查(ARB 需 regen 為 committed 產物)──"
(cd packages/localization && fvm flutter gen-l10n)
fvm dart format packages/localization/lib/src/generated
if ! git diff --exit-code -- packages/localization/lib/src/generated; then
  echo "✗ ARB 已改但未 regen:請執行 (cd packages/localization && fvm flutter gen-l10n) 並將 lib/src/generated 的變更納入本 commit"
  exit 1
fi

echo "── 10/11 analyze ──"
# 同樣只掃第一方原始碼(見 issue #40)。不能改用 analysis_options.yaml 的
# analyzer.exclude:build/ios/SourcePackages/ 底下每個套件各有自己的
# pubspec.yaml,analyzer 會為它們建獨立的 analysis context,外層的 exclude
# 管不到(實測仍會回報 402 個 issue)。
fvm flutter analyze app/lib app/test features packages tool

echo "── 11/11 tests(逐 package)──"
for dir in packages/* features/* app; do
  [ -d "$dir/test" ] || continue
  echo "→ $dir"
  if grep -q "sdk: flutter" "$dir/pubspec.yaml"; then
    (cd "$dir" && fvm flutter test)
  else
    (cd "$dir" && fvm dart test)
  fi
done

echo "✓ all checks passed"
