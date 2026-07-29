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
        const Scaffold(
          body: AppErrorView(
            message: 'Something went wrong. Please try again.',
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
