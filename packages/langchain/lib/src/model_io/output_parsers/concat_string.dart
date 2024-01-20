import '../../core/core.dart';
import '../../model_io/chat_models/models/models.dart';
import 'output_parser.dart';

/// {@template string_output_parser}
/// Output parser that parses the first generation as String.
///
/// - [ModelOutput] - The output of the language model (`String` for LLMs or
/// `ChatMessage` for chat models).
///
/// Example:
/// ```dart
/// final model = ChatOpenAI(apiKey: openaiApiKey);
/// final promptTemplate = ChatPromptTemplate.fromTemplate(
///   'Tell me a joke about {topic}',
/// );
/// final chain = promptTemplate | model | const StringOutputParser();
/// final res = await chain.invoke({'topic': 'bears'});
/// print(res);
/// // Why don't bears wear shoes? Because they have bear feet!
/// ```
/// {@endtemplate}
class StringChatConcatOutputParser<ModelOutput extends AIChatMessage>
    extends BaseOutputParser<ModelOutput, BaseLangChainOptions, String> {
  /// {@macro string_output_parser}
  const StringChatConcatOutputParser();

  @override
  Future<String> parse(final String text) {
    return Future.value(text);
  }

  /// Streams the output of invoking the [Runnable] on the given [inputStream].
  ///
  /// - [inputStream] - the input stream to invoke the [Runnable] on.
  /// - [options] - the options to use when invoking the [Runnable].
  @override
  Stream<String> streamFromInputStream(
    final Stream<dynamic> inputStream, {
    final BaseLangChainOptions? options,
  }) {
    // By default, it just emits the result of calling invoke
    // Subclasses should override this method if they support streaming output
    return Stream.fromFuture(inputStream
      .cast<ChatResult>()
      // ignore: discarded_futures
      .reduce((final previous, final element) => previous.concat(element))
      // ignore: discarded_futures
      .then((final value) => parseResult(value.generations.cast())),);
  }
}
