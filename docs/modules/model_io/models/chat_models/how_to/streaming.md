# Streaming

Some chat models provide a streaming response. This means that instead of waiting for the entire response to be returned, you can start processing it as soon as it's available. This is useful if you want to display the response to the user as it's being generated, or if you want to process the response as it's being generated.

Currently, it is supported for the following chat models:
- `ChatOpenAI`

Example usage:

```dart
final openaiApiKey = Platform.environment['OPENAI_API_KEY'];

final promptTemplate = ChatPromptTemplate.fromPromptMessages([
  SystemChatMessagePromptTemplate.fromTemplate(
    'You are a helpful assistant that replies only with numbers '
        'in order without any spaces or commas',
  ),
  HumanChatMessagePromptTemplate.fromTemplate(
    'List the numbers from 1 to {max_num}',
  ),
]);
final chat = ChatOpenAI(apiKey: openaiApiKey);
const stringOutputParser = StringOutputParser<AIChatMessage>();

final chain = promptTemplate.pipe(chat).pipe(stringOutputParser);

final stream = chain.stream({'max_num': '9'});
await stream.forEach(print);
// 123
// 456
// 789
```
