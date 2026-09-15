import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

const _video = DownloadStreamModel(role: DownloadStreamRole.video, itag: 137, contentLength: 52428800);

void main() {
  test('имя файла потока: роль, itag и размер', () {
    expect(DownloadPartFiles.fileName(_video), 'video-137-52428800.part');
    expect(DownloadPartFiles.path(r'C:\work\task', _video), p.join(r'C:\work\task', 'video-137-52428800.part'));
  });

  test('parse восстанавливает поток по имени и пропускает чужие файлы', () {
    expect(DownloadPartFiles.parse('video-137-52428800.part'), _video);
    expect(
      DownloadPartFiles.parse('audio-140-2428800.part'),
      const DownloadStreamModel(role: DownloadStreamRole.audio, itag: 140, contentLength: 2428800),
    );
    expect(DownloadPartFiles.parse('output.mp4'), isNull);
    expect(DownloadPartFiles.parse('subtitles-1-2.part'), isNull);
  });

  test('resumableBytes не засчитывает файл длиннее потока', () {
    expect(DownloadPartFiles.resumableBytes(1024, _video), 1024);
    expect(DownloadPartFiles.resumableBytes(52428800, _video), 52428800);
    expect(DownloadPartFiles.resumableBytes(52428801, _video), 0);
  });
}
