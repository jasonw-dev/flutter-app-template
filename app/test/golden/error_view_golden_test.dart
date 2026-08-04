import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import '_golden_harness.dart';

void main() {
  testWidgets(
    'AppErrorView',
    (tester) async {
      // 選這個元件是因為它是 packages/ui 的共用元件——改壞它會同時影響
      // 所有頁面,是最划算的一張 golden。
      await pumpGolden(
        tester,
        Scaffold(
          body: AppErrorView(
            message: 'Something went wrong. Please try again.',
            // onRetry 與 retryLabel 必須成對給,缺一則按鈕整個不渲染
            // (見 AppErrorView.build)。只給 label 的話這張 golden 就只剩
            // 一行文字,按鈕那條分支等於沒有守到。
            onRetry: () {},
            retryLabel: 'Retry',
          ),
        ),
      );

      await expectLater(
        find.byType(AppErrorView),
        matchesGoldenFile('goldens/error_view.png'),
      );
    },
    skip: skipOffLinux,
  );
}
