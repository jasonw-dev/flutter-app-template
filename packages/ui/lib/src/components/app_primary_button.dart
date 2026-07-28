import 'package:flutter/material.dart';

/// 主要動作按鈕;loading 時停用並顯示 indicator。
class AppPrimaryButton extends StatelessWidget {
  /// 建立主要按鈕。
  const AppPrimaryButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    super.key,
  });

  /// 按鈕文字。
  final String label;

  /// 點擊回呼;null 時停用。
  final VoidCallback? onPressed;

  /// 是否處於載入中。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
