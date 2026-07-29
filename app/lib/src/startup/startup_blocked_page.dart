import 'dart:async';

import 'package:app/src/startup/startup_gate.dart';
import 'package:app/src/startup/startup_gate_controller.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 啟動 gate 擋下時顯示的頁。
///
/// 依 [StartupGateController.state] 分支渲染;狀態變回 [StartupAllowed] 時
/// router 會立刻把使用者重導回首頁,所以那個分支只是過場。
class StartupBlockedPage extends StatelessWidget {
  /// 以 [controller] 建立。
  const StartupBlockedPage({required this.controller, super.key});

  /// 提供目前判定結果與重新評估的入口。
  final StartupGateController controller;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: context.l10n.startupBlockedTitle,
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.state) {
          StartupUpdateRequired(:final storeUrl) => AppErrorView(
            message: context.l10n.startupUpdateMessage,
            onRetry: () => unawaited(
              launchUrl(
                Uri.parse(storeUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            retryLabel: context.l10n.startupUpdateAction,
          ),
          StartupUnderMaintenance(:final message) => AppErrorView(
            message: message ?? context.l10n.startupMaintenanceMessage,
            onRetry: () => unawaited(controller.evaluate()),
            retryLabel: context.l10n.commonRetry,
          ),
          // 不該出現;router 會立刻重導走。
          StartupAllowed() => const AppLoadingIndicator(),
        },
      ),
    );
  }
}
