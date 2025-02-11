import '../../chains/sequential.dart';
import '../base.dart';
import 'base.dart';
import 'sequence_error.dart';


/// {@template runnable_sequence}
/// A [RunnableSequence] allows you to run multiple [Runnable] objects
/// sequentially, passing the output of the previous [Runnable] to the next one.
///
/// You can create a [RunnableSequence] in several ways:
///
/// - Calling [Runnable.pipe] method which takes another [Runnable] as an
/// argument. E.g.:
///
/// ```dart
/// final chain = promptTemplate.pipe(chatModel);
/// ```
///
/// - Using the `|` operator. This is a convenience method that calls
/// [Runnable.pipe] under the hood (note that it offers less type safety than
/// [Runnable.pipe] because of Dart limitations). E.g.:
///
/// ```dart
/// final chain = promptTemplate | chatModel;
/// ```
///
/// - Using the [Runnable.fromList] static method with a list of [Runnable],
/// which will run in sequence when invoked. E.g.:
///
/// ```dart
/// final chain = Runnable.fromList([promptTemplate, chatModel]);
/// ```
///
/// When you call [invoke] on a [RunnableSequence], it will invoke each
/// [Runnable] in the sequence in order, passing the output of the previous
/// [Runnable] to the next one. The output of the last [Runnable] in the
/// sequence is returned.
///
/// You can think of [RunnableSequence] as the replacement for
/// [SequentialChain].
///
/// Example:
/// ```dart
/// final openaiApiKey = Platform.environment['OPENAI_API_KEY'];
/// final model = ChatOpenAI(apiKey: openaiApiKey);
///
/// final promptTemplate = ChatPromptTemplate.fromTemplate(
///   'Tell me a joke about {topic}',
/// );
///
/// // The following three chains are equivalent:
/// final chain1 = promptTemplate | model | const StringOutputParser();
/// final chain2 = promptTemplate.pipe(model).pipe(const StringOutputParser());
/// final chain3 = Runnable.fromList(
///   [promptTemplate, model, const StringOutputParser()],
/// );
///
/// final res = await chain1.invoke({'topic': 'bears'});
/// print(res);
/// // Why don't bears wear shoes? Because they have bear feet!
/// ```
/// {@endtemplate}
class RunnableSequence<RunInput extends Object?, RunOutput extends Object?>
    extends Runnable<RunInput, BaseLangChainOptions, RunOutput> {
  /// {@macro runnable_sequence}
  const RunnableSequence({
    required this.first,
    this.middle = const [],
    required this.last,
  });

  /// The first [Runnable] in the [RunnableSequence].
  final Runnable<RunInput, BaseLangChainOptions, Object?> first;

  /// The middle [Runnable]s in the [RunnableSequence].
  final List<Runnable> middle;

  /// The last [Runnable] in the [RunnableSequence].
  final Runnable<Object?, BaseLangChainOptions, RunOutput> last;

  /// Returns a list of all the [Runnable]s in the [RunnableSequence].
  List<Runnable> get steps => [first, ...middle, last];

  /// Creates a [RunnableSequence] from a list of [Runnable]s.
  ///
  /// - [runnables] - the [Runnable]s to create the [RunnableSequence] from.
  static RunnableSequence from(final List<Runnable> runnables) {
    if (runnables.length < 2) {
      throw ArgumentError('You must provide at least two runnables to create a RunnableSequence. length is ${runnables.length}');
    }
  
    return RunnableSequence(
      first: runnables.first,
      middle: runnables.sublist(1, runnables.length - 1),
      last: runnables.last,
    );
  }

  /// Invokes the [RunnableSequence] on the given [input].
  ///
  /// - [input] - the input to invoke the [RunnableSequence] on.
  /// - [options] - the options to use when invoking the [RunnableSequence].
  @override
  Future<RunOutput> invoke(
    final RunInput input, {
    final BaseLangChainOptions? options,
  }) async {
    Object? nextStepInput = input;

    var idx = 0;
    for (final step in [first, ...middle]) {
      try {
        nextStepInput = await step.invoke(nextStepInput, options: options);
        idx++;
      } catch (e, t) {
        throw SequenceException(runnable: step, index: idx, error: e, trace: t);
      }
    }

    try {
      return await last.invoke(nextStepInput, options: options);
    } catch (e, t) {
      throw SequenceException(runnable: last, index: idx, error: e, trace: t);
    }
  }

  @override
  Stream<RunOutput> streamFromInputStream(
    final Stream<dynamic> inputStream, {
    final BaseLangChainOptions? options,
  }) {
    bool errorTester(final Object? obj) => obj is! SequenceException;

    void Function(Object?, StackTrace) createErrorHandler(final Runnable runnable, final int idx) {
      return (final Object? e, final StackTrace t)
        => throw SequenceException(runnable: runnable, index: idx, error: e, trace: t); 
    }

    var nextStepStream = first.streamFromInputStream(inputStream)
      .handleError(createErrorHandler(first, 0), test: errorTester);

    var idx = 0;
    for (final step in middle) {
      nextStepStream = step.streamFromInputStream(nextStepStream)
        .handleError(createErrorHandler(step, idx), test: errorTester);

      idx++;
    }

    return last.streamFromInputStream(nextStepStream)
      .handleError(createErrorHandler(last, idx), test: errorTester);
  }

  /// Pipes the output of this [RunnableSequence] into another [Runnable].
  ///
  /// - [next] - the [Runnable] to pipe the output into.
  @override
  RunnableSequence<RunInput, NewRunOutput> pipe<NewRunOutput extends Object?,
      NewCallOptions extends BaseLangChainOptions>(
    final Runnable<RunOutput, NewCallOptions, NewRunOutput> next,
  ) {
    if (next is RunnableSequence<RunOutput, NewRunOutput>) {
      final nextSeq = next as RunnableSequence<RunOutput, NewRunOutput>;
      return RunnableSequence(
        first: first,
        middle: [...middle, last, nextSeq.first, ...nextSeq.middle],
        last: nextSeq.last,
      );
    } else {
      return RunnableSequence(
        first: first,
        middle: [...middle, last],
        last: next,
      );
    }
  }
}
