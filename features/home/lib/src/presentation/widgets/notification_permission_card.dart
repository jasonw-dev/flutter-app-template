import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:permissions/permissions.dart';
import 'package:ui/ui.dart';

/// 首頁的通知權限引導卡片。
///
/// 這是 `docs/conventions.md`「權限流程」四條規則的活範例:
/// - 規則 1:**不在 initState 直接請求**——卡片只是說明,按下「開啟」才 request。
/// - 規則 2:顯示前先 `check()`,已授權就完全不顯示。
/// - 規則 3:`permanentlyDenied` 時按鈕變成「前往設定」,不再 request
///   (那不會跳對話框,使用者會以為 App 壞了)。
/// - 規則 4:拒絕不是錯誤——不上報、不顯示錯誤畫面,卡片留著即可。
class NotificationPermissionCard extends StatefulWidget {
  /// 以 [permissions] 與 [store] 建立;[store] 用來記住使用者按過「稍後」。
  const NotificationPermissionCard({
    required this.permissions,
    required this.store,
    super.key,
  });

  /// 權限請求。
  final Permissions permissions;

  /// 記住「稍後」用的儲存。
  final KeyValueStore store;

  /// 記住使用者按過「稍後」的 key。
  static const dismissedKey = 'home.notification_prompt.dismissed';

  @override
  State<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState
    extends State<NotificationPermissionCard> {
  PermissionOutcome? _outcome;
  var _dismissed = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    // 每次都 check():系統設定可能在 App 背景時被改,不快取權限狀態。
    final outcome = await widget.permissions.check(AppPermission.notifications);
    final dismissed =
        await widget.store.readBool(NotificationPermissionCard.dismissedKey) ??
        false;
    if (!mounted) {
      return;
    }
    setState(() {
      _outcome = outcome;
      _dismissed = dismissed;
      _ready = true;
    });
  }

  Future<void> _request() async {
    final outcome = await widget.permissions.request(
      AppPermission.notifications,
    );
    if (!mounted) {
      return;
    }
    setState(() => _outcome = outcome);
  }

  Future<void> _dismiss() async {
    await widget.store.writeBool(
      NotificationPermissionCard.dismissedKey,
      value: true,
    );
    if (!mounted) {
      return;
    }
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    if (!_ready ||
        _dismissed ||
        outcome == PermissionOutcome.granted ||
        outcome == PermissionOutcome.unsupported) {
      return const SizedBox.shrink();
    }
    final blocked = outcome == PermissionOutcome.permanentlyDenied;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.permissionNotificationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              blocked
                  ? context.l10n.permissionBlockedBody
                  : context.l10n.permissionNotificationBody,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => unawaited(_dismiss()),
                  child: Text(context.l10n.permissionLater),
                ),
                const SizedBox(width: 8),
                AppPrimaryButton(
                  label: blocked
                      ? context.l10n.permissionOpenSettings
                      : context.l10n.permissionEnable,
                  onPressed: () => unawaited(
                    blocked ? widget.permissions.openSettings() : _request(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
