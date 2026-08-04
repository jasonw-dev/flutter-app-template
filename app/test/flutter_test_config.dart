import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 所有 `app` 測試的共用前置。
///
/// **載入真實字型**:Flutter 的測試環境預設不帶任何字型,文字與圖示會渲染
/// 成實心方塊。golden 在那個狀態下仍抓得到版面/顏色/結構的退化,但抓不到
/// 字型與字重的退化,而且 png 沒辦法用肉眼 review——沒有人能確認「這張基準
/// 圖是對的」。
///
/// 字型取自釘選的 Flutter SDK(`.fvmrc`)而不是 commit 進 repo:SDK 版本本來
/// 就被釘死,字型跟著它走反而更一致,也省下兩 MB 的二進位檔。升 Flutter 版本
/// 時字型可能一併變動,**那本來就該重拍 golden**。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadTestFonts();
  await testMain();
}

Future<void> _loadTestFonts() async {
  final dir = _materialFontsDir();
  // Roboto 是 Material 在非 Apple 平台的預設字型(golden 在 ubuntu 產生),
  // 三個字重涵蓋 Material 3 TextTheme 實際用到的 w400 / w500 / w700。
  await _loadFamily(dir, 'Roboto', const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  // 沒有這個,所有 `Icon` 都是方塊(例如 `AppEmptyView` 的 inbox 圖示)。
  await _loadFamily(dir, 'MaterialIcons', const ['MaterialIcons-Regular.otf']);
}

Future<void> _loadFamily(
  Directory dir,
  String family,
  List<String> fileNames,
) async {
  final loader = FontLoader(family);
  for (final fileName in fileNames) {
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) {
      throw StateError(
        '找不到測試字型 ${file.path}。\n'
        '缺字型時 golden 會靜默退回實心方塊而不是失敗,所以這裡主動中斷。\n'
        '請確認 Flutter SDK 的 material_fonts 已下載(fvm flutter precache)。',
      );
    }
    loader.addFont(
      file.readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
}

/// 定位 SDK 的 `bin/cache/artifacts/material_fonts`。
///
/// `flutter test` 會設 `FLUTTER_ROOT`;沒有時退回從 Dart VM 的路徑推算
/// (`<flutter>/bin/cache/dart-sdk/bin/dart`,往上三層即 `bin/cache`)。
/// 兩條都失敗就丟出來,不靜默退回無字型狀態。
Directory _materialFontsDir() {
  final candidates = <Directory>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      Directory('$root/bin/cache/artifacts/material_fonts'),
    Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
      '/artifacts/material_fonts',
    ),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }
  throw StateError(
    '找不到 Flutter SDK 的 material_fonts 目錄。查過:\n'
    '${candidates.map((dir) => '  ${dir.path}').join('\n')}\n'
    '這代表測試會在沒有字型的狀態下跑,golden 將全是實心方塊。',
  );
}
