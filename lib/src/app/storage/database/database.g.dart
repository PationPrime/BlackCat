// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DownloadTasksTableTable extends DownloadTasksTable
    with TableInfo<$DownloadTasksTableTable, DownloadTasksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailMeta = const VerificationMeta(
    'thumbnail',
  );
  @override
  late final GeneratedColumn<String> thumbnail = GeneratedColumn<String>(
    'thumbnail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewCountMeta = const VerificationMeta(
    'viewCount',
  );
  @override
  late final GeneratedColumn<int> viewCount = GeneratedColumn<int>(
    'view_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityIdMeta = const VerificationMeta(
    'qualityId',
  );
  @override
  late final GeneratedColumn<String> qualityId = GeneratedColumn<String>(
    'quality_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<QualityKind, String> qualityKind =
      GeneratedColumn<String>(
        'quality_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<QualityKind>(
        $DownloadTasksTableTable.$converterqualityKind,
      );
  static const VerificationMeta _qualityLabelMeta = const VerificationMeta(
    'qualityLabel',
  );
  @override
  late final GeneratedColumn<String> qualityLabel = GeneratedColumn<String>(
    'quality_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _qualityResolutionMeta = const VerificationMeta(
    'qualityResolution',
  );
  @override
  late final GeneratedColumn<int> qualityResolution = GeneratedColumn<int>(
    'quality_resolution',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualitySizeMeta = const VerificationMeta(
    'qualitySize',
  );
  @override
  late final GeneratedColumn<int> qualitySize = GeneratedColumn<int>(
    'quality_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityIsAacMeta = const VerificationMeta(
    'qualityIsAac',
  );
  @override
  late final GeneratedColumn<bool> qualityIsAac = GeneratedColumn<bool>(
    'quality_is_aac',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("quality_is_aac" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskStatus, String>
  status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadTaskStatus>(
        $DownloadTasksTableTable.$converterstatus,
      );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskSection, String>
  section =
      GeneratedColumn<String>(
        'section',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadTaskSection>(
        $DownloadTasksTableTable.$convertersection,
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureMessageMeta = const VerificationMeta(
    'failureMessage',
  );
  @override
  late final GeneratedColumn<String> failureMessage = GeneratedColumn<String>(
    'failure_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureNeedsSignInMeta =
      const VerificationMeta('failureNeedsSignIn');
  @override
  late final GeneratedColumn<bool> failureNeedsSignIn = GeneratedColumn<bool>(
    'failure_needs_sign_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("failure_needs_sign_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    videoId,
    videoUrl,
    title,
    channel,
    durationSeconds,
    thumbnail,
    viewCount,
    qualityId,
    qualityKind,
    qualityLabel,
    qualityResolution,
    qualitySize,
    qualityIsAac,
    status,
    section,
    position,
    downloadedBytes,
    totalBytes,
    filePath,
    fileSizeBytes,
    thumbnailPath,
    completedAt,
    failureMessage,
    failureNeedsSignIn,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTasksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_videoUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail')) {
      context.handle(
        _thumbnailMeta,
        thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta),
      );
    }
    if (data.containsKey('view_count')) {
      context.handle(
        _viewCountMeta,
        viewCount.isAcceptableOrUnknown(data['view_count']!, _viewCountMeta),
      );
    }
    if (data.containsKey('quality_id')) {
      context.handle(
        _qualityIdMeta,
        qualityId.isAcceptableOrUnknown(data['quality_id']!, _qualityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityIdMeta);
    }
    if (data.containsKey('quality_label')) {
      context.handle(
        _qualityLabelMeta,
        qualityLabel.isAcceptableOrUnknown(
          data['quality_label']!,
          _qualityLabelMeta,
        ),
      );
    }
    if (data.containsKey('quality_resolution')) {
      context.handle(
        _qualityResolutionMeta,
        qualityResolution.isAcceptableOrUnknown(
          data['quality_resolution']!,
          _qualityResolutionMeta,
        ),
      );
    }
    if (data.containsKey('quality_size')) {
      context.handle(
        _qualitySizeMeta,
        qualitySize.isAcceptableOrUnknown(
          data['quality_size']!,
          _qualitySizeMeta,
        ),
      );
    }
    if (data.containsKey('quality_is_aac')) {
      context.handle(
        _qualityIsAacMeta,
        qualityIsAac.isAcceptableOrUnknown(
          data['quality_is_aac']!,
          _qualityIsAacMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('failure_message')) {
      context.handle(
        _failureMessageMeta,
        failureMessage.isAcceptableOrUnknown(
          data['failure_message']!,
          _failureMessageMeta,
        ),
      );
    }
    if (data.containsKey('failure_needs_sign_in')) {
      context.handle(
        _failureNeedsSignInMeta,
        failureNeedsSignIn.isAcceptableOrUnknown(
          data['failure_needs_sign_in']!,
          _failureNeedsSignInMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTasksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTasksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      ),
      thumbnail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail'],
      ),
      viewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_count'],
      ),
      qualityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_id'],
      )!,
      qualityKind: $DownloadTasksTableTable.$converterqualityKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quality_kind'],
        )!,
      ),
      qualityLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_label'],
      )!,
      qualityResolution: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality_resolution'],
      ),
      qualitySize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality_size'],
      ),
      qualityIsAac: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quality_is_aac'],
      )!,
      status: $DownloadTasksTableTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      section: $DownloadTasksTableTable.$convertersection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}section'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      failureMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_message'],
      ),
      failureNeedsSignIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}failure_needs_sign_in'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadTasksTableTable createAlias(String alias) {
    return $DownloadTasksTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<QualityKind, String, String> $converterqualityKind =
      const EnumNameConverter<QualityKind>(QualityKind.values);
  static JsonTypeConverter2<DownloadTaskStatus, String, String>
  $converterstatus = const EnumNameConverter<DownloadTaskStatus>(
    DownloadTaskStatus.values,
  );
  static JsonTypeConverter2<DownloadTaskSection, String, String>
  $convertersection = const EnumNameConverter<DownloadTaskSection>(
    DownloadTaskSection.values,
  );
}

