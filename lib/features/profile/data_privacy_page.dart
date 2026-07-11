import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../core/user_security_audit_service.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class PersonalDataExportService {
  const PersonalDataExportService(this._sb);

  final SupabaseClient _sb;

  Future<Map<String, dynamic>> buildExport() async {
    final user = _sb.auth.currentUser;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) {
      return const <String, dynamic>{};
    }

    final exportedAt = DateTime.now().toUtc().toIso8601String();
    return {
      'exported_at': exportedAt,
      'user': {
        'id': userId,
        'email': user?.email,
        'phone': user?.phone,
        'created_at': user?.createdAt,
        'updated_at': user?.updatedAt,
        'user_metadata': user?.userMetadata,
      },
      'account_profile': await _maybeSingle(
        'user_profiles',
        column: 'user_id',
        value: userId,
      ),
      'roles': await _list('user_roles', column: 'user_id', value: userId),
      'professional_profiles': await _list(
        'profiles',
        column: 'user_id',
        value: userId,
      ),
      'notifications': await _list(
        'app_notifications',
        column: 'user_id',
        value: userId,
      ),
      'push_devices': await _list(
        'push_device_tokens',
        column: 'user_id',
        value: userId,
      ),
      'notification_preferences': await _maybeSingle(
        'notification_preferences',
        column: 'user_id',
        value: userId,
      ),
      'legal_consents': await _list(
        'user_legal_consents',
        column: 'user_id',
        value: userId,
      ),
      'casting_agent_applications': await _list(
        'casting_agent_applications',
        column: 'user_id',
        value: userId,
      ),
      'castings_created': await _listIfColumnExists(
        'castings',
        column: 'created_by',
        value: userId,
      ),
      'selections_created': await _listIfColumnExists(
        'selections',
        column: 'created_by',
        value: userId,
      ),
    };
  }

  Future<Map<String, dynamic>?> _maybeSingle(
    String table, {
    required String column,
    required String value,
  }) async {
    try {
      final row = await _sb
          .from(table)
          .select()
          .eq(column, value)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, [table]) ||
          SupabaseCompat.isMissingColumn(e, column)) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _list(
    String table, {
    required String column,
    required String value,
  }) async {
    try {
      final rows = await _sb.from(table).select().eq(column, value).limit(500);
      return rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (SupabaseCompat.isMissingRelation(e, [table]) ||
          SupabaseCompat.isMissingColumn(e, column)) {
        return const [];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _listIfColumnExists(
    String table, {
    required String column,
    required String value,
  }) {
    return _list(table, column: column, value: value);
  }
}

final personalDataExportServiceProvider = Provider<PersonalDataExportService>((
  ref,
) {
  return PersonalDataExportService(ref.read(supabaseProvider));
});

class DataPrivacyPage extends ConsumerStatefulWidget {
  const DataPrivacyPage({super.key});

  @override
  ConsumerState<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends ConsumerState<DataPrivacyPage> {
  bool _exporting = false;
  String _message = '';
  String _exportJson = '';

  bool get _isRussian =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

  Future<void> _copyExport() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _message = '';
    });

    try {
      final data = await ref
          .read(personalDataExportServiceProvider)
          .buildExport();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      await ref
          .read(userSecurityAuditServiceProvider)
          .log(
            eventType: UserSecurityAuditEvent.dataExported,
            label: _isRussian ? 'Данные экспортированы' : 'Data exported',
            metadata: {'format': 'json', 'destination': 'clipboard'},
          );
      if (!mounted) return;
      setState(() {
        _exportJson = json;
        _message = _isRussian
            ? 'Экспорт JSON скопирован в буфер обмена.'
            : 'JSON export copied to clipboard.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _isRussian
            ? 'Не удалось подготовить экспорт.\n$e'
            : 'Could not prepare export.\n$e';
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: kMyProfilePagePad,
              children: [
                BrandAdminHeader(
                  title: _isRussian ? 'ЭКСПОРТ ДАННЫХ' : 'DATA EXPORT',
                  onBack: () => context.go(Routes.me),
                ),
                const SizedBox(height: kGap14),
                _InfoCard(
                  icon: Icons.file_download_rounded,
                  title: _isRussian ? 'Скачать мои данные' : 'Download my data',
                  body: _isRussian
                      ? 'Экспорт собирает доступные вашему аккаунту данные в JSON: профиль аккаунта, анкеты, уведомления, push-устройства, согласия и связанные записи.'
                      : 'Export collects data available to your account as JSON: account profile, profiles, notifications, push devices, consents and related records.',
                  actionLabel: _exporting
                      ? '...'
                      : (_isRussian ? 'СКОПИРОВАТЬ JSON' : 'COPY JSON'),
                  onAction: _exporting ? null : _copyExport,
                ),
                if (_message.trim().isNotEmpty) ...[
                  const SizedBox(height: kGap12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: _bodyStyle(
                      color: _message.contains('\n')
                          ? BrandTheme.redTop
                          : kTextMuted,
                    ),
                  ),
                ],
                if (_exportJson.isNotEmpty) ...[
                  const SizedBox(height: kGap12),
                  _ExportPreview(text: _exportJson),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kTextDark),
          const SizedBox(width: kGap12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle()),
                const SizedBox(height: 6),
                Text(body, style: _bodyStyle()),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: BrandPillButton(
                    label: actionLabel,
                    style: BrandPillStyle.light,
                    onTap: onAction,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPreview extends StatelessWidget {
  const _ExportPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final preview = text.length > 1600
        ? '${text.substring(0, 1600)}\n...'
        : text;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: catalogCardDecoration(),
      child: SelectableText(
        preview,
        style: const TextStyle(
          color: kTextDark,
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.25,
        ),
      ),
    );
  }
}

TextStyle _titleStyle({Color color = kTextDark}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );
}

TextStyle _bodyStyle({Color color = kTextMuted}) {
  return TextStyle(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.28,
  );
}
