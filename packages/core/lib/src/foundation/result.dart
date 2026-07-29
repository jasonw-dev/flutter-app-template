import 'package:core/src/foundation/exceptions.dart';

/// repository 的唯一回傳形狀(spec §4.2 第 5 條):
/// 成功為 [Success],失敗為 [Failure] 且僅攜帶 [AppException]。
/// bloc 端以 fold 或 exhaustive switch 消費,禁止 try/catch。
sealed class Result<T> {
  /// 基底建構子,僅供子類 super 呼叫。
  const Result();

  /// 工廠建構子建立成功結果。
  const factory Result.success(T value) = Success<T>;

  /// 工廠建構子建立失敗結果。
  const factory Result.failure(AppException exception) = Failure<T>;

  /// 使用提供的函式轉換成功或失敗結果。
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException exception) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Failure<T>(:final exception) => onFailure(exception),
  };

  /// 將成功值轉換為新型別，失敗結果保持不變。
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result.success(transform(value)),
    Failure<T>(:final exception) => Result.failure(exception),
  };
}

/// 表示成功結果的具體類別。
final class Success<T> extends Result<T> {
  /// 使用值建立成功結果。
  const Success(this.value);

  /// 成功結果的值。
  final T value;
}

/// 表示失敗結果的具體類別。
final class Failure<T> extends Result<T> {
  /// 使用例外建立失敗結果。
  const Failure(this.exception);

  /// 失敗結果的例外。
  final AppException exception;
}
