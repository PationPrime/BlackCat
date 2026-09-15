part of 'download_task_dto.dart';

/// Selected download stream in the queue database
@immutable
class DownloadStreamDto {
  final DownloadStreamRole role;
  final int itag;
  final int contentLength;

  const DownloadStreamDto({
    required this.role,
    required this.itag,
    required this.contentLength,
  });

  factory DownloadStreamDto.fromModel(DownloadStreamModel stream) =>
      DownloadStreamDto(
        role: stream.role,
        itag: stream.itag,
        contentLength: stream.contentLength,
      );

  DownloadStreamModel toModel() => DownloadStreamModel(
    role: role,
    itag: itag,
    contentLength: contentLength,
  );
}
