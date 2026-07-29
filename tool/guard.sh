#!/usr/bin/env bash
# 護欄稽核(稽核稽核者):斷言 AI agent 不會靜默削弱本庫的機器強制護欄。
# 可獨立執行,亦被 tool/check.sh 呼叫;CI 亦獨立跑一份(雙保險)。
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "✗ 護欄被削弱:$1。若為刻意變更,需在 PR 說明並經 CODEOWNERS 核可。"
  exit 1
}

# 1. analysis_options.yaml:very_good_analysis + 嚴格依賴/型別檢查未被削弱。
analysis_file="analysis_options.yaml"
[ -f "$analysis_file" ] || fail "$analysis_file 不存在"
# 用 ^\s* 錨定行首並排除以 # 開頭(被註解掉)的行,避免「註解掉即視為通過」的漏洞。
grep -Eq "^[[:space:]]*include:[[:space:]]*package:very_good_analysis/analysis_options.yaml" "$analysis_file" \
  || fail "$analysis_file 未 include package:very_good_analysis/analysis_options.yaml"
grep -Eq "^[[:space:]]*depend_on_referenced_packages:[[:space:]]*error" "$analysis_file" \
  || fail "$analysis_file 缺少 depend_on_referenced_packages: error"
grep -Eq "^[[:space:]]*strict-casts:[[:space:]]*true" "$analysis_file" \
  || fail "$analysis_file 缺少 strict-casts: true"

# 2. 產生器標記插入點:tool/new_feature.dart 接線依賴的四個標記不得被移除。
grep -q "{{route-paths}}" "packages/core/lib/src/navigation/route_paths.dart" 2>/dev/null \
  || fail "packages/core/lib/src/navigation/route_paths.dart 缺少 {{route-paths}} 標記"
grep -q "{{feature-registry}}" "app/lib/src/di/compose_dependencies.dart" 2>/dev/null \
  || fail "app/lib/src/di/compose_dependencies.dart 缺少 {{feature-registry}} 標記"
grep -q "{{feature-registry}}" "app/lib/src/router/app_router.dart" 2>/dev/null \
  || fail "app/lib/src/router/app_router.dart 缺少 {{feature-registry}} 標記"
grep -q "{{feature-registry}}" "app/test/di_smoke_test.dart" 2>/dev/null \
  || fail "app/test/di_smoke_test.dart 缺少 {{feature-registry}} 標記"

# 3. check.sh 的分層稽核不得被移除(見 issue #18)。
grep -q "bloc 純度稽核" "tool/check.sh" \
  || fail "tool/check.sh 缺少 bloc 純度稽核步驟"
grep -q "分層方向稽核" "tool/check.sh" \
  || fail "tool/check.sh 缺少分層方向稽核步驟"

grep -q "GetIt.instance 稽核" "tool/check.sh" \
  || fail "tool/check.sh 缺少 GetIt.instance 稽核步驟"
grep -q "Firebase 隔離稽核" "tool/check.sh" \
  || fail "tool/check.sh 缺少 Firebase 隔離稽核步驟"

# 4. architecture.md 的產生區塊標記不得被移除(gen_arch_docs.dart 依賴它們)。
for marker in topology dependency-table dependency-graph; do
  grep -q "BEGIN GENERATED: $marker" "docs/architecture.md" \
    || fail "docs/architecture.md 缺少 $marker 的 BEGIN GENERATED 標記"
  grep -q "END GENERATED: $marker" "docs/architecture.md" \
    || fail "docs/architecture.md 缺少 $marker 的 END GENERATED 標記"
done

# 5. .fvmrc:Flutter 版本釘選不得被移除。
[ -f ".fvmrc" ] || fail ".fvmrc 不存在"
grep -q '"flutter"' ".fvmrc" || fail ".fvmrc 缺少 \"flutter\" 版本釘選"

echo "✓ 護欄稽核全過"
