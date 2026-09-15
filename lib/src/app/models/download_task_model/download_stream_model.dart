part of 'download_task_model.dart';

enum DownloadStreamRole { video, audio }

/// A stream downloaded for a download task.
///
/// Stream links expire within a few hours, so instead of the link we store
/// what finds the stream in a fresh YouTube response: itag and exact size.
/// The size tells apart audio tracks of a dubbed video with the same itag
class DownloadStreamModel extends Equatable {
  final DownloadStreamRole role;
  final int itag;

  /// Stream size in bytes
  final int contentLength;

  const DownloadStreamModel({
    required this.role,
    required this.itag,
    required this.contentLength,
  });

  @override
  List<Object?> get props => [role, itag, contentLength];
}
