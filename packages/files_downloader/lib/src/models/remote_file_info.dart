/// What the server tells about a file before downloading it
final class RemoteFileInfo {
  /// `null` when the server does not report the size
  final int? length;

  /// The server gives parts of the file: slices can be downloaded
  /// in parallel and resumed
  final bool acceptsRanges;

  /// `ETag` or `Last-Modified`: changes when the file changes
  final String? validator;

  const RemoteFileInfo({
    required this.length,
    required this.acceptsRanges,
    this.validator,
  });

  /// Slices need both the size and range support
  bool get isSliceable => length != null && acceptsRanges;

  @override
  String toString() =>
      'RemoteFileInfo(length: $length, ranges: $acceptsRanges, '
      'validator: $validator)';
}
