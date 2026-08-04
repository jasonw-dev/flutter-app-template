import 'dart:io';

/// `fvm dart run tool/rename_project.dart --org 反向域名 --name snake_case
/// [--display-name "顯示名稱"] [--apply]` 樣板改名工具。
///
/// 預設 **dry-run**:只列出將變更的檔案與「舊 → 新」替換摘要,不寫入。加上
/// `--apply` 才實際寫入(含 Kotlin package 目錄搬移)。
///
/// `app/pubspec.yaml` 的 Dart package name(`app`)刻意不改:workspace 其他
/// package 以 `app: any` 依賴、`package:app/...` 匯入耦合此名稱,牽一髮動
/// 全身,不在本工具改名範圍內;沿用模板名即可,不影響 Android/iOS 識別碼。
///
/// `--self-test` 旗標另外執行內建純函式(replace 規則:輸入一行字串 + 規則
/// → 輸出一行字串)的單元斷言,印 PASS/FAIL;CI 不跑,供人工/報告驗證替換
/// 邏輯正確性。
void main(List<String> arguments) {
  if (arguments.contains('--self-test')) {
    exit(_runSelfTest() ? 0 : 1);
  }

  final parsed = _parseArgs(arguments);
  if (parsed == null) {
    _printUsage();
    exit(1);
  }

  final targets = _buildTargets(
    org: parsed.org,
    name: parsed.name,
    displayName: parsed.displayName,
  );
  final newKotlinDir =
      '$_kotlinRoot/${'${parsed.org}.${parsed.name}'.replaceAll('.', '/')}';

  if (!parsed.apply) {
    _printDryRun(targets, newKotlinDir);
    return;
  }

  _apply(targets, newKotlinDir);
}

// ---------------------------------------------------------------------------
// 參數解析與驗證
// ---------------------------------------------------------------------------

final _orgFormatRegex = RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$');
final _nameFormatRegex = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

/// 解析 CLI 參數;格式錯誤或缺必要參數回傳 null。
({String org, String name, String displayName, bool apply})? _parseArgs(
  List<String> arguments,
) {
  String? org;
  String? name;
  String? displayName;
  var apply = false;

  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--org':
        if (i + 1 >= arguments.length) return null;
        org = arguments[++i];
      case '--name':
        if (i + 1 >= arguments.length) return null;
        name = arguments[++i];
      case '--display-name':
        if (i + 1 >= arguments.length) return null;
        displayName = arguments[++i];
      case '--apply':
        apply = true;
      default:
        return null;
    }
  }

  if (org == null || name == null) return null;
  if (!_orgFormatRegex.hasMatch(org)) return null;
  if (!_nameFormatRegex.hasMatch(name)) return null;

  return (org: org, name: name, displayName: displayName ?? name, apply: apply);
}

void _printUsage() {
  stderr.writeln(
    '用法:fvm dart run tool/rename_project.dart --org <反向域名> '
    '--name <snake_case> [--display-name "顯示名稱"] [--apply]\n'
    '  --org           反向域名格式,如 com.mycorp(至少兩段,各段小寫英數開頭)\n'
    '  --name          snake_case 專案名稱,如 my_app\n'
    '  --display-name  App 顯示名稱(選填,預設同 --name)\n'
    '  --apply         實際寫入變更;省略則為 dry-run(僅列出將變更內容)\n'
    '  --self-test     執行內建替換函式單元斷言,印 PASS/FAIL(CI 不跑)',
  );
}

// ---------------------------------------------------------------------------
// 目標檔案與純替換函式
// ---------------------------------------------------------------------------

const _templateAppId = 'com.example.template.app';
const _kotlinRoot = 'app/android/app/src/main/kotlin';
const _oldKotlinDir = '$_kotlinRoot/com/example/template/app';
const _oldKotlinFile = '$_oldKotlinDir/MainActivity.kt';

class _Summary {
  _Summary({required this.from, required this.to, required this.count});

  final String from;
  final String to;
  final int count;
}

class _Target {
  _Target({required this.path, required this.apply});

  final String path;
  final ({String content, List<_Summary> summaries}) Function(String content)
  apply;
}

