import 'package:flutter/material.dart';
import 'package:ui/src/tokens.dart';

/// 置中的載入指示。
class AppLoadingIndicator extends StatelessWidget {
  /// 建立載入指示。
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 錯誤畫面:訊息 + 可選重試。文案由呼叫端提供(design_system 不依賴 localization)。
class AppErrorView extends StatelessWidget {
  /// 建立錯誤畫面;[onRetry] 與 [retryLabel] 需成對提供,缺一則不顯示按鈕。
  const AppErrorView({
    required this.message,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  /// 錯誤訊息。
  final String message;

  /// 重試回呼。
  final VoidCallback? onRetry;

  /// 重試按鈕文字。
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 空狀態畫面。
class AppEmptyView extends StatelessWidget {
  /// 建立空狀態畫面。
  const AppEmptyView({required this.message, super.key});

  /// 空狀態訊息。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
