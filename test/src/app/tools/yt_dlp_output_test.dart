import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

void main() {
  const codes = VideoErrorCodes();

  test('parseProgress: байты, размер, скорость и остаток времени', () {
    final progress = YtDlpOutput.parseProgress('[progress] downloading 14369139 31457280 NA 5536044.34 3');

    expect(progress?.status, 'downloading');
    expect(progress?.downloadedBytes, 14369139);
    expect(progress?.totalBytes, 31457280);
    expect(progress?.speed, closeTo(5536044.34, 0.01));
    expect(progress?.eta, 3);
    expect(progress?.isFinished, isFalse);
  });

  test('parseProgress: примерный размер, когда точного нет, и неизвестные поля', () {
    final progress = YtDlpOutput.parseProgress('[progress] finished NA NA 2048.0 NA NA');

    expect(progress?.isFinished, isTrue);
    expect(progress?.downloadedBytes, isNull);
    expect(progress?.totalBytes, 2048);
    expect(progress?.speed, isNull);
  });

  test('parseProgress пропускает остальной вывод', () {
    expect(YtDlpOutput.parseProgress('[download] Destination: C:\\work\\video-137-1'), isNull);
    expect(YtDlpOutput.parseProgress('[info] probe: Downloading 1 format(s): 140'), isNull);
  });

  test('toException: проверка на бота и возраст просят войти', () {
    final botCheck = YtDlpOutput.toException(
      "ERROR: [youtube] jNQXAC9IVRw: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies",
    );
    final age = YtDlpOutput.toException('ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate');

    expect(botCheck.code, codes.botCheck);
    expect(botCheck.needsSignIn, isTrue);
    expect(age.code, codes.ageRestricted);
    expect(age.needsSignIn, isTrue);
  });

  test('toException: известные ошибки без входа', () {
    expect(YtDlpOutput.toException('ERROR: [youtube] abc: Private video. Sign in if you have access').code, codes.privateVideo);
    expect(YtDlpOutput.toException('ERROR: [youtube] abc: Video unavailable').code, codes.videoUnavailable);
    expect(YtDlpOutput.toException('ERROR: [youtube] abc: Requested format is not available').code, codes.qualityUnavailable);
  });

  test('toException: неизвестная ошибка — первое предложение последней строки ERROR', () {
    final exception = YtDlpOutput.toException(
      'WARNING: something\nERROR: unable to download video data: HTTP Error 500: Internal. See https://example.com for help',
    );

    expect(exception.code, codes.ytDlpFailed);
    expect(exception.args['error'], 'unable to download video data: HTTP Error 500: Internal.');
    expect(exception.needsSignIn, isFalse);
  });
}
