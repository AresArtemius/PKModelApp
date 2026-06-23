import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';

const double _sectionGap = 14;
const double _innerGap = 10;
const double _sectionTitleLetterSpacing = 1.4;

const Color _titleColor = kTextDark;
const Color _subtitleColor = Color(0xFF4A4A4A);
const Color _labelColor = Color(0xFF5A5A5A);

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
            t.agentWorkspaceUpper,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: _sectionTitleLetterSpacing,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: _innerGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.agentFoldersUpper,
                  style: const TextStyle(
                    color: _labelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SmallTextButton(
                label: t.agentFolderCreateUpper,
                onTap: onCreateFolder,
              ),
            ],
          ),
          const SizedBox(height: 8),
          folders.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              t.unknownError,
              style: const TextStyle(color: kTextDanger),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  t.agentNoFolders,
                  style: const TextStyle(color: _subtitleColor),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
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
          const SizedBox(height: _sectionGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.agentPrivateNoteUpper,
                  style: const TextStyle(
                    color: _labelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SmallTextButton(
                label: t.agentEditNoteUpper,
                onTap: () => onEditNote(noteText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          note.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              t.unknownError,
              style: const TextStyle(color: kTextDanger),
            ),
            data: (value) => Text(
              value.trim().isEmpty ? t.agentPrivateNoteEmpty : value.trim(),
              style: const TextStyle(color: _subtitleColor, height: 1.35),
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
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: kTextDark,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
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
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            widget.actionLabel,
            style: const TextStyle(
              color: BrandTheme.redTop,
              fontWeight: FontWeight.w900,
            ),
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: pillDecoration(isDark: false, radius: kCardRadius).copyWith(
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
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
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pillDecoration(isDark: selected, radius: 999).copyWith(
            border: Border.all(
              color: selected ? Colors.transparent : kBorderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : kTextDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTextButton extends StatelessWidget {
  const _SmallTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: BrandTheme.redTop,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      child: Text(label),
    );
  }
}
