import 'package:flutter/material.dart';

import '../../ui/brand/ui_constants.dart';

/// A small «edit the text» dialog used for posts and comments.
/// Returns the new text, or null when cancelled / unchanged.
Future<String?> showEditTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
  int maxLength = 2000,
  int minLines = 3,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      title: Text(title, style: AppText.h2),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: minLines,
          maxLines: 10,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(ru ? 'Сохранить' : 'Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return null;
  final text = result.trim();
  if (text.isEmpty || text == initial.trim()) return null;
  return text;
}
