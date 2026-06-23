import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';

class AgentFolder {
  const AgentFolder({
    required this.id,
    required this.title,
    required this.containsProfile,
  });

  final String id;
  final String title;
  final bool containsProfile;

  factory AgentFolder.fromMap(Map<String, dynamic> map, Set<String> selected) {
    final id = (map['id'] ?? '').toString();
    return AgentFolder(
      id: id,
      title: (map['title'] ?? '').toString().trim(),
      containsProfile: selected.contains(id),
    );
  }
}

class AgentFolderProfile {
  const AgentFolderProfile({
    required this.id,
    required this.fullName,
    required this.age,
    required this.height,
    required this.city,
    required this.photoUrl,
  });

  final String id;
  final String fullName;
  final int age;
  final int height;
  final String city;
  final String photoUrl;

  factory AgentFolderProfile.fromMap(Map<String, dynamic> map) {
    final photos = map['photo_urls'] is List
        ? map['photo_urls'] as List
        : const [];
    return AgentFolderProfile(
      id: (map['id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString().trim(),
      age: _intOrZero(map['age']),
      height: _intOrZero(map['height']),
      city: (map['city'] ?? '').toString().trim(),
      photoUrl: photos.isEmpty ? '' : photos.first.toString().trim(),
    );
  }
}

class AgentFolderDetails {
  const AgentFolderDetails({required this.folder, required this.profiles});

  final AgentFolder folder;
  final List<AgentFolderProfile> profiles;
}

class AgentWorkspaceService {
  const AgentWorkspaceService(this._sb);

  static const int _foldersLimit = 100;
  static const int _folderProfilesLimit = 300;

  final SupabaseClient _sb;

  String? get _userId => _sb.auth.currentUser?.id;

  Future<List<AgentFolder>> fetchFolders() async {
    final userId = _userId;
    if (userId == null) return const <AgentFolder>[];

    try {
      final rows = await _sb
          .from('casting_agent_folders')
          .select('id,title')
          .eq('user_id', userId)
          .order('title')
          .limit(_foldersLimit);

      return (rows as List)
          .map(
            (row) => AgentFolder.fromMap(
              Map<String, dynamic>.from(row as Map),
              const <String>{},
            ),
          )
          .where((folder) => folder.id.isNotEmpty && folder.title.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isMissingAgentWorkspaceTable(e)) return const <AgentFolder>[];
      rethrow;
    }
  }

  Future<AgentFolderDetails?> fetchFolderDetails(String folderId) async {
    final userId = _userId;
    if (userId == null || folderId.isEmpty) return null;

    try {
      final folderRow = await _sb
          .from('casting_agent_folders')
          .select('id,title')
          .eq('user_id', userId)
          .eq('id', folderId)
          .maybeSingle();
      if (folderRow == null) return null;

      final itemRows = await _sb
          .from('casting_agent_folder_items')
          .select('profile:profiles(id,full_name,age,height,city,photo_urls)')
          .eq('user_id', userId)
          .eq('folder_id', folderId)
          .order('created_at', ascending: false)
          .limit(_folderProfilesLimit);

      final profiles = (itemRows as List)
          .map((row) => (row as Map)['profile'])
          .whereType<Map>()
          .map(
            (profile) =>
                AgentFolderProfile.fromMap(Map<String, dynamic>.from(profile)),
          )
          .where((profile) => profile.id.isNotEmpty)
          .toList(growable: false);

      return AgentFolderDetails(
        folder: AgentFolder.fromMap(
          Map<String, dynamic>.from(folderRow),
          const <String>{},
        ),
        profiles: profiles,
      );
    } on PostgrestException catch (e) {
      if (_isMissingAgentWorkspaceTable(e)) return null;
      rethrow;
    }
  }

  Future<List<AgentFolder>> fetchFoldersForProfile(String profileId) async {
    final userId = _userId;
    if (userId == null) return const <AgentFolder>[];

    try {
      final foldersRows = await _sb
          .from('casting_agent_folders')
          .select('id,title')
          .eq('user_id', userId)
          .order('title')
          .limit(_foldersLimit);

      final itemRows = await _sb
          .from('casting_agent_folder_items')
          .select('folder_id')
          .eq('user_id', userId)
          .eq('profile_id', profileId);

      final selected = (itemRows as List)
          .map((row) => ((row as Map)['folder_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      return (foldersRows as List)
          .map(
            (row) =>
                AgentFolder.fromMap(Map<String, dynamic>.from(row), selected),
          )
          .where((folder) => folder.id.isNotEmpty && folder.title.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (_isMissingAgentWorkspaceTable(e)) return const <AgentFolder>[];
      rethrow;
    }
  }

  Future<void> createFolder(String title) async {
    final userId = _userId;
    final cleanTitle = title.trim();
    if (userId == null || cleanTitle.isEmpty) return;

    await _sb.from('casting_agent_folders').insert({
      'user_id': userId,
      'title': cleanTitle,
    });
  }

  Future<AgentFolder?> findOrCreateFolder(String title) async {
    final userId = _userId;
    final cleanTitle = title.trim();
    if (userId == null || cleanTitle.isEmpty) return null;

    final rows = await _sb
        .from('casting_agent_folders')
        .select('id,title')
        .eq('user_id', userId)
        .eq('title', cleanTitle)
        .order('created_at')
        .limit(1);

    if (rows.isNotEmpty) {
      return AgentFolder.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
        const <String>{},
      );
    }

    final inserted = await _sb
        .from('casting_agent_folders')
        .insert({'user_id': userId, 'title': cleanTitle})
        .select('id,title')
        .single();

    return AgentFolder.fromMap(
      Map<String, dynamic>.from(inserted),
      const <String>{},
    );
  }

  Future<void> addProfileToNamedFolder({
    required String title,
    required String profileId,
  }) async {
    final folder = await findOrCreateFolder(title);
    if (folder == null) return;
    await setProfileInFolder(
      folderId: folder.id,
      profileId: profileId,
      selected: true,
    );
  }

  Future<void> setProfileInFolder({
    required String folderId,
    required String profileId,
    required bool selected,
  }) async {
    final userId = _userId;
    if (userId == null || folderId.isEmpty || profileId.isEmpty) return;

    if (selected) {
      await _sb.from('casting_agent_folder_items').upsert({
        'user_id': userId,
        'folder_id': folderId,
        'profile_id': profileId,
      }, onConflict: 'folder_id,profile_id');
      return;
    }

    await _sb
        .from('casting_agent_folder_items')
        .delete()
        .eq('user_id', userId)
        .eq('folder_id', folderId)
        .eq('profile_id', profileId);
  }

  Future<String> fetchNote(String profileId) async {
    final userId = _userId;
    if (userId == null) return '';

    Map<String, dynamic>? row;
    try {
      row = await _sb
          .from('casting_agent_model_notes')
          .select('note')
          .eq('user_id', userId)
          .eq('profile_id', profileId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (_isMissingAgentWorkspaceTable(e)) return '';
      rethrow;
    }

    return (row?['note'] ?? '').toString();
  }

  Future<void> saveNote({
    required String profileId,
    required String note,
  }) async {
    final userId = _userId;
    if (userId == null || profileId.isEmpty) return;

    await _sb.from('casting_agent_model_notes').upsert({
      'user_id': userId,
      'profile_id': profileId,
      'note': note.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,profile_id');
  }

  bool _isMissingAgentWorkspaceTable(PostgrestException e) {
    return SupabaseCompat.isMissingRelation(e, const [
      'casting_agent_folders',
      'casting_agent_folder_items',
      'casting_agent_model_notes',
    ]);
  }
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final agentWorkspaceServiceProvider = Provider<AgentWorkspaceService>((ref) {
  return AgentWorkspaceService(ref.read(supabaseProvider));
});

final agentFoldersForProfileProvider = FutureProvider.autoDispose
    .family<List<AgentFolder>, String>((ref, profileId) {
      return ref
          .watch(agentWorkspaceServiceProvider)
          .fetchFoldersForProfile(profileId);
    });

final agentModelNoteProvider = FutureProvider.autoDispose
    .family<String, String>((ref, profileId) {
      return ref.watch(agentWorkspaceServiceProvider).fetchNote(profileId);
    });

final agentFoldersProvider = FutureProvider.autoDispose<List<AgentFolder>>((
  ref,
) {
  return ref.watch(agentWorkspaceServiceProvider).fetchFolders();
});

final agentFolderDetailsProvider = FutureProvider.autoDispose
    .family<AgentFolderDetails?, String>((ref, folderId) {
      return ref
          .watch(agentWorkspaceServiceProvider)
          .fetchFolderDetails(folderId);
    });
