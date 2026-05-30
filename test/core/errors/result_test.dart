import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/errors/failures.dart';
import 'package:memovault/core/errors/result.dart';

class TestFailure extends Failure {
  const TestFailure(super.message);
}

void main() {
  group('Result Wrapper Tests', () {
    test('Success fold returns correct value and executes onSuccess', () {
      const result = Success<String, TestFailure>('data');

      final output = result.fold(
        (success) => 'Success: $success',
        (failure) => 'Failure: ${failure.message}',
      );

      expect(output, 'Success: data');
    });

    test('FailureResult fold returns correct failure and executes onFailure', () {
      const result = FailureResult<String, TestFailure>(TestFailure('error_msg'));

      final output = result.fold(
        (success) => 'Success: $success',
        (failure) => 'Failure: ${failure.message}',
      );

      expect(output, 'Failure: error_msg');
    });
  });
}
