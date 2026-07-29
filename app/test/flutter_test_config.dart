import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 所有 `app` 測試的共用前置。
///
/// **載入真實字型**:預設測試環境沒有字型,文字會渲染成方塊,golden 檔會
/// 長得跟實際畫面完全不同。這一步不做的話 golden 抓不到任何有意義的退化。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();
  await testMain();
}

Future<void> _loadAppFonts() async {
  final manifest = await rootBundle.loadStructuredData<Iterable<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as Iterable<dynamic>,
  );
  for (final entry in manifest) {
    final font = entry as Map<String, dynamic>;
    final loader = FontLoader(font['family'] as String);
    for (final asset in font['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((asset as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}
