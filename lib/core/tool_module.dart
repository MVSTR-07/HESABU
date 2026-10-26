import 'dart:typed_data';

/// Each future tool owns its parser, analyser and immutable result model.
/// No Flutter, storage or network imports belong in core/.
abstract interface class ToolModule<TInput, TResult> {
  TInput importData(Uint8List bytes, {String? password});
  TResult analyse(TInput input);
}
