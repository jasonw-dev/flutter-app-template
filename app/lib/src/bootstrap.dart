import 'package:app/src/app.dart';
import 'package:app/src/config/app_config.dart';
import 'package:app/src/di/compose_dependencies.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foundation/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:observability/observability.dart';
import 'package:session/session.dart';

/// 掛上全域錯誤捕捉(spec §5.2 第 3 步)。
///
/// `FlutterError.onError` 轉送 widget 樹錯誤(非致命),
/// `PlatformDispatcher.instance.onError` 轉送未捕捉的非同步錯誤(致命)。
void installErrorHooks({
  required AppLogger logger,
  required CrashReporter reporter,
}) {
  FlutterError.onError = (details) {
    logger.error(
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    // ignore: discarded_futures -- 上報為 fire-and-forget，不阻塞錯誤呈現流程
    reporter.recordError(details.exception, details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(error.toString(), error: error, stackTrace: stack);
    // ignore: discarded_futures -- 上報為 fire-and-forget，不阻塞 handler 回傳
    reporter.recordError(error, stack, fatal: true);
    return true;
  };
}

/// 啟動序列(spec §5.2,順序不可變)。
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized(); // 1
  final gi = GetIt.instance;
  await composeDependencies(gi, config); // 2 純註冊
  installErrorHooks(
    // 3
    // hook 自己負責 recordError(含 fatal 語義);logger 僅供本地輸出，
    // 用 console-only 避免 prod 的 CrashReportingLogger 造成雙重上報。
    logger: ConsoleLogger(),
    reporter: gi<CrashReporter>(),
  );
  await gi.allReady(); // 4a persistence 等就緒
  if (config.firebaseEnabled) {
    // 4b
    await Firebase.initializeApp();
    await gi<BufferingCrashReporter>().attach(
      CrashlyticsCrashReporter(FirebaseCrashlytics.instance),
    );
  }
  await gi<SessionManager>().restore(); // 4c
  runApp(App(gi: gi)); // 5
}
