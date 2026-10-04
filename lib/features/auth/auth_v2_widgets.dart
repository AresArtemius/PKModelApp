import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/brand/ui_constants.dart';
import '../legal/legal_documents.dart';
import 'auth_split_layout.dart';

/// Frame for every auth screen in the v2 style: on wide screens the brand
/// panel on the left and the form on the right ([AuthSplitLayout]); on
/// narrow screens a plain white page with the form stretched to the width.
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.child,
    this.topBar,
    this.maxWidth = Tokens.formMaxWidth,
  });

  final Widget child;
  final Widget? topBar;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kAuthDesktopBreakpoint;
    if (wide) {
      return AuthSplitLayout(topBar: topBar, child: child);
    }
    return ColoredBox(
      color: Tokens.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: topBar,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field decoration for the v2 auth forms: the app theme already
/// draws the hairline border, this only adds the label and error line.
InputDecoration authFieldDecoration({
  required String label,
  String? errorText,
  String? hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    errorText: errorText,
    errorMaxLines: 3,
    errorStyle: AppText.caption.copyWith(color: Tokens.danger),
    suffixIcon: suffixIcon,
  );
}

/// Quiet message strip above a form: an error or a confirmation.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? Tokens.accentSoft : Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: AppText.small.copyWith(
          color: isError ? Tokens.danger : Tokens.text,
        ),
      ),
    );
  }
}

/// «Назад» link for the top bar of auth pages.
class AuthBackLink extends StatelessWidget {
  const AuthBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Tokens.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 36),
        textStyle: AppText.smallStrong,
      ),
    );
  }
}

/// Checkbox row «Я принимаю документы…» with the legal links underneath.
class AuthConsentRow extends StatelessWidget {
  const AuthConsentRow({
    super.key,
    required this.accepted,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final links = <(String, LegalDocumentKind)>[
      (ru ? 'Конфиденциальность' : 'Privacy', LegalDocumentKind.privacy),
      (ru ? 'Условия' : 'Terms', LegalDocumentKind.terms),
      (ru ? 'Безопасность детей' : 'Child safety', LegalDocumentKind.childSafety),
      ('Cookies', LegalDocumentKind.cookies),
      (
        ru ? 'Обработка данных' : 'Data processing',
        LegalDocumentKind.processingNotice,
      ),
      (ru ? 'Реквизиты' : 'Legal details', LegalDocumentKind.requisites),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          onTap: enabled ? () => onChanged(!accepted) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: accepted,
                    onChanged: enabled
                        ? (value) => onChanged(value ?? false)
                        : null,
                    activeColor: Tokens.ink,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: errorText != null
                          ? Tokens.danger
                          : Tokens.borderStrong,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      ru
                          ? 'Я принимаю документы и согласие на обработку данных'
                          : 'I accept the documents and the data processing consent',
                      style: AppText.small.copyWith(color: Tokens.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Wrap(
            spacing: 2,
            runSpacing: 0,
            children: [
              for (var i = 0; i < links.length; i++) ...[
                _LegalLinkV2(
                  label: links[i].$1,
                  route: legalDocumentByKind(links[i].$2).route,
                ),
                if (i != links.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('·', style: TextStyle(color: Tokens.textTertiary)),
                  ),
              ],
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text(
              errorText!,
              style: AppText.caption.copyWith(color: Tokens.danger),
            ),
          ),
      ],
    );
  }
}

class _LegalLinkV2 extends StatelessWidget {
  const _LegalLinkV2({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: Tokens.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: Tokens.borderStrong,
          ),
        ),
      ),
    );
  }
}

/// Two-choice row of bordered options (e.g. «Модель / участник» vs
/// «Заказчик»); the selected one gets an ink border.
class AuthChoiceRow<T> extends StatelessWidget {
  const AuthChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ChoiceTile(
              title: options[i].$2,
              subtitle: options[i].$3,
              selected: options[i].$1 == value,
              onTap: () => onChanged(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Tokens.fast,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? Tokens.surfaceAlt : Tokens.bg,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(
              color: selected ? Tokens.ink : Tokens.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.smallStrong.copyWith(color: Tokens.text),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: Tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
