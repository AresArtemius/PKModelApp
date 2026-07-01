import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

enum ProfileMediaUploadStatus { uploading, failed, completed }

class ProfileMediaUploadTask {
  const ProfileMediaUploadTask({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.uid,
    required this.profile,
    required this.pickedPhotos,
    required this.pickedVideos,
    required this.pickedCoverPhotoIndex,
    required this.approveImmediately,
    required this.status,
    required this.error,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String profileName;
  final String uid;
  final MyProfileState profile;
  final List<XFile> pickedPhotos;
  final List<XFile> pickedVideos;
  final int? pickedCoverPhotoIndex;
  final bool approveImmediately;
  final ProfileMediaUploadStatus status;
  final String error;
  final DateTime createdAt;

  int get photoCount => pickedPhotos.length;

  int get videoCount => pickedVideos.length;

  bool get hasMedia => photoCount > 0 || videoCount > 0;

  ProfileMediaUploadTask copyWith({
    ProfileMediaUploadStatus? status,
    String? error,
    MyProfileState? profile,
  }) {
    return ProfileMediaUploadTask(
      id: id,
      profileId: profileId,
      profileName: profileName,
      uid: uid,
      profile: profile ?? this.profile,
      pickedPhotos: pickedPhotos,
      pickedVideos: pickedVideos,
      pickedCoverPhotoIndex: pickedCoverPhotoIndex,
      approveImmediately: approveImmediately,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
    );
  }
}

class ProfileMediaUploadQueue
    extends StateNotifier<List<ProfileMediaUploadTask>> {
  ProfileMediaUploadQueue(this.ref) : super(const []);

  final Ref ref;

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

    final task = ProfileMediaUploadTask(
      id: '${profileId}_${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      profileName: profile.fullName.trim(),
      uid: uid,
      profile: profile,
      pickedPhotos: List<XFile>.from(pickedPhotos),
      pickedVideos: List<XFile>.from(pickedVideos),
      pickedCoverPhotoIndex: pickedCoverPhotoIndex,
      approveImmediately: approveImmediately,
      status: ProfileMediaUploadStatus.uploading,
      error: '',
      createdAt: DateTime.now(),
    );

    state = [...state, task];
    unawaited(_process(task));
  }

  void retry(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status != ProfileMediaUploadStatus.failed) return;
    _replace(
      task.copyWith(status: ProfileMediaUploadStatus.uploading, error: ''),
    );
    unawaited(_process(task));
  }

  void dismiss(String taskId) {
    state = [
      for (final item in state)
        if (item.id != taskId) item,
    ];
  }

  ProfileMediaUploadTask? latestForProfile(String profileId) {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    for (final task in state.reversed) {
      if (task.profileId == id) return task;
    }
    return null;
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

  String _uploadedCoverPhotoUrlFrom(
    List<String> uploadedPhotoUrls,
    int? selectedIndex,
  ) {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= uploadedPhotoUrls.length) {
      return '';
    }
    return uploadedPhotoUrls[index].trim();
  }

  Future<void> _process(ProfileMediaUploadTask task) async {
    try {
      final storage = ProfileMediaStorage(ref.read(supabaseProvider));
      final result = await storage.uploadPickedMedia(
        bucket: kProfileMediaBucket,
        uid: task.uid,
        pickedPhotos: task.pickedPhotos,
        pickedVideos: task.pickedVideos,
      );
      final selectedCoverPhotoUrl = _uploadedCoverPhotoUrlFrom(
        result.photoUrls,
        task.pickedCoverPhotoIndex,
      );
      final notifier = ref.read(myProfileProvider.notifier);
      var baseProfile = task.profile;
      for (final profile
          in ref.read(myProfileProvider).valueOrNull ??
              const <MyProfileState>[]) {
        if (profile.id == task.profileId) {
          baseProfile = profile;
          break;
        }
      }

      final profileForMedia = baseProfile.copyWith(
        pendingCoverPhotoUrl:
            !task.approveImmediately && selectedCoverPhotoUrl.isNotEmpty
            ? selectedCoverPhotoUrl
            : baseProfile.pendingCoverPhotoUrl,
        coverPhotoUrl:
            task.approveImmediately && selectedCoverPhotoUrl.isNotEmpty
            ? selectedCoverPhotoUrl
            : baseProfile.coverPhotoUrl,
      );

      final saved = await notifier.saveProfileWithPendingMedia(
        profile: profileForMedia,
        newPhotoUrls: result.photoUrls,
        newVideoUrls: result.videoUrls,
        newVideoPreviewUrls: result.videoPreviewUrls,
      );
      if (task.approveImmediately) {
        await notifier.publishAdminProfile(saved.id);
      }
      _replace(task.copyWith(status: ProfileMediaUploadStatus.completed));
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (mounted) dismiss(task.id);
      });
    } catch (e, st) {
      AppLogger.error(
        'Failed to upload profile media in queue',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _replace(
        task.copyWith(
          status: ProfileMediaUploadStatus.failed,
          error: e.toString().trim(),
        ),
      );
    }
  }
}
