import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../core/supabase_provider.dart';
import 'my_profile_controller.dart';
import 'profile_media_storage.dart';
import 'profile_model.dart';

const String kProfileMediaBucket = 'profile-media';

final profileMediaUploadQueueProvider =
    StateNotifierProvider<
      ProfileMediaUploadQueue,
      List<ProfileMediaUploadTask>
    >((ref) => ProfileMediaUploadQueue(ref));

enum ProfileMediaUploadStatus { uploading, paused, failed, completed }

enum ProfileMediaUploadItemKind { photo, video }

enum ProfileMediaUploadItemStatus {
  queued,
  preparing,
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
  final XFile? source;

  bool get isPhoto => kind == ProfileMediaUploadItemKind.photo;

  bool get isVideo => kind == ProfileMediaUploadItemKind.video;

  bool get isDone => status == ProfileMediaUploadItemStatus.uploaded;

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
    final active = items.any(
      (e) =>
          e.status == ProfileMediaUploadItemStatus.preparing ||
          e.status == ProfileMediaUploadItemStatus.uploading,
    );
    final activeBonus = active ? 0.45 : 0.0;
    return ((completedCount + activeBonus) / totalCount).clamp(0.0, 1.0);
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

  void enqueue({
    required String uid,
    required MyProfileState profile,
    required List<XFile> pickedPhotos,
    required List<XFile> pickedVideos,
    required int? pickedCoverPhotoIndex,
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
        ),
      for (int i = 0; i < pickedVideos.length; i++)
        _itemFromXFile(
          taskId: taskId,
          index: pickedPhotos.length + i,
          kind: ProfileMediaUploadItemKind.video,
          file: pickedVideos[i],
          isCover: false,
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
    unawaited(_process(task.id));
  }

  void pause(String taskId) {
    final task = _taskById(taskId);
    if (task == null || !task.canPause) return;
    final nextItems = [
      for (final item in task.items)
        item.status == ProfileMediaUploadItemStatus.queued
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
      final restored = decoded
          .whereType<Map>()
          .map((e) => ProfileMediaUploadTask.fromJson(Map.from(e)))
          .where((e) => e.id.isNotEmpty && e.items.isNotEmpty)
          .map(_normalizeRestoredTask)
          .toList();
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

  ProfileMediaUploadTask _normalizeRestoredTask(ProfileMediaUploadTask task) {
    if (kIsWeb) {
      return task.copyWith(
        status: ProfileMediaUploadStatus.failed,
        paused: false,
        error:
            'После перезапуска браузер не может восстановить выбранные файлы. Выберите медиа заново.',
        items: [
          for (final item in task.items)
            item.isDone
                ? item
                : item.copyWith(
                    status: ProfileMediaUploadItemStatus.failed,
                    error: 'Файл недоступен после перезапуска браузера',
                  ),
        ],
      );
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
          if (item.isVideo) item.previewUrl.trim(),
      ];

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
        );
        _replaceItem(taskId, item);
        await _persistQueue();

        try {
          item = await _ensurePersistentSource(task, item);
          item = item.copyWith(status: ProfileMediaUploadItemStatus.uploading);
          _replaceItem(taskId, item);
          await _persistQueue();

          if (item.isPhoto) {
            final url = await storage.uploadPhoto(
              bucket: kProfileMediaBucket,
              uid: task.uid,
              file: item.toXFile(),
              pathSeed: item.id,
            );
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.uploaded,
              url: url,
              error: '',
            );
            uploadedPhotoUrls = [...uploadedPhotoUrls, url];
          } else {
            final result = await storage.uploadVideo(
              bucket: kProfileMediaBucket,
              uid: task.uid,
              file: item.toXFile(),
              pathSeed: item.id,
            );
            item = item.copyWith(
              status: ProfileMediaUploadItemStatus.uploaded,
              url: result.videoUrl,
              previewUrl: result.previewUrl,
              error: '',
            );
            uploadedVideoUrls = [...uploadedVideoUrls, result.videoUrl];
            uploadedVideoPreviewUrls = [
              ...uploadedVideoPreviewUrls,
              result.previewUrl,
            ];
          }
          _replaceItem(taskId, item);
          await _persistQueue();
        } catch (e) {
          item = item.copyWith(
            status: ProfileMediaUploadItemStatus.failed,
            error: e.toString().trim(),
          );
          _replaceItem(taskId, item);
          final failedTask = _taskById(taskId);
          if (failedTask != null) {
            _replace(
              failedTask.copyWith(
                status: ProfileMediaUploadStatus.failed,
                error: e.toString().trim(),
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

      await _finishUploadedTask(
        task,
        uploadedPhotoUrls: uploadedPhotoUrls,
        uploadedVideoUrls: uploadedVideoUrls,
        uploadedVideoPreviewUrls: uploadedVideoPreviewUrls,
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to upload profile media in queue',
        error: e,
        stackTrace: st,
      );
      final task = _taskById(taskId);
      if (task != null) {
        _replace(
          task.copyWith(
            status: ProfileMediaUploadStatus.failed,
            error: e.toString().trim(),
            paused: false,
          ),
        );
        await _persistQueue();
      }
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  Future<void> _finishUploadedTask(
    ProfileMediaUploadTask task, {
    required List<String> uploadedPhotoUrls,
    required List<String> uploadedVideoUrls,
    required List<String> uploadedVideoPreviewUrls,
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

    final notifier = ref.read(myProfileProvider.notifier);
    final saved = await notifier.saveProfileWithPendingMedia(
      profile: profileForMedia,
      newPhotoUrls: uploadedPhotoUrls,
      newVideoUrls: uploadedVideoUrls,
      newVideoPreviewUrls: uploadedVideoPreviewUrls,
    );
    if (task.approveImmediately) {
      await notifier.publishAdminProfile(saved.id);
    }
    _replace(task.copyWith(status: ProfileMediaUploadStatus.completed));
    await _persistQueue();
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) dismiss(task.id);
    });
  }
}
