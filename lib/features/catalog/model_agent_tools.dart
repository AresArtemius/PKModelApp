import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';


String _agentText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
}

/// Agent tools on a profile (v2): folders as flat chips and a private note,
/// in one bordered card with sentence-case labels.
class ModelAgentToolsCard extends StatelessWidget {
  const ModelAgentToolsCard({
    super.key,
    required this.folders,
    required this.note,
    required this.onCreateFolder,
    required this.onToggleFolder,
    required this.onEditNote,
  });

  final AsyncValue<List<AgentFolder>> folders;
  final AsyncValue<String> note;
  final VoidCallback onCreateFolder;
  final ValueChanged<AgentFolder> onToggleFolder;
  final ValueChanged<String> onEditNote;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final noteText = note.maybeWhen(
      data: (value) => value.trim(),
      orElse: () => '',
    );

    return _AgentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _agentText(context, 'РАБОТА АГЕНТА', 'AGENT TOOLS'),
            style: AppText.label.copyWith(fontSize: 12, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _agentText(context, 'Папки', 'Folders'),
                  style: AppText.smallStrong,
                ),
              ),
              _SmallTextButton(
                icon: Icons.add_rounded,
                label: _agentText(context, 'Новая папка', 'New folder'),
                onTap: onCreateFolder,
              ),
            ],
          ),
          const SizedBox(height: 8),
          folders.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              t.unknownError,
              style: AppText.small.copyWith(color: Tokens.danger),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  t.agentNoFolders,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                );
              }
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final folder in items)
                    _FolderChip(
                      label: folder.title,
                      selected: folder.containsProfile,
                      onTap: () => onToggleFolder(folder),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _agentText(context, 'Приватная заметка', 'Private note'),
                  style: AppText.smallStrong,
                ),
              ),
              _SmallTextButton(
                icon: Icons.edit_outlined,
                label: _agentText(context, 'Изменить', 'Edit'),
                onTap: () => onEditNote(noteText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          note.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              t.unknownError,
              style: AppText.small.copyWith(color: Tokens.danger),
            ),
            data: (value) => Text(
              value.trim().isEmpty ? t.agentPrivateNoteEmpty : value.trim(),
              style: AppText.small.copyWith(
                color: value.trim().isEmpty
                    ? Tokens.textSecondary
                    : Tokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgentTextInputDialog extends StatefulWidget {
  const AgentTextInputDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.actionLabel,
    this.initial = '',
    this.maxLines = 1,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final String initial;
  final int maxLines;

  @override
  State<AgentTextInputDialog> createState() => _AgentTextInputDialogState();
}

class _AgentTextInputDialogState extends State<AgentTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        minLines: widget.maxLines == 1 ? 1 : 3,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        onSubmitted: widget.maxLines == 1
            ? (_) => Navigator.of(context).pop(_controller.text)
            : null,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _AgentSurface extends StatelessWidget {
  const _AgentSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: Tokens.border),
      ),
      child: child,
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Tokens.ink : Tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Tokens.textOnDark,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppText.small.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Tokens.textOnDark : Tokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTextButton extends StatelessWidget {
  const _SmallTextButton({
    required this.label,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Tokens.text,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppText.small.copyWith(fontWeight: FontWeight.w500),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
