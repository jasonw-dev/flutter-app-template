import 'package:flutter/material.dart';

/// 頁面外框元件:統一 AppBar 與 SafeArea(spec §2.1 design_system)。
class AppPageScaffold extends StatelessWidget {
  /// 建立頁面外框。
  const AppPageScaffold({
    required this.title,
    required this.body,
    this.actions,
    super.key,
  });

  /// AppBar 標題。
  final String title;

  /// 頁面內容。
  final Widget body;

  /// AppBar 右側動作。
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
    );
  }
}