List<_Target> _buildTargets({
  required String org,
  required String name,
  required String displayName,
}) {
  final newId = '$org.$name';
  return [
    _Target(
      path: 'pubspec.yaml',
      apply: (c) => _applyRootPubspec(c, '${name}_workspace'),
    ),
    _Target(
      path: 'app/android/app/build.gradle.kts',
      apply: (c) => _applyGradle(c, _templateAppId, newId),
    ),
    _Target(
      path: _oldKotlinFile,
      apply: (c) => _applyKotlinPackage(c, _templateAppId, newId),
    ),
    _Target(
      path: 'app/ios/Runner.xcodeproj/project.pbxproj',
      apply: (c) => _applyPbxproj(c, _templateAppId, newId),
    ),
    _Target(
      path: 'app/android/app/src/main/AndroidManifest.xml',
      apply: (c) => _applyManifest(c, displayName),
    ),
    _Target(
      path: 'app/ios/Runner/Info.plist',
      apply: (c) => _applyInfoPlist(c, displayName),
    ),
  ];
}

/// 對每一行套用 [rule];回傳套用後的完整內容與變更行數。
({String content, int count}) _applyLineRule(
  String content,
  String Function(String line) rule,
) {
  final lines = content.split('\n');
  var count = 0;
  for (var i = 0; i < lines.length; i++) {
    final updated = rule(lines[i]);
    if (updated != lines[i]) {
      count++;
      lines[i] = updated;
    }
  }
  return (content: lines.join('\n'), count: count);
}

/// 根 pubspec.yaml 的 `name: workspace_root` 行。
String _rootPubspecNameLineRule(String line, String newWorkspaceName) {
  if (line == 'name: workspace_root') {
    return 'name: $newWorkspaceName';
  }
  return line;
}

({String content, List<_Summary> summaries}) _applyRootPubspec(
  String content,
  String newWorkspaceName,
) {
  final result = _applyLineRule(
    content,
    (line) => _rootPubspecNameLineRule(line, newWorkspaceName),
  );
  if (result.count == 0) return (content: content, summaries: const []);
  return (
    content: result.content,
    summaries: [
      _Summary(
        from: 'name: workspace_root',
        to: 'name: $newWorkspaceName',
        count: result.count,
      ),
    ],
  );
}

/// Android build.gradle.kts 的 `namespace = "..."` / `applicationId = "..."` 行。
String _gradleLineRule(
  String line, {
  required String oldId,
  required String newId,
}) {
  if (!line.contains('"$oldId"')) return line;
  return line.replaceAll('"$oldId"', '"$newId"');
}

({String content, List<_Summary> summaries}) _applyGradle(
  String content,
  String oldId,
  String newId,
) {
  final result = _applyLineRule(
    content,
    (line) => _gradleLineRule(line, oldId: oldId, newId: newId),
  );
  if (result.count == 0) return (content: content, summaries: const []);
  return (
    content: result.content,
    summaries: [_Summary(from: oldId, to: newId, count: result.count)],
  );
}

/// Kotlin `package ...;` 宣告行(MainActivity.kt)。
String _kotlinPackageLineRule(
  String line, {
  required String oldId,
  required String newId,
}) {
  if (line.trim() == 'package $oldId') {
    return line.replaceFirst(oldId, newId);
  }
  return line;
}

({String content, List<_Summary> summaries}) _applyKotlinPackage(
  String content,
  String oldId,
  String newId,
) {
  final result = _applyLineRule(
    content,
    (line) => _kotlinPackageLineRule(line, oldId: oldId, newId: newId),
  );
  if (result.count == 0) return (content: content, summaries: const []);
  return (
    content: result.content,
    summaries: [
      _Summary(
        from: 'package $oldId',
        to: 'package $newId',
        count: result.count,
      ),
    ],
  );
}

/// project.pbxproj 的 `PRODUCT_BUNDLE_IDENTIFIER = ...;` 行(含 RunnerTests
/// 變體,須先比對較長的 `.RunnerTests` 字串以免被基本 id 規則誤先替換)。
String _pbxprojLineRule(
  String line, {
  required String oldId,
  required String newId,
}) {
  if (!line.contains('PRODUCT_BUNDLE_IDENTIFIER')) return line;
  final oldTests = '$oldId.RunnerTests';
  if (line.contains(oldTests)) {
    return line.replaceAll(oldTests, '$newId.RunnerTests');
  }
  if (line.contains(oldId)) {
    return line.replaceAll(oldId, newId);
  }
  return line;
}

