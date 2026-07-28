/// 全專案唯一的例外體系(spec §2.4)。
///
/// 規則:repository 一律回傳 Result 且 failure 端只能是 AppException 子類;
/// 各 feature 不得自創例外型別。轉換責任:networking 攔截器產生前四類,
/// data 層產生 ParsingException,persistence 產生 StorageException,
/// packages/native 產生 NativeException。
sealed class AppException implements Exception {
  /// 建立例外,可選擇性攜帶原始錯誤 [cause] 與其堆疊 [stackTrace]。
  const AppException({this.cause, this.stackTrace});

  /// 原始錯誤(如 DioException),僅供 observability 記錄,UI 不得使用。
  final Object? cause;

  /// 原始錯誤發生當下的堆疊追蹤,僅供 observability 記錄。
  final StackTrace? stackTrace;
}

/// 無網路、DNS 失敗、連線逾時。
final class ConnectivityException extends AppException {
  /// 建立連線失敗例外。
  const ConnectivityException({super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'ConnectivityException()'
      : 'ConnectivityException(cause: $cause)';
}

/// HTTP 5xx。
final class ServerException extends AppException {
  /// 建立伺服器錯誤例外,需帶入 HTTP 狀態碼 [statusCode]。
  const ServerException({
    required this.statusCode,
    super.cause,
    super.stackTrace,
  });

  /// 伺服器回應的 HTTP 狀態碼(5xx)。
  final int statusCode;

  /// 輸出類別名稱、[statusCode] 與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'ServerException(statusCode: $statusCode)'
      : 'ServerException(statusCode: $statusCode, cause: $cause)';
}

/// 401,且 token refresh 失敗(觸發 session 過期流程)。
final class UnauthorizedException extends AppException {
  /// 建立未授權例外。
  const UnauthorizedException({super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'UnauthorizedException()'
      : 'UnauthorizedException(cause: $cause)';
}

/// HTTP 4xx 業務錯誤,攜帶後端錯誤碼與訊息。
final class ApiException extends AppException {
  /// 建立業務錯誤例外,需帶入後端錯誤碼 [code] 與訊息 [message]。
  const ApiException({
    required this.code,
    required this.message,
    super.cause,
    super.stackTrace,
  });

  /// 後端定義的業務錯誤碼。
  final String code;

  /// 後端回傳的錯誤訊息。
  final String message;

  /// 輸出類別名稱、[code]、[message] 與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'ApiException(code: $code, message: $message)'
      : 'ApiException(code: $code, message: $message, cause: $cause)';
}

/// JSON 解析或 DTO 轉換失敗。
final class ParsingException extends AppException {
  /// 建立解析失敗例外。
  const ParsingException({super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() =>
      cause == null ? 'ParsingException()' : 'ParsingException(cause: $cause)';
}

/// 本地儲存讀寫失敗。
final class StorageException extends AppException {
  /// 建立本地儲存失敗例外。
  const StorageException({super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() =>
      cause == null ? 'StorageException()' : 'StorageException(cause: $cause)';
}

/// 原生能力呼叫失敗,code 為 pigeon 介面定義的錯誤碼。
final class NativeException extends AppException {
  /// 建立原生呼叫失敗例外,需帶入錯誤碼 [code]。
  const NativeException({required this.code, super.cause, super.stackTrace});

  /// pigeon 介面定義的錯誤碼。
  final String code;

  /// 輸出類別名稱、[code] 與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'NativeException(code: $code)'
      : 'NativeException(code: $code, cause: $cause)';
}

/// 請求被主動取消(頁面關閉、使用者輸入變更等)。
///
/// 消費端(bloc)應**靜默忽略**:不顯示錯誤畫面、不上報。
/// 取消是預期中的控制流,不是失敗。
final class CancelledException extends AppException {
  /// 建立取消例外。
  const CancelledException({super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause](若有)供除錯與記錄使用。
  @override
  String toString() => cause == null
      ? 'CancelledException()'
      : 'CancelledException(cause: $cause)';
}

/// 以上皆非的兜底。出現即代表有未收攏的錯誤來源,應追查 [cause]。
/// [cause] 為必填,因為此例外一定是包裝某個未預期的原始錯誤而產生。
final class UnknownException extends AppException {
  /// 建立未知錯誤例外,必須帶入原始錯誤 [cause]。
  const UnknownException({required Object super.cause, super.stackTrace});

  /// 輸出類別名稱與 [cause] 供除錯與記錄使用。
  @override
  String toString() => 'UnknownException(cause: $cause)';
}
