/// 啟動 gate 的判定結果。
sealed class StartupGateState {
  /// 基底建構子,僅供子類 super 呼叫。
  const StartupGateState();
}

/// 一切正常,可進入 App。
final class StartupAllowed extends StartupGateState {
  /// 建立放行狀態。
  const StartupAllowed();
}

/// 必須更新才能繼續使用。
final class StartupUpdateRequired extends StartupGateState {
  /// 以商店連結建立強制更新狀態。
  const StartupUpdateRequired({required this.storeUrl});

  /// 導向商店的連結。
  final String storeUrl;
}

/// 維護中。
final class StartupUnderMaintenance extends StartupGateState {
  /// 以可選的說明建立維護狀態。
  const StartupUnderMaintenance({this.message});

  /// 要顯示給使用者的說明;null 時用 l10n 的預設文案。
  final String? message;
}

/// 啟動檢查的擴充點。
///
/// 模板出貨 [AlwaysAllowedStartupGate](永遠放行)。專案接上真實判斷依據
/// 時,實作這個介面並在 `compose_dependencies.dart` 換掉註冊即可,
/// **不需要改 bootstrap 或 router**。
// ignore: one_member_abstracts -- 契約刻意單方法,由專案提供實作
abstract interface class StartupGate {
  /// 執行一次啟動檢查。
  ///
  /// **實作必須自己處理逾時與失敗**:檢查失敗(斷網、API 掛掉)時應回傳
  /// [StartupAllowed] 而不是丟例外——**把使用者鎖在門外的代價遠大於漏擋
  /// 一次**。
  Future<StartupGateState> evaluate();
}

/// 出廠預設:永遠放行。
class AlwaysAllowedStartupGate implements StartupGate {
  /// 建立永遠放行的 gate。
  const AlwaysAllowedStartupGate();

  @override
  Future<StartupGateState> evaluate() async => const StartupAllowed();
}