({String content, List<_Summary> summaries}) _applyPbxproj(
  String content,
  String oldId,
  String newId,
) {
  final result = _applyLineRule(
    content,
    (line) => _pbxprojLineRule(line, oldId: oldId, newId: newId),
  );
  final baseCount = RegExp(
    '${RegExp.escape(oldId)};',
  ).allMatches(content).length;
  final testsCount = RegExp(
    '${RegExp.escape('$oldId.RunnerTests')};',
  ).allMatches(content).length;
  final summaries = <_Summary>[
    if (baseCount > 0) _Summary(from: oldId, to: newId, count: baseCount),
    if (testsCount > 0)
      _Summary(
        from: '$oldId.RunnerTests',
        to: '$newId.RunnerTests',
        count: testsCount,
      ),
  ];
  return (content: result.content, summaries: summaries);
}

/// AndroidManifest.xml 的 `android:label="..."` 行。
String _manifestLabelLineRule(String line, String newLabel) {
  final regex = RegExp('android:label="[^"]*"');
  if (!regex.hasMatch(line)) return line;
  return line.replaceFirst(regex, 'android:label="$newLabel"');
}

({String content, List<_Summary> summaries}) _applyManifest(
  String content,
  String newLabel,
) {
  final oldLabelMatch = RegExp('android:label="([^"]*)"').firstMatch(content);
  final result = _applyLineRule(
    content,
    (line) => _manifestLabelLineRule(line, newLabel),
  );
  if (result.count == 0 || oldLabelMatch == null) {
    return (content: content, summaries: const []);
  }
  return (
    content: result.content,
    summaries: [
      _Summary(
        from: 'android:label="${oldLabelMatch.group(1)}"',
        to: 'android:label="$newLabel"',
        count: result.count,
      ),
    ],
  );
}

/// Info.plist 的 `<string>...</string>` 值行(位於 `<key>` 行之後一行)。
String _plistStringValueLineRule(String line, String newValue) {
  final match = RegExp(r'^(\s*)<string>.*</string>\s*$').firstMatch(line);
  if (match == null) return line;
  return '${match.group(1)}<string>$newValue</string>';
}

({String content, List<_Summary> summaries}) _applyInfoPlist(
  String content,
  String displayName,
) {
  final lines = content.split('\n');
  final summaries = <_Summary>[];
  for (var i = 0; i < lines.length - 1; i++) {
    final key = lines[i].trim();
    if (key != '<key>CFBundleDisplayName</key>' &&
        key != '<key>CFBundleName</key>') {
      continue;
    }
    final oldValueMatch = RegExp(
      '<string>(.*)</string>',
    ).firstMatch(lines[i + 1]);
    if (oldValueMatch == null) continue;
    final updated = _plistStringValueLineRule(lines[i + 1], displayName);
    if (updated == lines[i + 1]) continue;
    final oldValue = oldValueMatch.group(1)!;
    lines[i + 1] = updated;
    summaries.add(
      _Summary(from: '$key → $oldValue', to: '$key → $displayName', count: 1),
    );
  }
  return (content: lines.join('\n'), summaries: summaries);
}

// ---------------------------------------------------------------------------
// dry-run / apply 執行
// ---------------------------------------------------------------------------

void _printDryRun(List<_Target> targets, String newKotlinDir) {
  stdout.writeln('[dry-run] 以下檔案將變更(不會寫入;加上 --apply 才會寫入):');
  var changedCount = 0;
  for (final target in targets) {
    final file = File(target.path);
    if (!file.existsSync()) {
      stdout.writeln('\n${target.path}\n  ⚠ 檔案不存在,略過');
      continue;
    }
    final result = target.apply(file.readAsStringSync());
    if (result.summaries.isEmpty) continue;
    changedCount++;
    stdout.writeln('\n${target.path}');
    for (final s in result.summaries) {
      stdout.writeln('  ${s.from} → ${s.to}(${s.count} 處)');
    }
  }

  if (Directory(_oldKotlinDir).existsSync()) {
    changedCount++;
    stdout
      ..writeln('\n$_oldKotlinDir/')
      ..writeln('  將搬移目錄 → $newKotlinDir/');
  }

  stdout.writeln('\n共 $changedCount 個檔案/目錄將變更。');
}

void _apply(List<_Target> targets, String newKotlinDir) {
  for (final target in targets) {
    final file = File(target.path);
    if (!file.existsSync()) continue;
    final result = target.apply(file.readAsStringSync());
    if (result.summaries.isEmpty) continue;
    file.writeAsStringSync(result.content);
    stdout.writeln('✓ 已更新 ${target.path}');
  }

  _moveKotlinPackageDir(newKotlinDir);

  stdout.writeln('✓ rename 完成。請執行 fvm flutter pub get 與 ./tool/check.sh 驗證。');
}

