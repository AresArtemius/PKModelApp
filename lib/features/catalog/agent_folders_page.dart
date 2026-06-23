import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';

class AgentFoldersPage extends ConsumerWidget {
  const AgentFoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final canUse = ref.watch(canCreateSelectionsProvider);
    final folders = ref.watch(agentFoldersProvider);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.agentMyFoldersUpper,
                    onBack: () => context.go(Routes.search),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: canUse.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          _MessageCard(text: AppErrorMapper.message(e, t)),
                      data: (allowed) {
                        if (!allowed) {
                          return _MessageCard(text: t.adminOnlyUpper);
                        }
                        return folders.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) =>
                              _MessageCard(text: AppErrorMapper.message(e, t)),
                          data: (items) {
                            if (items.isEmpty) {
                              return _MessageCard(text: t.agentNoFolders);
                            }
                            return RefreshIndicator(
                              color: Colors.black,
                              backgroundColor: Colors.white,
                              onRefresh: () async {
                                ref.invalidate(agentFoldersProvider);
                              },
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _FolderSection(folder: items[index]);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderSection extends ConsumerWidget {
  const _FolderSection({required this.folder});

  final AgentFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final details = ref.watch(agentFolderDetailsProvider(folder.id));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
        gradient: BrandTheme.lightPillGradient,
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            folder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          children: [
            details.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (e, _) =>
                  _InlineMessage(text: AppErrorMapper.message(e, t)),
              data: (data) {
                final profiles = data?.profiles ?? const <AgentFolderProfile>[];
                if (profiles.isEmpty) {
                  return _InlineMessage(text: t.agentFolderEmpty);
                }
                return Column(
                  children: [
                    for (var i = 0; i < profiles.length; i++) ...[
                      _FolderProfileTile(profile: profiles[i]),
                      if (i != profiles.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderProfileTile extends StatelessWidget {
  const _FolderProfileTile({required this.profile});

  final AgentFolderProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final subtitle = [
      if (profile.age > 0) '${t.age}: ${profile.age}',
      if (profile.height > 0) '${t.height}: ${profile.height} ${t.cm}',
      if (profile.city.isNotEmpty) profile.city,
    ].join(' · ');

    return Material(
      color: Colors.white.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('${Routes.modelPrefix}${profile.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: profile.photoUrl.isEmpty
                      ? Container(
                          color: const Color(0x14000000),
                          child: const Icon(
                            Icons.person_rounded,
                            color: kTextMuted,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: profile.photoUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 180,
                          maxWidthDiskCache: 180,
                          placeholder: (_, _) =>
                              Container(color: const Color(0x14000000)),
                          errorWidget: (_, _, _) => Container(
                            color: const Color(0x14000000),
                            child: const Icon(
                              Icons.person_rounded,
                              color: kTextMuted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty ? '—' : profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BrandTheme.redTop),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kCardRadius),
          gradient: BrandTheme.lightPillGradient,
          border: Border.all(color: kBorderColor, width: 1),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w700),
      ),
    );
  }
}
