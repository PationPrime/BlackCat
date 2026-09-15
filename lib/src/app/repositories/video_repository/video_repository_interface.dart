import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../base_repository_interface.dart';

abstract interface class VideoRepositoryInterface
    implements BaseRepositoryInterface {
  Future<OperationResult<VideoInfoModel>> getVideoInfo(String url);

  /// Скачивает видео в выбранном качестве в «Загрузки».
  /// Возвращает путь к готовому файлу
  Future<OperationResult<String>> downloadVideo({
    required String url,
    required String quality,
    void Function(DownloadProgressModel progress)? onProgress,
  });
}
