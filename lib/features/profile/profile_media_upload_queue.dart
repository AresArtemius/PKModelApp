import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../core/media_tools.dart';
import '../../core/supabase_provider.dart';
import 'my_profile_controller.dart';
import 'profile_media_storage.dart';
import 'profile_model.dart';
import 'profile_media_web_upload_cache_stub.dart'
    if (dart.library.html) 'profile_media_web_upload_cache_web.dart';

const String kProfileMediaBucket = 'profile-media';

final profileMediaUploadQueueProvider =
    StateNotifierProvider<
      ProfileMediaUploadQueue,
      List<ProfileMediaUploadTask>
    >((ref) => ProfileMediaUploadQueue(ref));

enum ProfileMediaUploadStatus {
  uploading,
  finalizing,
  paused,
  failed,
  completed,
}

enum ProfileMediaUploadItemKind { photo, video }

enum ProfileMediaUploadItemStatus {
  queued,
  preparing,
  compressing,
  uploading,
  uploaded,
  paused,
  failed,
}

class ProfileMediaUploadItem {
  const ProfileMediaUploadItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.status,
    required this.url,
    required this.previewUrl,
    required this.error,
    required this.isCover,
    required this.isShowreel,
    required this.categoryLabel,
    required this.progress,
    required this.uploadAttempt,
    required this.webStorage,
    required this.webRestored,
    required this.webDiagnostic,
    required this.resumableUploadUrl,
    required this.resumableUploadedBytes,
    this.source,
  });

  final String id;
  final ProfileMediaUploadItemKind kind;
  final String name;
  final String path;
  final String mimeType;
  final ProfileMediaUploadItemStatus status;
  final String url;
  final String previewUrl;
  final String error;
  final bool isCover;
  final bool isShowreel;
  final String categoryLabel;
  final double progress;
  final int uploadAttempt;
  final String webStorage;
  final bool webRestored;
  final String webDiagnostic;
  final String resumableUploadUrl;
  final int resumableUploadedBytes;
  final XFile? source;

  bool get isPhoto => kind == ProfileMediaUploadItemKind.photo;

  bool get isVideo => kind == ProfileMediaUploadItemKind.video;

  bool get isDone => status == ProfileMediaUploadItemStatus.uploaded;

  int get progressPercent => (progress * 100).round().clamp(0, 100);

  bool get canUpload =>
      status == ProfileMediaUploadItemStatus.queued ||
      status == ProfileMediaUploadItemStatus.paused ||
      status == ProfileMediaUploadItemStatus.failed;

  XFile toXFile() {
    final existing = source;
    if (existing != null) return existing;
    return XFile(
      path,
      name: name,
      mimeType: mimeType.isEmpty ? null : mimeType,
    );
  }

  ProfileMediaUploadItem copyWith({
    ProfileMediaUploadItemStatus? status,
    String? path,
    String? url,
    String? previewUrl,
    String? error,
    bool? isShowreel,
    String? categoryLabel,
    double? progress,
    int? uploadAttempt,
    String? webStorage,
    bool? webRestored,
    String? webDiagnostic,
    String? resumableUploadUrl,
    int? resumableUploadedBytes,
    XFile? source,
  }) {
    return ProfileMediaUploadItem(
      id: id,
      kind: kind,
      name: name,
      path: path ?? this.path,
      mimeType: mimeType,
      status: status ?? this.status,
      url: url ?? this.url,
      previewUrl: previewUrl ?? this.previewUrl,
      error: error ?? this.error,
      isCover: isCover,
      isShowreel: isShowreel ?? this.isShowreel,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      progress: progress ?? this.progress,
      uploadAttempt: uploadAttempt ?? this.uploadAttempt,
      webStorage: webStorage ?? this.webStorage,
      webRestored: webRestored ?? this.webRestored,
      webDiagnostic: webDiagnostic ?? this.webDiagnostic,
      resumableUploadUrl: resumableUploadUrl ?? this.resumableUploadUrl,
      resumableUploadedBytes:
          resumableUploadedBytes ?? this.resumableUploadedBytes,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'path': path,
    'mimeType': mimeType,
    'status': status.name,
    'url': url,
    'previewUrl': previewUrl,
    'error': error,
    'isCover': isCover,
    'isShowreel': isShowreel,
    'categoryLabel': categoryLabel,
    'progress': progress,
    'uploadAttempt': uploadAttempt,
    'webStorage': webStorage,
    'webRestored': webRestored,
    'webDiagnostic': webDiagnostic,
    'resumableUploadUrl': resumableUploadUrl,
    'resumableUploadedBytes': resumableUploadedBytes,
  };

  static ProfileMediaUploadItem fromJson(Map<String, dynamic> json) {
    final kindName = (json['kind'] ?? '').toString();
    final statusName = (json['status'] ?? '').toString();
    return ProfileMediaUploadItem(
      id: (json['id'] ?? '').toString(),
      kind: ProfileMediaUploadItemKind.values.firstWhere(
        (e) => e.name == kindName,
        orElse: () => ProfileMediaUploadItemKind.photo,
      ),
      name: (json['name'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      status: ProfileMediaUploadItemStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => ProfileMediaUploadItemStatus.queued,
      ),
      url: (json['url'] ?? '').toString(),
      previewUrl: (json['previewUrl'] ?? '').toString(),
      error: (json['error'] ?? '').toString(),
      isCover: json['isCover'] == true,
      isShowreel: json['isShowreel'] == true,
      categoryLabel: (json['categoryLabel'] ?? '').toString(),
      progress: (json['progress'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0,
      uploadAttempt: (json['uploadAttempt'] as num?)?.toInt() ?? 0,
      webStorage: (json['webStorage'] ?? '').toString(),
      webRestored: json['webRestored'] == true,
      webDiagnostic: (json['webDiagnostic'] ?? '').toString(),
      resumableUploadUrl: (json['resumableUploadUrl'] ?? '').toString(),
      resumableUploadedBytes:
          (json['resumableUploadedBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileMediaUploadTask {
  const ProfileMediaUploadTask({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.uid,
    required this.items,
    required this.approveImmediately,
    required this.status,
    required this.error,
    required this.createdAt,
    required this.paused,
    this.profile,
  });

  final String id;
  final String profileId;
  final String profileName;
  final String uid;
  final MyProfileState? profile;
  final List<ProfileMediaUploadItem> items;
  final bool approveImmediately;
  final ProfileMediaUploadStatus status;
  final String error;
  final DateTime createdAt;
  final bool paused;

  int get photoCount => items.where((e) => e.isPhoto).length;

  int get videoCount => items.where((e) => e.isVideo).length;

  int get completedCount => items.where((e) => e.isDone).length;

  int get failedCount => items
      .where((e) => e.status == ProfileMediaUploadItemStatus.failed)
      .length;

  int get totalCount => items.length;

  bool get hasMedia => items.isNotEmpty;

  bool get canPause =>
      status == ProfileMediaUploadStatus.uploading &&
      completedCount < totalCount;

  bool get canResume =>
      status == ProfileMediaUploadStatus.paused ||
      status == ProfileMediaUploadStatus.failed;

  double get progress {
    if (totalCount == 0) return 1;
    final sum = items.fold<double>(
      0,
      (total, item) =>
          total + (item.isDone ? 1 : item.progress.clamp(0.0, 1.0)),
    );
    return (sum / totalCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round().clamp(0, 100);

  ProfileMediaUploadTask copyWith({
    ProfileMediaUploadStatus? status,
    String? error,
    MyProfileState? profile,
    List<ProfileMediaUploadItem>? items,
    bool? paused,
  }) {
    return ProfileMediaUploadTask(
      id: id,
      profileId: profileId,
      profileName: profileName,
      uid: uid,
      profile: profile ?? this.profile,
      items: items ?? this.items,
      approveImmediately: approveImmediately,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
      paused: paused ?? this.paused,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'profileName': profileName,
    'uid': uid,
    'items': items.map((e) => e.toJson()).toList(),
    'approveImmediately': approveImmediately,
    'status': status.name,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
    'paused': paused,
  };

  static ProfileMediaUploadTask fromJson(Map<String, dynamic> json) {
    final statusName = (json['status'] ?? '').toString();
    final rawItems = json['items'];
    return ProfileMediaUploadTask(
      id: (json['id'] ?? '').toString(),
      profileId: (json['profileId'] ?? '').toString(),
      profileName: (json['profileName'] ?? '').toString(),
      uid: (json['uid'] ?? '').toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((e) => ProfileMediaUploadItem.fromJson(Map.from(e)))
                .toList()
          : const <ProfileMediaUploadItem>[],
      approveImmediately: json['approveImmediately'] == true,
      status: ProfileMediaUploadStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => ProfileMediaUploadStatus.failed,
      ),
      error: (json['error'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      paused: json['paused'] == true,
    );
  }
}

class ProfileMediaUploadQueue
    extends StateNotifier<List<ProfileMediaUploadTask>> {
  ProfileMediaUploadQueue(this.ref) : super(const []) {
    unawaited(_restorePersistedQueue());
  }

  static const _storageKey = 'profile_media_upload_queue_v1';

  final Ref ref;
  final Set<String> _activeTasks = <String>{};
  final Map<String, ProfileMediaUploadCancelToken> _cancelTokens =
      <String, ProfileMediaUploadCancelToken>{};

  void enqueue({
    required String uid,
    required MyProfileState profile,
    required List<XFile> pickedPhotos,
    required List<XFile> pickedVideos,
    required int? pickedCoverPhotoIndex,
    required List<String> pickedPhotoCategoryLabels,
    required List<String> pickedVideoCategoryLabels,
    required int? pickedShowreelVideoIndex,
    required bool approveImmediately,
  }) {
    if (pickedPhotos.isEmpty && pickedVideos.isEmpty) return;

    final profileId = profile.id.trim();
    if (profileId.isEmpty) return;

    final now = DateTime.now();
    final taskId = '${profileId}_${now.microsecondsSinceEpoch}';
    final items = <ProfileMediaUploadItem>[
      for (int i = 0; i < pickedPhotos.length; i++)
        _itemFromXFile(
          taskId: taskId,
          index: i,
          kind: ProfileMediaUploadItemKind.photo,
          file: pickedPhotos[i],
          isCover: pickedCoverPhotoIndex == i,
          isShowreel: false,
          categoryLabel: i < pickedPhotoCategoryLabels.length
              ? pickedPhotoCategoryLabels[i]
              : 'Портфолио',
        ),
      for (int i = 0; i < pickedVideos.length; i++)
        _itemFromXFile(
          taskId: taskId,
          index: pickedPhotos.length + i,
          kind: ProfileMediaUploadItemKind.video,
          file: pickedVideos[i],
          isCover: false,
          isShowreel: pickedShowreelVideoIndex == i,
          categoryLabel: i < pickedVideoCategoryLabels.length
              ? pickedVideoCategoryLabels[i]
              : 'Видео',
        ),
    ];

    final task = ProfileMediaUploadTask(
      id: taskId,
      profileId: profileId,
      profileName: profile.fullName.trim(),
      uid: uid,
      profile: profile,
      items: items,
      approveImmediately: approveImmediately,
      status: ProfileMediaUploadStatus.uploading,
      error: '',
      createdAt: now,
      paused: false,
    );

    state = [...state, task];
    _persistQueue();
    unawaited(_persistWebSources(task));
    unawaited(_process(task.id));
  }

  void pause(String taskId) {
    final task = _taskById(taskId);
    if (task == null || !task.canPause) return;
    _cancelTokens[taskId]?.cancel();
    final nextItems = [
      for (final item in task.items)
        item.status == ProfileMediaUploadItemStatus.queued ||
                item.status == ProfileMediaUploadItemStatus.preparing ||
                item.status == ProfileMediaUploadItemStatus.compressing ||
                item.status == ProfileMediaUploadItemStatus.uploading
            ? item.copyWith(status: ProfileMediaUploadItemStatus.paused)
            : item,
    ];
    _replace(
      task.copyWith(
        status: ProfileMediaUploadStatus.paused,
        items: nextItems,
        paused: true,
        error: '',
      ),
    );
    _persistQueue();
  }

  void resume(String taskId) {
    final task = _taskById(taskId);
    if (task == null || !task.canResume) return;
    final nextItems = [
      for (final item in task.items)
        item.status == ProfileMediaUploadItemStatus.paused ||
                item.status == ProfileMediaUploadItemStatus.failed
            ? item.copyWith(
                status: ProfileMediaUploadItemStatus.queued,
                error: '',
                progress: 0,
                uploadAttempt:
                    item.url.trim().isEmpty &&
                        item.resumableUploadUrl.trim().isEmpty
                    ? item.uploadAttempt + 1
                    : item.uploadAttempt,
              )
            : item,
    ];
    _replace(
      task.copyWith(
        status: ProfileMediaUploadStatus.uploading,
        items: nextItems,
        paused: false,
        error: '',
      ),
    );
    _persistQueue();
    unawaited(_process(task.id));
  }

  void retry(String taskId) => resume(taskId);

  void dismiss(String taskId) {
    state = [
      for (final item in state)
        if (item.id != taskId) item,
    ];
    _persistQueue();
    unawaited(ProfileMediaWebUploadCache.deleteTask(taskId));
  }

  ProfileMediaUploadTask? latestForProfile(String profileId) {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    for (final task in state.reversed) {
      if (task.profileId == id) return task;
    }
    return null;
  }

  ProfileMediaUploadItem _itemFromXFile({
    required String taskId,
    required int index,
    required ProfileMediaUploadItemKind kind,
    required XFile file,
    required bool isCover,
    required bool isShowreel,
    required String categoryLabel,
  }) {
    final name = file.name.trim().isNotEmpty
        ? file.name.trim()
        : '${kind.name}_$index';
    return ProfileMediaUploadItem(
      id: '${taskId}_${kind.name}_$index',
      kind: kind,
      name: name,
      path: file.path,
      mimeType: file.mimeType ?? '',
      status: ProfileMediaUploadItemStatus.queued,
      url: '',
      previewUrl: '',
      error: '',
      isCover: isCover,
      isShowreel: isShowreel,
      categoryLabel: categoryLabel.trim(),
      progress: 0,
      uploadAttempt: 0,
      webStorage: '',
      webRestored: false,
      webDiagnostic: kIsWeb ? 'ожидает сохранения в браузере' : '',
      resumableUploadUrl: '',
      resumableUploadedBytes: 0,
      source: file,
    );
  }

  ProfileMediaUploadTask? _taskById(String taskId) {
    for (final task in state) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  void _replace(ProfileMediaUploadTask task) {
    state = [for (final item in state) item.id == task.id ? task : item];
  }

  void _replaceItem(String taskId, ProfileMediaUploadItem nextItem) {
    final task = _taskById(taskId);
    if (task == null) return;
    _replace(
      task.copyWith(
        items: [
          for (final item in task.items)
            item.id == nextItem.id ? nextItem : item,
        ],
      ),
    );
  }

  Future<void> _restorePersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <ProfileMediaUploadTask>[];
      for (final item in decoded.whereType<Map>()) {
        final task = ProfileMediaUploadTask.fromJson(Map.from(item));
        if (task.id.isEmpty || task.items.isEmpty) continue;
        restored.add(await _normalizeRestoredTask(task));
      }
      if (restored.isEmpty) return;
      state = [...state, ...restored];
      for (final task in restored.where(
        (e) => e.status == ProfileMediaUploadStatus.uploading,
      )) {
        unawaited(_process(task.id));
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to restore profile media upload queue',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<ProfileMediaUploadTask> _normalizeRestoredTask(
    ProfileMediaUploadTask task,
  ) async {
    if (kIsWeb) {
      return _restoreWebTaskSources(task);
    }

    final items = [
      for (final item in task.items)
        item.isDone
            ? item
            : item.copyWith(
                status: File(item.path).existsSync()
                    ? ProfileMediaUploadItemStatus.queued
                    : ProfileMediaUploadItemStatus.failed,
                error: File(item.path).existsSync()
                    ? ''
                    : 'Локальный файл недоступен',
              ),
    ];
    final hasFailed = items.any(
      (e) => e.status == ProfileMediaUploadItemStatus.failed,
    );
    return task.copyWith(
      status: hasFailed
          ? ProfileMediaUploadStatus.failed
          : ProfileMediaUploadStatus.uploading,
      items: items,
      paused: false,
      error: hasFailed
          ? 'Часть файлов не удалось восстановить после перезапуска'
          : '',
    );
  }

  Future<ProfileMediaUploadTask> _restoreWebTaskSources(
    ProfileMediaUploadTask task,
  ) async {
    final items = <ProfileMediaUploadItem>[];
    for (final item in task.items) {
      if (item.isDone) {
        items.add(item);
        continue;
      }

      final restored = await ProfileMediaWebUploadCache.restoreItem(
        taskId: task.id,
        itemId: item.id,
        name: item.name,
        mimeType: item.mimeType,
      );
      if (restored == null) {
        items.add(
          item.copyWith(
            status: ProfileMediaUploadItemStatus.failed,
            error:
                'Файл недоступен после перезапуска браузера. Выберите медиа заново.',
            webDiagnostic: 'ошибка восстановления',
          ),
        );
      } else {
        items.add(
          item.copyWith(
            status: ProfileMediaUploadItemStatus.queued,
            error: '',
            progress: 0,
            source: restored.file,
            webStorage: restored.storage,
            webRestored: true,
            webDiagnostic: 'восстановлено после перезапуска',
          ),
        );
      }
    }

    final hasFailed = items.any(
      (e) => e.status == ProfileMediaUploadItemStatus.failed,
    );
    return task.copyWith(
      status: hasFailed
          ? ProfileMediaUploadStatus.failed
          : ProfileMediaUploadStatus.uploading,
      items: items,
      paused: false,
      error: hasFailed
          ? 'Часть файлов не удалось восстановить после перезапуска браузера'
          : '',
    );
  }

  Future<void> _persistWebSources(ProfileMediaUploadTask task) async {
    if (!kIsWeb || !ProfileMediaWebUploadCache.isSupported) return;
    try {
      for (final item in task.items) {
        final source = item.source;
        if (source == null || item.isDone) continue;
        final storage = await ProfileMediaWebUploadCache.saveItem(
          taskId: task.id,
          itemId: item.id,
          source: source,
        );
        final latestTask = _taskById(task.id);
        if (latestTask == null) continue;
        final latestItem = latestTask.items.firstWhere(
          (e) => e.id == item.id,
          orElse: () => item,
        );
        if (storage.trim().isNotEmpty && !latestItem.isDone) {
          _replaceItem(
            task.id,
            latestItem.copyWith(
              webStorage: storage,
              webDiagnostic: 'сохранено в браузере',
            ),
          );
          await _persistQueue();
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to persist web profile media upload sources',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _persistQueue() async {
    try {
      final active = state
          .where((e) => e.status != ProfileMediaUploadStatus.completed)
          .map((e) => e.toJson())
          .toList();
      final prefs = await SharedPreferences.getInstance();
      if (active.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(active));
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to persist profile media upload queue',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<ProfileMediaUploadItem> _ensurePersistentSource(
    ProfileMediaUploadTask task,
    ProfileMediaUploadItem item,
  ) async {
    if (kIsWeb || item.source == null) return item;
    final existingPath = item.path.trim();
    if (existingPath.isNotEmpty &&
        existingPath.contains('/profile_media_uploads/') &&
        File(existingPath).existsSync()) {
      return item;
    }

    final source = item.source!;
    final bytes = await source.readAsBytes();
    final dir = await _uploadCacheDirectory(task.uid);
    final ext = _extensionFromName(
      item.name,
      fallback: item.isVideo ? 'mp4' : 'jpg',
    );
    final file = File('${dir.path}/${item.id}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return item.copyWith(path: file.path, source: XFile(file.path));
  }

  Future<Directory> _uploadCacheDirectory(String uid) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/profile_media_uploads/$uid');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _compressedVideoPath(String uid, String itemId) async {
    final dir = await _uploadCacheDirectory(uid);
    return '${dir.path}/${itemId}_compressed.mp4';
  }

  String _extensionFromName(String name, {required String fallback}) {
    final clean = name.trim().toLowerCase();
    final index = clean.lastIndexOf('.');
    if (index == -1 || index == clean.length - 1) return fallback;
    return clean.substring(index + 1);
  }

  Future<MyProfileState> _profileForTask(ProfileMediaUploadTask task) async {
    for (var i = 0; i < 24; i++) {
      final list = ref.read(myProfileProvider).valueOrNull;
      if (list != null) {
        for (final profile in list) {
          if (profile.id == task.profileId) return profile;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final fallback = task.profile;
    if (fallback != null) return fallback;
    throw StateError('Анкета не найдена для завершения загрузки медиа');
  }

  Future<void> _process(String taskId) async {
    if (_activeTasks.contains(taskId)) return;
    _activeTasks.add(taskId);
    try {
      var task = _taskById(taskId);
      if (task == null) return;
      if (task.status == ProfileMediaUploadStatus.completed) return;

      final storage = ProfileMediaStorage(ref.read(supabaseProvider));
      var uploadedPhotoUrls = <String>[
        for (final item in task.items)
          if (item.isPhoto && item.url.trim().isNotEmpty) item.url.trim(),
      ];
      var uploadedVideoUrls = <String>[
        for (final item in task.items)
          if (item.isVideo && item.url.trim().isNotEmpty) item.url.trim(),
      ];
      var uploadedVideoPreviewUrls = <String>[
        for (final item in task.items)
          if (item.isVideo && item.url.trim().isNotEmpty)
            item.previewUrl.trim(),
      ];
      var uploadedPhotoCategoryLabels = <String>[
        for (final item in task.items)
          if (item.isPhoto && item.url.trim().isNotEmpty)
            item.categoryLabel.trim().isEmpty
                ? 'Портфолио'
                : item.categoryLabel.trim(),
      ];
      var uploadedVideoCategoryLabels = <String>[
        for (final item in task.items)
          if (item.isVideo && item.url.trim().isNotEmpty)
            item.categoryLabel.trim().isEmpty
                ? (item.isShowreel ? 'Showreel' : 'Видео')
                : item.categoryLabel.trim(),
      ];
      var uploadedShowreelUrl = task.items
          .where((e) => e.isVideo && e.isShowreel && e.url.trim().isNotEmpty)
          .map((e) => e.url.trim())
          .cast<String?>()
          .firstWhere((e) => e != null, orElse: () => null);
      var uploadedShowreelPreviewUrl = task.items
          .where((e) => e.isVideo && e.isShowreel && e.url.trim().isNotEmpty)
          .map((e) => e.previewUrl.trim())
          .cast<String?>()
          .firstWhere((e) => e != null, orElse: () => null);

      for (final originalItem in task.items) {
        task = _taskById(taskId);
        if (task == null) return;
        if (task.paused) {
          _replace(task.copyWith(status: ProfileMediaUploadStatus.paused));
          await _persistQueue();
          return;
        }
        final current = task.items.firstWhere((e) => e.id == originalItem.id);
        if (!current.canUpload) continue;

        var item = current.copyWith(
          status: ProfileMediaUploadItemStatus.preparing,
          error: '',
          progress: 0,
          webDiagnostic: kIsWeb ? 'готовим файл к загрузке' : '',
        );
        _replaceItem(taskId, item);
        await _persistQueue();

        try {
          item = await _ensurePersistentSource(task, item);
          if (_isPausedOrCancelled(taskId)) {
            await _pauseCurrentItem(taskId, item);
            return;
          }
          if (item.isPhoto) {
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.compressing,
              progress: 0,
              webDiagnostic: kIsWeb ? 'оптимизируем фото' : '',
            );
            _replaceItem(taskId, item);
            await _persistQueue();
          } else if (item.isVideo) {
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.compressing,
              progress: 0,
              webDiagnostic: kIsWeb ? 'готовим видео без нативного сжатия' : '',
            );
            _replaceItem(taskId, item);
            await _persistQueue();

            final prepared = await _prepareVideoSafely(task, item);
            if (_isPausedOrCancelled(taskId)) {
              await _pauseCurrentItem(taskId, item);
              return;
            }
            if (prepared.compressed) {
              item = item.copyWith(
                path: prepared.path,
                source: XFile(
                  prepared.path,
                  name: '${item.id}.mp4',
                  mimeType: 'video/mp4',
                ),
              );
              _replaceItem(taskId, item);
              await _persistQueue();
            }
          }
          item = item.copyWith(
            status: ProfileMediaUploadItemStatus.uploading,
            progress: 0,
            webDiagnostic: kIsWeb ? 'отправляем файл в Supabase Storage' : '',
          );
          _replaceItem(taskId, item);
          await _persistQueue();

          final cancelToken = ProfileMediaUploadCancelToken();
          _cancelTokens[taskId] = cancelToken;
          var lastProgressPercent = -1;
          void updateUploadProgress(double value) {
            if (cancelToken.isCancelled) return;
            final normalized = value.clamp(0.0, 1.0);
            final percent = (normalized * 100).floor();
            if (percent == lastProgressPercent && percent < 100) return;
            lastProgressPercent = percent;
            item = item.copyWith(progress: normalized);
            _replaceItem(taskId, item);
          }

          void updateResumableProgress(ProfileMediaResumableProgress value) {
            if (cancelToken.isCancelled) return;
            updateUploadProgress(value.progress);
            item = item.copyWith(
              resumableUploadUrl: value.uploadUrl,
              resumableUploadedBytes: value.uploadedBytes,
            );
            _replaceItem(taskId, item);
            unawaited(_persistQueue());
          }

          if (item.isPhoto) {
            final url = await storage.uploadPhoto(
              bucket: kProfileMediaBucket,
              uid: task.uid,
              file: item.toXFile(),
              pathSeed: _pathSeedForItem(item),
              onProgress: updateUploadProgress,
              cancelToken: cancelToken,
            );
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.uploaded,
              url: url,
              error: '',
              progress: 1,
              webDiagnostic: kIsWeb ? 'загружено, сохраняем анкету' : '',
            );
            uploadedPhotoUrls = [...uploadedPhotoUrls, url];
            uploadedPhotoCategoryLabels = [
              ...uploadedPhotoCategoryLabels,
              item.categoryLabel.trim().isEmpty
                  ? 'Портфолио'
                  : item.categoryLabel.trim(),
            ];
          } else {
            final result = await storage.uploadVideo(
              bucket: kProfileMediaBucket,
              uid: task.uid,
              file: item.toXFile(),
              pathSeed: _pathSeedForItem(item),
              onProgress: updateUploadProgress,
              onResumableProgress: updateResumableProgress,
              cancelToken: cancelToken,
              resumableUploadUrl: item.resumableUploadUrl,
              resumableUploadedBytes: item.resumableUploadedBytes,
            );
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.uploaded,
              url: result.videoUrl,
              previewUrl: result.previewUrl,
              error: '',
              progress: 1,
              resumableUploadUrl: '',
              resumableUploadedBytes: 0,
              webDiagnostic: kIsWeb ? 'загружено, сохраняем анкету' : '',
            );
            uploadedVideoUrls = [...uploadedVideoUrls, result.videoUrl];
            uploadedVideoPreviewUrls = [
              ...uploadedVideoPreviewUrls,
              result.previewUrl,
            ];
            uploadedVideoCategoryLabels = [
              ...uploadedVideoCategoryLabels,
              item.categoryLabel.trim().isEmpty
                  ? (item.isShowreel ? 'Showreel' : 'Видео')
                  : item.categoryLabel.trim(),
            ];
            if (item.isShowreel) {
              uploadedShowreelUrl = result.videoUrl;
              uploadedShowreelPreviewUrl = result.previewUrl;
            }
          }
          _replaceItem(taskId, item);
          await _persistQueue();
        } on ProfileMediaUploadCancelled {
          await _handleCancelledItem(taskId, item);
          return;
        } catch (e) {
          final message = _errorMessage(e);
          item = item.copyWith(
            status: ProfileMediaUploadItemStatus.failed,
            error: message,
            webDiagnostic: kIsWeb ? 'ошибка: $message' : '',
          );
          _replaceItem(taskId, item);
          final failedTask = _taskById(taskId);
          if (failedTask != null) {
            _replace(
              failedTask.copyWith(
                status: ProfileMediaUploadStatus.failed,
                error: message,
                paused: false,
              ),
            );
          }
          await _persistQueue();
          return;
        }
      }

      task = _taskById(taskId);
      if (task == null) return;
      final failed = task.items.any(
        (e) => e.status == ProfileMediaUploadItemStatus.failed,
      );
      final pending = task.items.any((e) => !e.isDone);
      if (failed || pending) {
        _replace(
          task.copyWith(
            status: failed
                ? ProfileMediaUploadStatus.failed
                : ProfileMediaUploadStatus.paused,
            error: failed ? 'Часть медиа не загрузилась' : '',
          ),
        );
        await _persistQueue();
        return;
      }

      _replace(
        task.copyWith(
          status: ProfileMediaUploadStatus.finalizing,
          items: [
            for (final item in task.items)
              item.copyWith(
                webDiagnostic: kIsWeb ? 'сохраняем медиа в анкету' : '',
              ),
          ],
        ),
      );
      await _persistQueue();

      await _finishUploadedTask(
        task,
        uploadedPhotoUrls: uploadedPhotoUrls,
        uploadedVideoUrls: uploadedVideoUrls,
        uploadedVideoPreviewUrls: uploadedVideoPreviewUrls,
        uploadedPhotoCategoryLabels: uploadedPhotoCategoryLabels,
        uploadedVideoCategoryLabels: uploadedVideoCategoryLabels,
        uploadedShowreelUrl: uploadedShowreelUrl ?? '',
        uploadedShowreelPreviewUrl: uploadedShowreelPreviewUrl ?? '',
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to upload profile media in queue',
        error: e,
        stackTrace: st,
      );
      final task = _taskById(taskId);
      if (task != null) {
        final message = _errorMessage(e);
        _replace(
          task.copyWith(
            status: ProfileMediaUploadStatus.failed,
            error: message,
            paused: false,
            items: [
              for (final item in task.items)
                item.isDone
                    ? item.copyWith(
                        webDiagnostic: kIsWeb
                            ? 'файл загружен, ошибка сохранения анкеты: $message'
                            : '',
                      )
                    : item,
            ],
          ),
        );
        await _persistQueue();
      }
    } finally {
      _cancelTokens.remove(taskId);
      _activeTasks.remove(taskId);
    }
  }

  bool _isPausedOrCancelled(String taskId) {
    final task = _taskById(taskId);
    return task == null ||
        task.paused ||
        _cancelTokens[taskId]?.isCancelled == true;
  }

  String _pathSeedForItem(ProfileMediaUploadItem item) {
    if (item.uploadAttempt <= 0) return item.id;
    return '${item.id}_retry_${item.uploadAttempt}';
  }

  String _errorMessage(Object error) {
    final type = error.runtimeType.toString();
    final message = error.toString().trim();
    if (message.contains('MissingPluginException')) {
      return 'Недоступен нативный модуль обработки видео в этой web-среде. type: $type. $message';
    }
    if (message.isEmpty || message == 'Exception') {
      return 'Не удалось загрузить медиа. type: $type. Проверьте соединение и повторите.';
    }
    return '$message\ntype: $type';
  }

  Future<PreparedVideo> _prepareVideoSafely(
    ProfileMediaUploadTask task,
    ProfileMediaUploadItem item,
  ) async {
    if (kIsWeb) {
      return PreparedVideo(
        path: item.path,
        originalBytes: 0,
        preparedBytes: 0,
        compressed: false,
      );
    }
    try {
      return await MediaTools.prepareVideo(
        inputPath: item.path,
        outputPath: await _compressedVideoPath(task.uid, item.id),
      );
    } catch (e, st) {
      AppLogger.warning(
        'Video preparation skipped, uploading original',
        error: e,
        stackTrace: st,
      );
      return PreparedVideo(
        path: item.path,
        originalBytes: 0,
        preparedBytes: 0,
        compressed: false,
      );
    }
  }

  Future<void> _pauseCurrentItem(
    String taskId,
    ProfileMediaUploadItem item,
  ) async {
    final task = _taskById(taskId);
    if (task == null) return;
    _replaceItem(
      taskId,
      item.copyWith(status: ProfileMediaUploadItemStatus.paused, error: ''),
    );
    final pausedTask = _taskById(taskId);
    if (pausedTask != null) {
      _replace(
        pausedTask.copyWith(
          status: ProfileMediaUploadStatus.paused,
          paused: true,
          error: '',
        ),
      );
    }
    await _persistQueue();
  }

  Future<void> _handleCancelledItem(
    String taskId,
    ProfileMediaUploadItem item,
  ) async {
    final task = _taskById(taskId);
    if (task == null) return;
    if (task.paused) {
      await _pauseCurrentItem(taskId, item);
      return;
    }

    final latestItem = task.items.firstWhere(
      (e) => e.id == item.id,
      orElse: () => item,
    );
    _replaceItem(
      taskId,
      latestItem.copyWith(
        status: ProfileMediaUploadItemStatus.queued,
        error: '',
        progress: 0,
        uploadAttempt: latestItem.resumableUploadUrl.trim().isEmpty
            ? latestItem.uploadAttempt + 1
            : latestItem.uploadAttempt,
      ),
    );
    await _persistQueue();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) unawaited(_process(taskId));
    });
  }

  Future<void> _finishUploadedTask(
    ProfileMediaUploadTask task, {
    required List<String> uploadedPhotoUrls,
    required List<String> uploadedVideoUrls,
    required List<String> uploadedVideoPreviewUrls,
    required List<String> uploadedPhotoCategoryLabels,
    required List<String> uploadedVideoCategoryLabels,
    required String uploadedShowreelUrl,
    required String uploadedShowreelPreviewUrl,
  }) async {
    final selectedCoverPhotoUrl = task.items
        .where((e) => e.isPhoto && e.isCover && e.url.trim().isNotEmpty)
        .map((e) => e.url.trim())
        .cast<String?>()
        .firstWhere((e) => e != null, orElse: () => null);

    final baseProfile = await _profileForTask(task);
    final profileForMedia = baseProfile.copyWith(
      pendingCoverPhotoUrl:
          !task.approveImmediately &&
              selectedCoverPhotoUrl != null &&
              selectedCoverPhotoUrl.isNotEmpty
          ? selectedCoverPhotoUrl
          : baseProfile.pendingCoverPhotoUrl,
      coverPhotoUrl:
          task.approveImmediately &&
              selectedCoverPhotoUrl != null &&
              selectedCoverPhotoUrl.isNotEmpty
          ? selectedCoverPhotoUrl
          : baseProfile.coverPhotoUrl,
    );

    try {
      final notifier = ref.read(myProfileProvider.notifier);
      final saved = await notifier
          .saveProfileWithPendingMedia(
            profile: profileForMedia,
            newPhotoUrls: uploadedPhotoUrls,
            newVideoUrls: uploadedVideoUrls,
            newVideoPreviewUrls: uploadedVideoPreviewUrls,
            newPhotoCategoryLabels: uploadedPhotoCategoryLabels,
            newVideoCategoryLabels: uploadedVideoCategoryLabels,
            newShowreelUrl: uploadedShowreelUrl,
            newShowreelPreviewUrl: uploadedShowreelPreviewUrl,
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw TimeoutException(
              'Файл загружен, но Supabase слишком долго сохраняет медиа в анкету. Нажмите «Повторить».',
            ),
          );
      if (task.approveImmediately) {
        await notifier
            .publishAdminProfile(saved.id)
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException(
                'Файл загружен, но публикация анкеты заняла слишком много времени. Нажмите «Повторить».',
              ),
            );
      }
    } catch (e) {
      final latest = _taskById(task.id) ?? task;
      final message = _errorMessage(e);
      _replace(
        latest.copyWith(
          status: ProfileMediaUploadStatus.failed,
          error: message,
          paused: false,
          items: [
            for (final item in latest.items)
              item.isDone
                  ? item.copyWith(
                      webDiagnostic: kIsWeb
                          ? 'файл загружен, ошибка сохранения анкеты: $message'
                          : '',
                    )
                  : item,
          ],
        ),
      );
      await _persistQueue();
      rethrow;
    }
    _replace(task.copyWith(status: ProfileMediaUploadStatus.completed));
    await _persistQueue();
    unawaited(ProfileMediaWebUploadCache.deleteTask(task.id));
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) dismiss(task.id);
    });
  }
}