/// 將舊 Kotlin package 目錄下的檔案搬到 [newDir],並由下而上刪除搬空後的舊
/// package 目錄(不會刪到 `kotlin/` 根目錄,亦不會刪到新舊路徑共用且仍非空
/// 的祖先目錄,如兩者皆以 `com` 開頭時的 `com/` 目錄)。僅搬移直屬檔案
/// (`entity is File`);Kotlin package 目錄下如有子目錄(例如巢狀套件或額外
/// 資源目錄),需自行手動搬移,本函式不遞迴處理。
void _moveKotlinPackageDir(String newDir) {
  final oldDir = Directory(_oldKotlinDir);
  if (!oldDir.existsSync()) return;

  Directory(newDir).createSync(recursive: true);
  for (final entity in oldDir.listSync()) {
    if (entity is File) {
      entity.renameSync('$newDir/${entity.uri.pathSegments.last}');
    }
  }

  var dir = oldDir;
  while (dir.path != _kotlinRoot) {
    if (dir.listSync().isNotEmpty) break;
    final parent = dir.parent;
    dir.deleteSync();
    dir = parent;
  }

  stdout.writeln('✓ 已搬移 Kotlin package 目錄至 $newDir');
}

// ---------------------------------------------------------------------------
// --self-test:純函式單元斷言(CI 不跑)
// ---------------------------------------------------------------------------

bool _runSelfTest() {
  final cases = <({String label, bool Function() check})>[
    (
      label: 'gradle namespace 行替換',
      check: () =>
          _gradleLineRule(
            '    namespace = "com.example.template.app"',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          '    namespace = "com.mycorp.my_app"',
    ),
    (
      label: 'gradle applicationId 行替換',
      check: () =>
          _gradleLineRule(
            '        applicationId = "com.example.template.app"',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          '        applicationId = "com.mycorp.my_app"',
    ),
    (
      label: 'gradle 不相關行維持不變',
      check: () =>
          _gradleLineRule(
            '    compileSdk = flutter.compileSdkVersion',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          '    compileSdk = flutter.compileSdkVersion',
    ),
    (
      label: 'pbxproj 基本 bundle id 行替換',
      check: () =>
          _pbxprojLineRule(
            '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.template.app;',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.mycorp.my_app;',
    ),
    (
      label: 'pbxproj RunnerTests 變體行替換',
      check: () =>
          _pbxprojLineRule(
            '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = '
            'com.example.template.app.RunnerTests;',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = '
              'com.mycorp.my_app.RunnerTests;',
    ),
    (
      label: 'AndroidManifest android:label 行替換',
      check: () =>
          _manifestLabelLineRule('        android:label="app"', 'My App') ==
          '        android:label="My App"',
    ),
    (
      label: 'Kotlin package 宣告行替換',
      check: () =>
          _kotlinPackageLineRule(
            'package com.example.template.app',
            oldId: 'com.example.template.app',
            newId: 'com.mycorp.my_app',
          ) ==
          'package com.mycorp.my_app',
    ),
    (
      label: '根 pubspec name 行替換',
      check: () =>
          _rootPubspecNameLineRule(
            'name: workspace_root',
            'my_app_workspace',
          ) ==
          'name: my_app_workspace',
    ),
    (
      label: 'Info.plist <string> 值行替換',
      check: () =>
          _plistStringValueLineRule('\t<string>App</string>', 'My App') ==
          '\t<string>My App</string>',
    ),
    (
      label: 'org 格式驗證接受 com.mycorp',
      check: () => _orgFormatRegex.hasMatch('com.mycorp'),
    ),
    (label: 'org 格式驗證拒絕單段', check: () => !_orgFormatRegex.hasMatch('mycorp')),
    (
      label: 'name 格式驗證接受 my_app',
      check: () => _nameFormatRegex.hasMatch('my_app'),
    ),
    (label: 'name 格式驗證拒絕大寫', check: () => !_nameFormatRegex.hasMatch('MyApp')),
  ];

  var allPass = true;
  for (final c in cases) {
    final pass = c.check();
    allPass &= pass;
    stdout.writeln('${pass ? 'PASS' : 'FAIL'} ${c.label}');
  }
  stdout.writeln(allPass ? '\n全數 PASS' : '\n存在 FAIL');
  return allPass;
}
