part of 'video_metadata_service.dart';

/// The Windows Shell: the duration from the file properties and the thumbnail
/// Explorer shows
final class _WindowsVideoMetadataReader implements _VideoMetadataReader {
  /// `System.Media.Duration`, in 100-nanosecond units
  static const _durationKeyFormat = '{64440490-4C8B-11D1-8B70-080036B11A03}';
  static const _durationKeyId = 3;
  static const _ticksPerMillisecond = 10000;

  const _WindowsVideoMetadataReader();

  @override
  Future<(Duration?, Uint8List?)> read(
    String videoPath, {
    required bool withThumbnail,
  }) async {
    /// COM calls and JPEG encoding run off the UI isolate
    final (durationMs, thumbnail) = await Isolate.run(
      () => _readMetadata(videoPath, withThumbnail: withThumbnail),
    );

    return (
      durationMs == null ? null : Duration(milliseconds: durationMs),
      thumbnail,
    );
  }

  /// Duration in milliseconds and the JPEG thumbnail. Runs synchronously
  /// on one thread: COM is initialized for the calling thread
  static (int?, Uint8List?) _readMetadata(
    String videoPath, {
    required bool withThumbnail,
  }) {
    final initialized = win32.CoInitializeEx(win32.COINIT_APARTMENTTHREADED);
    final path = videoPath.toPcwstr();

    try {
      final item = win32.SHCreateItemFromParsingName<win32.IShellItem2>(
        path,
        null,
      );

      try {
        return (_durationOf(item), withThumbnail ? _thumbnailOf(item) : null);
      } finally {
        item.release();
      }
    } on win32.WindowsException {
      return (null, null);
    } finally {
      win32.free(path);

      /// A thread already initialized in another mode is left as it was
      if (initialized.isOk) win32.CoUninitialize();
    }
  }

  static int? _durationOf(win32.IShellItem2 item) {
    final key = calloc<win32.PROPERTYKEY>();

    try {
      key.ref.fmtid.setGUID(_durationKeyFormat);
      key.ref.pid = _durationKeyId;

      return item.getUInt64(key) ~/ _ticksPerMillisecond;
    } on win32.WindowsException {
      return null;
    } finally {
      calloc.free(key);
    }
  }

  /// Only a real thumbnail: without one Windows would give the file type icon
  static Uint8List? _thumbnailOf(win32.IShellItem2 item) {
    final win32.IShellItemImageFactory factory;

    try {
      factory = item.queryInterface<win32.IShellItemImageFactory>();
    } on win32.WindowsException {
      return null;
    }

    try {
      final size = Struct.create<win32.SIZE>()
        ..cx = PlayerConstants.thumbnailWidth
        ..cy = PlayerConstants.thumbnailHeight;
      final bitmap = factory.getImage(size, win32.SIIGBF_THUMBNAILONLY);

      try {
        return _jpegOf(bitmap);
      } finally {
        win32.DeleteObject(win32.HGDIOBJ(bitmap));
      }
    } on win32.WindowsException {
      return null;
    } finally {
      factory.release();
    }
  }

  static Uint8List? _jpegOf(win32.HBITMAP bitmap) {
    final info = calloc<win32.BITMAP>();
    final header = calloc<win32.BITMAPINFO>();
    final context = win32.CreateCompatibleDC(null);
    Pointer<Uint8>? pixels;

    try {
      final infoSize = sizeOf<win32.BITMAP>();

      if (win32.GetObject(win32.HGDIOBJ(bitmap), infoSize, info) == 0) {
        return null;
      }

      final width = info.ref.bmWidth;
      final height = info.ref.bmHeight.abs();

      if (width <= 0 || height <= 0) return null;

      /// A negative height asks for rows from top to bottom
      header.ref.bmiHeader
        ..biSize = sizeOf<win32.BITMAPINFOHEADER>()
        ..biWidth = width
        ..biHeight = -height
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = win32.BI_RGB;

      final length = width * height * 4;

      pixels = calloc<Uint8>(length);

      final copiedRows = win32.GetDIBits(
        context,
        bitmap,
        0,
        height,
        pixels,
        header,
        win32.DIB_RGB_COLORS,
      );

      if (copiedRows == 0) return null;

      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: Uint8List.fromList(pixels.asTypedList(length)).buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );

      return img.encodeJpg(
        image,
        quality: VideoMetadataServiceImpl._jpegQuality,
      );
    } finally {
      if (pixels != null) calloc.free(pixels);
      win32.DeleteDC(context);
      calloc
        ..free(info)
        ..free(header);
    }
  }
}
