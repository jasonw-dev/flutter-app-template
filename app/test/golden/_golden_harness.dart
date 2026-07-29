import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';

/// **golden 只在 Linux 跑。**
///
/// Flutter 的 golden 比對對平台的字型 rasterization 與 antialiasing 敏感,
/// 同一份 png 在 macOS 與 ubuntu 產出**不會 byte-identical**。本 repo 的 CI
/// 是 ubuntu、開發端是 macOS,不處理的話第一個在 macOS 看到全紅的人會跑
/// `--update-goldens` 並 commit,CI 立刻反向變紅,來回兩輪之後就會有人把
/// golden 從 check.sh 拿掉——而 golden 正是對抗 AI agent 破壞最關鍵的一層。
///
/// png 一律由 CI 的 `update-goldens` job 產生,**不在本機產**。
final bool skipOffLinux = !Platform.isLinux;

/// 固定視窗尺寸並套上 theme 與 l10n。
///
/// 尺寸與 devicePixelRatio 必須寫死,否則不同機器產出的 png 尺寸不同。
Future<void> pumpGolden(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1080, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
