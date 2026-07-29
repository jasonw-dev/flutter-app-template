/// 間距刻度(dp)。
abstract final class AppSpacing {
  /// 4。
  static const double xs = 4;

  /// 8。
  static const double sm = 8;

  /// 16。
  static const double md = 16;

  /// 24。
  static const double lg = 24;

  /// 32。
  static const double xl = 32;
}

/// 圓角刻度(dp)。
abstract final class AppRadii {
  /// 8。
  static const double sm = 8;

  /// 12。
  static const double md = 12;

  /// 16。
  static const double lg = 16;
}

/// 動畫時長刻度。
abstract final class AppDurations {
  /// 150ms:微互動。
  static const fast = Duration(milliseconds: 150);

  /// 300ms:頁面轉場等。
  static const normal = Duration(milliseconds: 300);
}
