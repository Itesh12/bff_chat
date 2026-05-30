import 'package:memovault/core/errors/failures.dart';

/// Represents the outcome of an operation.
sealed class Result<S, F extends Failure> {
  const Result();

  /// Executes [onSuccess] if result is successful, or [onFailure] if failed.
  T fold<T>(T Function(S success) onSuccess, T Function(F failure) onFailure);
}

class Success<S, F extends Failure> extends Result<S, F> {
  final S value;
  const Success(this.value);

  @override
  T fold<T>(T Function(S success) onSuccess, T Function(F failure) onFailure) {
    return onSuccess(value);
  }
}

class FailureResult<S, F extends Failure> extends Result<S, F> {
  final F failure;
  const FailureResult(this.failure);

  @override
  T fold<T>(T Function(S success) onSuccess, T Function(F failure) onFailure) {
    return onFailure(failure);
  }
}