class DownloadTasksTableData extends DataClass
    implements Insertable<DownloadTasksTableData> {
  final String id;
  final String videoId;
  final String videoUrl;
  final String title;
  final String? channel;
  final double? durationSeconds;
  final String? thumbnail;
  final int? viewCount;
  final String qualityId;
  final QualityKind qualityKind;
  final String qualityLabel;
  final int? qualityResolution;

  /// Approximate file size from the quality list
  final int? qualitySize;
  final bool qualityIsAac;
  final DownloadTaskStatus status;
  final DownloadTaskSection section;
  final int position;

  /// Downloaded bytes as of the last save. On app launch it is checked
  /// against the length of the unfinished files
  final int downloadedBytes;
  final int? totalBytes;
  final String? filePath;

  /// Size of the finished file in bytes
  final int? fileSizeBytes;

  /// Local copy of the thumbnail in the app folder
  final String? thumbnailPath;
  final DateTime? completedAt;
  final String? failureMessage;
  final bool failureNeedsSignIn;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DownloadTasksTableData({
    required this.id,
    required this.videoId,
    required this.videoUrl,
    required this.title,
    this.channel,
    this.durationSeconds,
    this.thumbnail,
    this.viewCount,
    required this.qualityId,
    required this.qualityKind,
    required this.qualityLabel,
    this.qualityResolution,
    this.qualitySize,
    required this.qualityIsAac,
    required this.status,
    required this.section,
    required this.position,
    required this.downloadedBytes,
    this.totalBytes,
    this.filePath,
    this.fileSizeBytes,
    this.thumbnailPath,
    this.completedAt,
    this.failureMessage,
    required this.failureNeedsSignIn,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['video_id'] = Variable<String>(videoId);
    map['video_url'] = Variable<String>(videoUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || channel != null) {
      map['channel'] = Variable<String>(channel);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<String>(thumbnail);
    }
    if (!nullToAbsent || viewCount != null) {
      map['view_count'] = Variable<int>(viewCount);
    }
    map['quality_id'] = Variable<String>(qualityId);
    {
      map['quality_kind'] = Variable<String>(
        $DownloadTasksTableTable.$converterqualityKind.toSql(qualityKind),
      );
    }
    map['quality_label'] = Variable<String>(qualityLabel);
    if (!nullToAbsent || qualityResolution != null) {
      map['quality_resolution'] = Variable<int>(qualityResolution);
    }
    if (!nullToAbsent || qualitySize != null) {
      map['quality_size'] = Variable<int>(qualitySize);
    }
    map['quality_is_aac'] = Variable<bool>(qualityIsAac);
    {
      map['status'] = Variable<String>(
        $DownloadTasksTableTable.$converterstatus.toSql(status),
      );
    }
    {
      map['section'] = Variable<String>(
        $DownloadTasksTableTable.$convertersection.toSql(section),
      );
    }
    map['position'] = Variable<int>(position);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || failureMessage != null) {
      map['failure_message'] = Variable<String>(failureMessage);
    }
    map['failure_needs_sign_in'] = Variable<bool>(failureNeedsSignIn);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadTasksTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksTableCompanion(
      id: Value(id),
      videoId: Value(videoId),
      videoUrl: Value(videoUrl),
      title: Value(title),
      channel: channel == null && nullToAbsent
          ? const Value.absent()
          : Value(channel),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      viewCount: viewCount == null && nullToAbsent
          ? const Value.absent()
          : Value(viewCount),
      qualityId: Value(qualityId),
      qualityKind: Value(qualityKind),
      qualityLabel: Value(qualityLabel),
      qualityResolution: qualityResolution == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityResolution),
      qualitySize: qualitySize == null && nullToAbsent
          ? const Value.absent()
          : Value(qualitySize),
      qualityIsAac: Value(qualityIsAac),
      status: Value(status),
      section: Value(section),
      position: Value(position),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      failureMessage: failureMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(failureMessage),
      failureNeedsSignIn: Value(failureNeedsSignIn),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadTasksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTasksTableData(
      id: serializer.fromJson<String>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      videoUrl: serializer.fromJson<String>(json['videoUrl']),
      title: serializer.fromJson<String>(json['title']),
      channel: serializer.fromJson<String?>(json['channel']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      thumbnail: serializer.fromJson<String?>(json['thumbnail']),
      viewCount: serializer.fromJson<int?>(json['viewCount']),
      qualityId: serializer.fromJson<String>(json['qualityId']),
      qualityKind: $DownloadTasksTableTable.$converterqualityKind.fromJson(
        serializer.fromJson<String>(json['qualityKind']),
      ),
      qualityLabel: serializer.fromJson<String>(json['qualityLabel']),
      qualityResolution: serializer.fromJson<int?>(json['qualityResolution']),
      qualitySize: serializer.fromJson<int?>(json['qualitySize']),
      qualityIsAac: serializer.fromJson<bool>(json['qualityIsAac']),
      status: $DownloadTasksTableTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      section: $DownloadTasksTableTable.$convertersection.fromJson(
        serializer.fromJson<String>(json['section']),
      ),
      position: serializer.fromJson<int>(json['position']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      failureMessage: serializer.fromJson<String?>(json['failureMessage']),
      failureNeedsSignIn: serializer.fromJson<bool>(json['failureNeedsSignIn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'videoId': serializer.toJson<String>(videoId),
      'videoUrl': serializer.toJson<String>(videoUrl),
      'title': serializer.toJson<String>(title),
      'channel': serializer.toJson<String?>(channel),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'thumbnail': serializer.toJson<String?>(thumbnail),
      'viewCount': serializer.toJson<int?>(viewCount),
      'qualityId': serializer.toJson<String>(qualityId),
      'qualityKind': serializer.toJson<String>(
        $DownloadTasksTableTable.$converterqualityKind.toJson(qualityKind),
      ),
      'qualityLabel': serializer.toJson<String>(qualityLabel),
      'qualityResolution': serializer.toJson<int?>(qualityResolution),
      'qualitySize': serializer.toJson<int?>(qualitySize),
      'qualityIsAac': serializer.toJson<bool>(qualityIsAac),
      'status': serializer.toJson<String>(
        $DownloadTasksTableTable.$converterstatus.toJson(status),
      ),
      'section': serializer.toJson<String>(
        $DownloadTasksTableTable.$convertersection.toJson(section),
      ),
      'position': serializer.toJson<int>(position),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'filePath': serializer.toJson<String?>(filePath),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'failureMessage': serializer.toJson<String?>(failureMessage),
      'failureNeedsSignIn': serializer.toJson<bool>(failureNeedsSignIn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadTasksTableData copyWith({
    String? id,
    String? videoId,
    String? videoUrl,
    String? title,
    Value<String?> channel = const Value.absent(),
    Value<double?> durationSeconds = const Value.absent(),
    Value<String?> thumbnail = const Value.absent(),
    Value<int?> viewCount = const Value.absent(),
    String? qualityId,
    QualityKind? qualityKind,
    String? qualityLabel,
    Value<int?> qualityResolution = const Value.absent(),
    Value<int?> qualitySize = const Value.absent(),
    bool? qualityIsAac,
    DownloadTaskStatus? status,
    DownloadTaskSection? section,
    int? position,
    int? downloadedBytes,
    Value<int?> totalBytes = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<int?> fileSizeBytes = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> failureMessage = const Value.absent(),
    bool? failureNeedsSignIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DownloadTasksTableData(
    id: id ?? this.id,
    videoId: videoId ?? this.videoId,
    videoUrl: videoUrl ?? this.videoUrl,
    title: title ?? this.title,
    channel: channel.present ? channel.value : this.channel,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
    viewCount: viewCount.present ? viewCount.value : this.viewCount,
    qualityId: qualityId ?? this.qualityId,
    qualityKind: qualityKind ?? this.qualityKind,
    qualityLabel: qualityLabel ?? this.qualityLabel,
    qualityResolution: qualityResolution.present
        ? qualityResolution.value
        : this.qualityResolution,
    qualitySize: qualitySize.present ? qualitySize.value : this.qualitySize,
    qualityIsAac: qualityIsAac ?? this.qualityIsAac,
    status: status ?? this.status,
    section: section ?? this.section,
    position: position ?? this.position,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    failureMessage: failureMessage.present
        ? failureMessage.value
        : this.failureMessage,
    failureNeedsSignIn: failureNeedsSignIn ?? this.failureNeedsSignIn,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadTasksTableData copyWithCompanion(DownloadTasksTableCompanion data) {
    return DownloadTasksTableData(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      title: data.title.present ? data.title.value : this.title,
      channel: data.channel.present ? data.channel.value : this.channel,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      viewCount: data.viewCount.present ? data.viewCount.value : this.viewCount,
      qualityId: data.qualityId.present ? data.qualityId.value : this.qualityId,
      qualityKind: data.qualityKind.present
          ? data.qualityKind.value
          : this.qualityKind,
      qualityLabel: data.qualityLabel.present
          ? data.qualityLabel.value
          : this.qualityLabel,
      qualityResolution: data.qualityResolution.present
          ? data.qualityResolution.value
          : this.qualityResolution,
      qualitySize: data.qualitySize.present
          ? data.qualitySize.value
          : this.qualitySize,
      qualityIsAac: data.qualityIsAac.present
          ? data.qualityIsAac.value
          : this.qualityIsAac,
      status: data.status.present ? data.status.value : this.status,
      section: data.section.present ? data.section.value : this.section,
      position: data.position.present ? data.position.value : this.position,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      failureMessage: data.failureMessage.present
          ? data.failureMessage.value
          : this.failureMessage,
      failureNeedsSignIn: data.failureNeedsSignIn.present
          ? data.failureNeedsSignIn.value
          : this.failureNeedsSignIn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksTableData(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('title: $title, ')
          ..write('channel: $channel, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('viewCount: $viewCount, ')
          ..write('qualityId: $qualityId, ')
          ..write('qualityKind: $qualityKind, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('qualityResolution: $qualityResolution, ')
          ..write('qualitySize: $qualitySize, ')
          ..write('qualityIsAac: $qualityIsAac, ')
          ..write('status: $status, ')
          ..write('section: $section, ')
          ..write('position: $position, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('completedAt: $completedAt, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('failureNeedsSignIn: $failureNeedsSignIn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    videoId,
    videoUrl,
    title,
    channel,
    durationSeconds,
    thumbnail,
    viewCount,
    qualityId,
    qualityKind,
    qualityLabel,
    qualityResolution,
    qualitySize,
    qualityIsAac,
    status,
    section,
    position,
    downloadedBytes,
    totalBytes,
    filePath,
    fileSizeBytes,
    thumbnailPath,
    completedAt,
    failureMessage,
    failureNeedsSignIn,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTasksTableData &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.videoUrl == this.videoUrl &&
          other.title == this.title &&
          other.channel == this.channel &&
          other.durationSeconds == this.durationSeconds &&
          other.thumbnail == this.thumbnail &&
          other.viewCount == this.viewCount &&
          other.qualityId == this.qualityId &&
          other.qualityKind == this.qualityKind &&
          other.qualityLabel == this.qualityLabel &&
          other.qualityResolution == this.qualityResolution &&
          other.qualitySize == this.qualitySize &&
          other.qualityIsAac == this.qualityIsAac &&
          other.status == this.status &&
          other.section == this.section &&
          other.position == this.position &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.filePath == this.filePath &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.thumbnailPath == this.thumbnailPath &&
          other.completedAt == this.completedAt &&
          other.failureMessage == this.failureMessage &&
          other.failureNeedsSignIn == this.failureNeedsSignIn &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadTasksTableCompanion
    extends UpdateCompanion<DownloadTasksTableData> {
  final Value<String> id;
  final Value<String> videoId;
  final Value<String> videoUrl;
  final Value<String> title;
  final Value<String?> channel;
  final Value<double?> durationSeconds;
  final Value<String?> thumbnail;
  final Value<int?> viewCount;
  final Value<String> qualityId;
  final Value<QualityKind> qualityKind;
  final Value<String> qualityLabel;
  final Value<int?> qualityResolution;
  final Value<int?> qualitySize;
  final Value<bool> qualityIsAac;
  final Value<DownloadTaskStatus> status;
  final Value<DownloadTaskSection> section;
  final Value<int> position;
  final Value<int> downloadedBytes;
  final Value<int?> totalBytes;
  final Value<String?> filePath;
  final Value<int?> fileSizeBytes;
  final Value<String?> thumbnailPath;
  final Value<DateTime?> completedAt;
  final Value<String?> failureMessage;
  final Value<bool> failureNeedsSignIn;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadTasksTableCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.channel = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.viewCount = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.qualityKind = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.qualityResolution = const Value.absent(),
    this.qualitySize = const Value.absent(),
    this.qualityIsAac = const Value.absent(),
    this.status = const Value.absent(),
    this.section = const Value.absent(),
    this.position = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.failureNeedsSignIn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksTableCompanion.insert({
    required String id,
    required String videoId,
    required String videoUrl,
    required String title,
    this.channel = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.viewCount = const Value.absent(),
    required String qualityId,
    required QualityKind qualityKind,
    this.qualityLabel = const Value.absent(),
    this.qualityResolution = const Value.absent(),
    this.qualitySize = const Value.absent(),
    this.qualityIsAac = const Value.absent(),
    required DownloadTaskStatus status,
    required DownloadTaskSection section,
    this.position = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.failureMessage = const Value.absent(),
    this.failureNeedsSignIn = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       videoId = Value(videoId),
       videoUrl = Value(videoUrl),
       title = Value(title),
       qualityId = Value(qualityId),
       qualityKind = Value(qualityKind),
       status = Value(status),
       section = Value(section),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadTasksTableData> custom({
    Expression<String>? id,
    Expression<String>? videoId,
    Expression<String>? videoUrl,
    Expression<String>? title,
    Expression<String>? channel,
    Expression<double>? durationSeconds,
    Expression<String>? thumbnail,
    Expression<int>? viewCount,
    Expression<String>? qualityId,
    Expression<String>? qualityKind,
    Expression<String>? qualityLabel,
    Expression<int>? qualityResolution,
    Expression<int>? qualitySize,
    Expression<bool>? qualityIsAac,
    Expression<String>? status,
    Expression<String>? section,
    Expression<int>? position,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<String>? filePath,
    Expression<int>? fileSizeBytes,
    Expression<String>? thumbnailPath,
    Expression<DateTime>? completedAt,
    Expression<String>? failureMessage,
    Expression<bool>? failureNeedsSignIn,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (videoUrl != null) 'video_url': videoUrl,
      if (title != null) 'title': title,
      if (channel != null) 'channel': channel,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (viewCount != null) 'view_count': viewCount,
      if (qualityId != null) 'quality_id': qualityId,
      if (qualityKind != null) 'quality_kind': qualityKind,
      if (qualityLabel != null) 'quality_label': qualityLabel,
      if (qualityResolution != null) 'quality_resolution': qualityResolution,
      if (qualitySize != null) 'quality_size': qualitySize,
      if (qualityIsAac != null) 'quality_is_aac': qualityIsAac,
      if (status != null) 'status': status,
      if (section != null) 'section': section,
      if (position != null) 'position': position,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (filePath != null) 'file_path': filePath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (completedAt != null) 'completed_at': completedAt,
      if (failureMessage != null) 'failure_message': failureMessage,
      if (failureNeedsSignIn != null)
        'failure_needs_sign_in': failureNeedsSignIn,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? videoId,
    Value<String>? videoUrl,
    Value<String>? title,
    Value<String?>? channel,
    Value<double?>? durationSeconds,
    Value<String?>? thumbnail,
    Value<int?>? viewCount,
    Value<String>? qualityId,
    Value<QualityKind>? qualityKind,
    Value<String>? qualityLabel,
    Value<int?>? qualityResolution,
    Value<int?>? qualitySize,
    Value<bool>? qualityIsAac,
    Value<DownloadTaskStatus>? status,
    Value<DownloadTaskSection>? section,
    Value<int>? position,
    Value<int>? downloadedBytes,
    Value<int?>? totalBytes,
    Value<String?>? filePath,
    Value<int?>? fileSizeBytes,
    Value<String?>? thumbnailPath,
    Value<DateTime?>? completedAt,
    Value<String?>? failureMessage,
    Value<bool>? failureNeedsSignIn,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksTableCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      videoUrl: videoUrl ?? this.videoUrl,
      title: title ?? this.title,
      channel: channel ?? this.channel,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnail: thumbnail ?? this.thumbnail,
      viewCount: viewCount ?? this.viewCount,
      qualityId: qualityId ?? this.qualityId,
      qualityKind: qualityKind ?? this.qualityKind,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      qualityResolution: qualityResolution ?? this.qualityResolution,
      qualitySize: qualitySize ?? this.qualitySize,
      qualityIsAac: qualityIsAac ?? this.qualityIsAac,
      status: status ?? this.status,
      section: section ?? this.section,
      position: position ?? this.position,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      completedAt: completedAt ?? this.completedAt,
      failureMessage: failureMessage ?? this.failureMessage,
      failureNeedsSignIn: failureNeedsSignIn ?? this.failureNeedsSignIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<String>(thumbnail.value);
    }
    if (viewCount.present) {
      map['view_count'] = Variable<int>(viewCount.value);
    }
    if (qualityId.present) {
      map['quality_id'] = Variable<String>(qualityId.value);
    }
    if (qualityKind.present) {
      map['quality_kind'] = Variable<String>(
        $DownloadTasksTableTable.$converterqualityKind.toSql(qualityKind.value),
      );
    }
    if (qualityLabel.present) {
      map['quality_label'] = Variable<String>(qualityLabel.value);
    }
    if (qualityResolution.present) {
      map['quality_resolution'] = Variable<int>(qualityResolution.value);
    }
    if (qualitySize.present) {
      map['quality_size'] = Variable<int>(qualitySize.value);
    }
    if (qualityIsAac.present) {
      map['quality_is_aac'] = Variable<bool>(qualityIsAac.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $DownloadTasksTableTable.$converterstatus.toSql(status.value),
      );
    }
    if (section.present) {
      map['section'] = Variable<String>(
        $DownloadTasksTableTable.$convertersection.toSql(section.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (failureMessage.present) {
      map['failure_message'] = Variable<String>(failureMessage.value);
    }
    if (failureNeedsSignIn.present) {
      map['failure_needs_sign_in'] = Variable<bool>(failureNeedsSignIn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksTableCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('title: $title, ')
          ..write('channel: $channel, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('viewCount: $viewCount, ')
          ..write('qualityId: $qualityId, ')
          ..write('qualityKind: $qualityKind, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('qualityResolution: $qualityResolution, ')
          ..write('qualitySize: $qualitySize, ')
          ..write('qualityIsAac: $qualityIsAac, ')
          ..write('status: $status, ')
          ..write('section: $section, ')
          ..write('position: $position, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('completedAt: $completedAt, ')
          ..write('failureMessage: $failureMessage, ')
          ..write('failureNeedsSignIn: $failureNeedsSignIn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTaskStreamsTableTable extends DownloadTaskStreamsTable
    with
        TableInfo<
          $DownloadTaskStreamsTableTable,
          DownloadTaskStreamsTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTaskStreamsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download_tasks_table (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStreamRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadStreamRole>(
        $DownloadTaskStreamsTableTable.$converterrole,
      );
  static const VerificationMeta _itagMeta = const VerificationMeta('itag');
  @override
  late final GeneratedColumn<int> itag = GeneratedColumn<int>(
    'itag',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentLengthMeta = const VerificationMeta(
    'contentLength',
  );
  @override
  late final GeneratedColumn<int> contentLength = GeneratedColumn<int>(
    'content_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, role, itag, contentLength];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_task_streams_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskStreamsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('itag')) {
      context.handle(
        _itagMeta,
        itag.isAcceptableOrUnknown(data['itag']!, _itagMeta),
      );
    } else if (isInserting) {
      context.missing(_itagMeta);
    }
    if (data.containsKey('content_length')) {
      context.handle(
        _contentLengthMeta,
        contentLength.isAcceptableOrUnknown(
          data['content_length']!,
          _contentLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, role};
  @override
  DownloadTaskStreamsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskStreamsTableData(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      role: $DownloadTaskStreamsTableTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      itag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itag'],
      )!,
      contentLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_length'],
      )!,
    );
  }

  @override
  $DownloadTaskStreamsTableTable createAlias(String alias) {
    return $DownloadTaskStreamsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStreamRole, String, String> $converterrole =
      const EnumNameConverter<DownloadStreamRole>(DownloadStreamRole.values);
}

class DownloadTaskStreamsTableData extends DataClass
    implements Insertable<DownloadTaskStreamsTableData> {
  final String taskId;
  final DownloadStreamRole role;
  final int itag;
  final int contentLength;
  const DownloadTaskStreamsTableData({
    required this.taskId,
    required this.role,
    required this.itag,
    required this.contentLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    {
      map['role'] = Variable<String>(
        $DownloadTaskStreamsTableTable.$converterrole.toSql(role),
      );
    }
    map['itag'] = Variable<int>(itag);
    map['content_length'] = Variable<int>(contentLength);
    return map;
  }

  DownloadTaskStreamsTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadTaskStreamsTableCompanion(
      taskId: Value(taskId),
      role: Value(role),
      itag: Value(itag),
      contentLength: Value(contentLength),
    );
  }

  factory DownloadTaskStreamsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskStreamsTableData(
      taskId: serializer.fromJson<String>(json['taskId']),
      role: $DownloadTaskStreamsTableTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      itag: serializer.fromJson<int>(json['itag']),
      contentLength: serializer.fromJson<int>(json['contentLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'role': serializer.toJson<String>(
        $DownloadTaskStreamsTableTable.$converterrole.toJson(role),
      ),
      'itag': serializer.toJson<int>(itag),
      'contentLength': serializer.toJson<int>(contentLength),
    };
  }

  DownloadTaskStreamsTableData copyWith({
    String? taskId,
    DownloadStreamRole? role,
    int? itag,
    int? contentLength,
  }) => DownloadTaskStreamsTableData(
    taskId: taskId ?? this.taskId,
    role: role ?? this.role,
    itag: itag ?? this.itag,
    contentLength: contentLength ?? this.contentLength,
  );
  DownloadTaskStreamsTableData copyWithCompanion(
    DownloadTaskStreamsTableCompanion data,
  ) {
    return DownloadTaskStreamsTableData(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      role: data.role.present ? data.role.value : this.role,
      itag: data.itag.present ? data.itag.value : this.itag,
      contentLength: data.contentLength.present
          ? data.contentLength.value
          : this.contentLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskStreamsTableData(')
          ..write('taskId: $taskId, ')
          ..write('role: $role, ')
          ..write('itag: $itag, ')
          ..write('contentLength: $contentLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, role, itag, contentLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskStreamsTableData &&
          other.taskId == this.taskId &&
          other.role == this.role &&
          other.itag == this.itag &&
          other.contentLength == this.contentLength);
}

class DownloadTaskStreamsTableCompanion
    extends UpdateCompanion<DownloadTaskStreamsTableData> {
  final Value<String> taskId;
  final Value<DownloadStreamRole> role;
  final Value<int> itag;
  final Value<int> contentLength;
  final Value<int> rowid;
  const DownloadTaskStreamsTableCompanion({
    this.taskId = const Value.absent(),
    this.role = const Value.absent(),
    this.itag = const Value.absent(),
    this.contentLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTaskStreamsTableCompanion.insert({
    required String taskId,
    required DownloadStreamRole role,
    required int itag,
    required int contentLength,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       role = Value(role),
       itag = Value(itag),
       contentLength = Value(contentLength);
  static Insertable<DownloadTaskStreamsTableData> custom({
    Expression<String>? taskId,
    Expression<String>? role,
    Expression<int>? itag,
    Expression<int>? contentLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (role != null) 'role': role,
      if (itag != null) 'itag': itag,
      if (contentLength != null) 'content_length': contentLength,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTaskStreamsTableCompanion copyWith({
    Value<String>? taskId,
    Value<DownloadStreamRole>? role,
    Value<int>? itag,
    Value<int>? contentLength,
    Value<int>? rowid,
  }) {
    return DownloadTaskStreamsTableCompanion(
      taskId: taskId ?? this.taskId,
      role: role ?? this.role,
      itag: itag ?? this.itag,
      contentLength: contentLength ?? this.contentLength,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $DownloadTaskStreamsTableTable.$converterrole.toSql(role.value),
      );
    }
    if (itag.present) {
      map['itag'] = Variable<int>(itag.value);
    }
    if (contentLength.present) {
      map['content_length'] = Variable<int>(contentLength.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskStreamsTableCompanion(')
          ..write('taskId: $taskId, ')
          ..write('role: $role, ')
          ..write('itag: $itag, ')
          ..write('contentLength: $contentLength, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadTasksTableTable downloadTasksTable =
      $DownloadTasksTableTable(this);
  late final $DownloadTaskStreamsTableTable downloadTaskStreamsTable =
      $DownloadTaskStreamsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadTasksTable,
    downloadTaskStreamsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'download_tasks_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('download_task_streams_table', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$DownloadTasksTableTableCreateCompanionBuilder =
    DownloadTasksTableCompanion Function({
      required String id,
      required String videoId,
      required String videoUrl,
      required String title,
      Value<String?> channel,
      Value<double?> durationSeconds,
      Value<String?> thumbnail,
      Value<int?> viewCount,
      required String qualityId,
      required QualityKind qualityKind,
      Value<String> qualityLabel,
      Value<int?> qualityResolution,
      Value<int?> qualitySize,
      Value<bool> qualityIsAac,
      required DownloadTaskStatus status,
      required DownloadTaskSection section,
      Value<int> position,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<String?> filePath,
      Value<int?> fileSizeBytes,
      Value<String?> thumbnailPath,
      Value<DateTime?> completedAt,
      Value<String?> failureMessage,
      Value<bool> failureNeedsSignIn,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableTableUpdateCompanionBuilder =
    DownloadTasksTableCompanion Function({
      Value<String> id,
      Value<String> videoId,
      Value<String> videoUrl,
      Value<String> title,
      Value<String?> channel,
      Value<double?> durationSeconds,
      Value<String?> thumbnail,
      Value<int?> viewCount,
      Value<String> qualityId,
      Value<QualityKind> qualityKind,
      Value<String> qualityLabel,
      Value<int?> qualityResolution,
      Value<int?> qualitySize,
      Value<bool> qualityIsAac,
      Value<DownloadTaskStatus> status,
      Value<DownloadTaskSection> section,
      Value<int> position,
      Value<int> downloadedBytes,
      Value<int?> totalBytes,
      Value<String?> filePath,
      Value<int?> fileSizeBytes,
      Value<String?> thumbnailPath,
      Value<DateTime?> completedAt,
      Value<String?> failureMessage,
      Value<bool> failureNeedsSignIn,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DownloadTasksTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadTasksTableTable,
          DownloadTasksTableData
        > {
  $$DownloadTasksTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $DownloadTaskStreamsTableTable,
    List<DownloadTaskStreamsTableData>
  >
  _downloadTaskStreamsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.downloadTaskStreamsTable,
        aliasName:
            'download_tasks_table__id__download_task_streams_table__task_id',
      );

  $$DownloadTaskStreamsTableTableProcessedTableManager
  get downloadTaskStreamsTableRefs {
    final manager = $$DownloadTaskStreamsTableTableTableManager(
      $_db,
      $_db.downloadTaskStreamsTable,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _downloadTaskStreamsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadTasksTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTableTable> {
  $$DownloadTasksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<QualityKind, QualityKind, String>
  get qualityKind => $composableBuilder(
    column: $table.qualityKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qualityResolution => $composableBuilder(
    column: $table.qualityResolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qualitySize => $composableBuilder(
    column: $table.qualitySize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get qualityIsAac => $composableBuilder(
    column: $table.qualityIsAac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadTaskStatus, DownloadTaskStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DownloadTaskSection,
    DownloadTaskSection,
    String
  >
  get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get failureNeedsSignIn => $composableBuilder(
    column: $table.failureNeedsSignIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadTaskStreamsTableRefs(
    Expression<bool> Function($$DownloadTaskStreamsTableTableFilterComposer f)
    f,
  ) {
    final $$DownloadTaskStreamsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.downloadTaskStreamsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadTaskStreamsTableTableFilterComposer(
                $db: $db,
                $table: $db.downloadTaskStreamsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DownloadTasksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTableTable> {
  $$DownloadTasksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityKind => $composableBuilder(
    column: $table.qualityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qualityResolution => $composableBuilder(
    column: $table.qualityResolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qualitySize => $composableBuilder(
    column: $table.qualitySize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get qualityIsAac => $composableBuilder(
    column: $table.qualityIsAac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get failureNeedsSignIn => $composableBuilder(
    column: $table.failureNeedsSignIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTableTable> {
  $$DownloadTasksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<int> get viewCount =>
      $composableBuilder(column: $table.viewCount, builder: (column) => column);

  GeneratedColumn<String> get qualityId =>
      $composableBuilder(column: $table.qualityId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QualityKind, String> get qualityKind =>
      $composableBuilder(
        column: $table.qualityKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qualityResolution => $composableBuilder(
    column: $table.qualityResolution,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qualitySize => $composableBuilder(
    column: $table.qualitySize,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get qualityIsAac => $composableBuilder(
    column: $table.qualityIsAac,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadTaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadTaskSection, String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureMessage => $composableBuilder(
    column: $table.failureMessage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get failureNeedsSignIn => $composableBuilder(
    column: $table.failureNeedsSignIn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> downloadTaskStreamsTableRefs<T extends Object>(
    Expression<T> Function($$DownloadTaskStreamsTableTableAnnotationComposer a)
    f,
  ) {
    final $$DownloadTaskStreamsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.downloadTaskStreamsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadTaskStreamsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.downloadTaskStreamsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DownloadTasksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTableTable,
          DownloadTasksTableData,
          $$DownloadTasksTableTableFilterComposer,
          $$DownloadTasksTableTableOrderingComposer,
          $$DownloadTasksTableTableAnnotationComposer,
          $$DownloadTasksTableTableCreateCompanionBuilder,
          $$DownloadTasksTableTableUpdateCompanionBuilder,
          (DownloadTasksTableData, $$DownloadTasksTableTableReferences),
          DownloadTasksTableData,
          PrefetchHooks Function({bool downloadTaskStreamsTableRefs})
        > {
  $$DownloadTasksTableTableTableManager(
    _$AppDatabase db,
    $DownloadTasksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> videoUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<String?> thumbnail = const Value.absent(),
                Value<int?> viewCount = const Value.absent(),
                Value<String> qualityId = const Value.absent(),
                Value<QualityKind> qualityKind = const Value.absent(),
                Value<String> qualityLabel = const Value.absent(),
                Value<int?> qualityResolution = const Value.absent(),
                Value<int?> qualitySize = const Value.absent(),
                Value<bool> qualityIsAac = const Value.absent(),
                Value<DownloadTaskStatus> status = const Value.absent(),
                Value<DownloadTaskSection> section = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<bool> failureNeedsSignIn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksTableCompanion(
                id: id,
                videoId: videoId,
                videoUrl: videoUrl,
                title: title,
                channel: channel,
                durationSeconds: durationSeconds,
                thumbnail: thumbnail,
                viewCount: viewCount,
                qualityId: qualityId,
                qualityKind: qualityKind,
                qualityLabel: qualityLabel,
                qualityResolution: qualityResolution,
                qualitySize: qualitySize,
                qualityIsAac: qualityIsAac,
                status: status,
                section: section,
                position: position,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                filePath: filePath,
                fileSizeBytes: fileSizeBytes,
                thumbnailPath: thumbnailPath,
                completedAt: completedAt,
                failureMessage: failureMessage,
                failureNeedsSignIn: failureNeedsSignIn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String videoId,
                required String videoUrl,
                required String title,
                Value<String?> channel = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<String?> thumbnail = const Value.absent(),
                Value<int?> viewCount = const Value.absent(),
                required String qualityId,
                required QualityKind qualityKind,
                Value<String> qualityLabel = const Value.absent(),
                Value<int?> qualityResolution = const Value.absent(),
                Value<int?> qualitySize = const Value.absent(),
                Value<bool> qualityIsAac = const Value.absent(),
                required DownloadTaskStatus status,
                required DownloadTaskSection section,
                Value<int> position = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int?> fileSizeBytes = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> failureMessage = const Value.absent(),
                Value<bool> failureNeedsSignIn = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksTableCompanion.insert(
                id: id,
                videoId: videoId,
                videoUrl: videoUrl,
                title: title,
                channel: channel,
                durationSeconds: durationSeconds,
                thumbnail: thumbnail,
                viewCount: viewCount,
                qualityId: qualityId,
                qualityKind: qualityKind,
                qualityLabel: qualityLabel,
                qualityResolution: qualityResolution,
                qualitySize: qualitySize,
                qualityIsAac: qualityIsAac,
                status: status,
                section: section,
                position: position,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                filePath: filePath,
                fileSizeBytes: fileSizeBytes,
                thumbnailPath: thumbnailPath,
                completedAt: completedAt,
                failureMessage: failureMessage,
                failureNeedsSignIn: failureNeedsSignIn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadTasksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadTaskStreamsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (downloadTaskStreamsTableRefs) db.downloadTaskStreamsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (downloadTaskStreamsTableRefs)
                    await $_getPrefetchedData<
                      DownloadTasksTableData,
                      $DownloadTasksTableTable,
                      DownloadTaskStreamsTableData
                    >(
                      currentTable: table,
                      referencedTable: $$DownloadTasksTableTableReferences
                          ._downloadTaskStreamsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DownloadTasksTableTableReferences(
                            db,
                            table,
                            p0,
                          ).downloadTaskStreamsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DownloadTasksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTableTable,
      DownloadTasksTableData,
      $$DownloadTasksTableTableFilterComposer,
      $$DownloadTasksTableTableOrderingComposer,
      $$DownloadTasksTableTableAnnotationComposer,
      $$DownloadTasksTableTableCreateCompanionBuilder,
      $$DownloadTasksTableTableUpdateCompanionBuilder,
      (DownloadTasksTableData, $$DownloadTasksTableTableReferences),
      DownloadTasksTableData,
      PrefetchHooks Function({bool downloadTaskStreamsTableRefs})
    >;
typedef $$DownloadTaskStreamsTableTableCreateCompanionBuilder =
    DownloadTaskStreamsTableCompanion Function({
      required String taskId,
      required DownloadStreamRole role,
      required int itag,
      required int contentLength,
      Value<int> rowid,
    });
typedef $$DownloadTaskStreamsTableTableUpdateCompanionBuilder =
    DownloadTaskStreamsTableCompanion Function({
      Value<String> taskId,
      Value<DownloadStreamRole> role,
      Value<int> itag,
      Value<int> contentLength,
      Value<int> rowid,
    });

final class $$DownloadTaskStreamsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadTaskStreamsTableTable,
          DownloadTaskStreamsTableData
        > {
  $$DownloadTaskStreamsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadTasksTableTable _taskIdTable(_$AppDatabase db) =>
      db.downloadTasksTable.createAlias(
        'download_task_streams_table__task_id__download_tasks_table__id',
      );

  $$DownloadTasksTableTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$DownloadTasksTableTableTableManager(
      $_db,
      $_db.downloadTasksTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadTaskStreamsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTaskStreamsTableTable> {
  $$DownloadTaskStreamsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DownloadStreamRole, DownloadStreamRole, String>
  get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get itag => $composableBuilder(
    column: $table.itag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadTasksTableTableFilterComposer get taskId {
    final $$DownloadTasksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableTableFilterComposer(
            $db: $db,
            $table: $db.downloadTasksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadTaskStreamsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTaskStreamsTableTable> {
  $$DownloadTaskStreamsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itag => $composableBuilder(
    column: $table.itag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadTasksTableTableOrderingComposer get taskId {
    final $$DownloadTasksTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.downloadTasksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableTableOrderingComposer(
            $db: $db,
            $table: $db.downloadTasksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadTaskStreamsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTaskStreamsTableTable> {
  $$DownloadTaskStreamsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DownloadStreamRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get itag =>
      $composableBuilder(column: $table.itag, builder: (column) => column);

  GeneratedColumn<int> get contentLength => $composableBuilder(
    column: $table.contentLength,
    builder: (column) => column,
  );

  $$DownloadTasksTableTableAnnotationComposer get taskId {
    final $$DownloadTasksTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.downloadTasksTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DownloadTasksTableTableAnnotationComposer(
                $db: $db,
                $table: $db.downloadTasksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DownloadTaskStreamsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTaskStreamsTableTable,
          DownloadTaskStreamsTableData,
          $$DownloadTaskStreamsTableTableFilterComposer,
          $$DownloadTaskStreamsTableTableOrderingComposer,
          $$DownloadTaskStreamsTableTableAnnotationComposer,
          $$DownloadTaskStreamsTableTableCreateCompanionBuilder,
          $$DownloadTaskStreamsTableTableUpdateCompanionBuilder,
          (
            DownloadTaskStreamsTableData,
            $$DownloadTaskStreamsTableTableReferences,
          ),
          DownloadTaskStreamsTableData,
          PrefetchHooks Function({bool taskId})
        > {
  $$DownloadTaskStreamsTableTableTableManager(
    _$AppDatabase db,
    $DownloadTaskStreamsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTaskStreamsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadTaskStreamsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadTaskStreamsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<DownloadStreamRole> role = const Value.absent(),
                Value<int> itag = const Value.absent(),
                Value<int> contentLength = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTaskStreamsTableCompanion(
                taskId: taskId,
                role: role,
                itag: itag,
                contentLength: contentLength,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required DownloadStreamRole role,
                required int itag,
                required int contentLength,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTaskStreamsTableCompanion.insert(
                taskId: taskId,
                role: role,
                itag: itag,
                contentLength: contentLength,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadTaskStreamsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$DownloadTaskStreamsTableTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$DownloadTaskStreamsTableTableReferences
                                        ._taskIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadTaskStreamsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTaskStreamsTableTable,
      DownloadTaskStreamsTableData,
      $$DownloadTaskStreamsTableTableFilterComposer,
      $$DownloadTaskStreamsTableTableOrderingComposer,
      $$DownloadTaskStreamsTableTableAnnotationComposer,
      $$DownloadTaskStreamsTableTableCreateCompanionBuilder,
      $$DownloadTaskStreamsTableTableUpdateCompanionBuilder,
      (DownloadTaskStreamsTableData, $$DownloadTaskStreamsTableTableReferences),
      DownloadTaskStreamsTableData,
      PrefetchHooks Function({bool taskId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadTasksTableTableTableManager get downloadTasksTable =>
      $$DownloadTasksTableTableTableManager(_db, _db.downloadTasksTable);
  $$DownloadTaskStreamsTableTableTableManager get downloadTaskStreamsTable =>
      $$DownloadTaskStreamsTableTableTableManager(
        _db,
        _db.downloadTaskStreamsTable,
      );
}
