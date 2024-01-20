import 'base.dart';
import 'sequence_error.dart';

class SequenceException implements Exception {
  final Runnable runnable;
  final Object index;

  final Object? error;
  final StackTrace trace;

  const SequenceException({
    required this.runnable,
    required this.index,
    required this.error,
    required this.trace,
  });

  @override
  String toString() => 'SequenceException: of runnable $runnable${runnable.runtimeType} at index $index with error $error';
}