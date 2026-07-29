#!/usr/bin/env bash
# 一次跑完全部產生步驟。CI 說「漂移」時跑這個就對了。
#
# 收掉三條各自獨立的肌肉記憶:改 ARB 要 gen-l10n、改 pubspec 要
# gen_arch_docs、格式化生成產物。忘記任一條就是 CI 紅燈加一次來回。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "── l10n ──"
(cd packages/localization && fvm flutter gen-l10n)
fvm dart format packages/localization/lib/src/generated

echo "── 架構文件 ──"
fvm dart run tool/gen_arch_docs.dart

echo "✓ regen 完成。"
echo "  golden 不在這裡——它由 CI 的 update-goldens job 產生,本機跑會產出"
echo "  平台不同的 png(見 docs/conventions.md)。"
