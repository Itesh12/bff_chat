import 'package:memovault/core/errors/failures.dart';
import 'package:memovault/core/errors/result.dart';

/// Illustrative generic repository interface for local storage collections.
///
/// Specific repositories (e.g. notes, messages) should define custom contracts
/// tailored to their unique querying and sync requirements.
abstract class LocalRepository<T> {
  Future<Result<T, Failure>> save(T item);
  Future<Result<List<T>, Failure>> getAll();
  Future<Result<void, Failure>> delete(int id);
  Stream<List<T>> watchAll();
}
