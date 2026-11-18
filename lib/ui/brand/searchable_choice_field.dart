import 'package:flutter/material.dart';

import 'brand_theme.dart';
import 'ui_constants.dart';

/// A text field with a filtered list of suggestions (country, city, colours).
///
/// The field edits [controller] directly, so the parent's listeners only fire
/// on real user input. Nothing here writes to the parent's controller while a
/// frame is being built; doing that froze the profile form on the web.
class SearchableChoiceField extends StatelessWidget {
  const SearchableChoiceField({
    super.key,
    required this.controller,
    required this.options,
    this.onChanged,
    this.enabled = true,
    this.hint = '',
    this.label,
    this.flat = false,
  });

  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String hint;
  final String? label;

  /// v2 look: the app theme's hairline field and a plain options list.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    // A new field whenever the choice list or the enabled state changes (for
    // example, the city list after a country is picked): the suggestion list
    // is otherwise only recomputed when the text changes.
    return _SearchableChoiceBody(
      key: ValueKey<int>(Object.hash(enabled, Object.hashAll(options))),
      controller: controller,
      options: options,
      onChanged: onChanged,
      enabled: enabled,
      hint: hint,
      label: label,
      flat: flat,
    );
  }
}

class _SearchableChoiceBody extends StatefulWidget {
  const _SearchableChoiceBody({
    super.key,
    required this.controller,
    required this.options,
    required this.onChanged,
    required this.enabled,
    required this.hint,
    required this.label,
    required this.flat,
  });

  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String hint;
  final String? label;
  final bool flat;

  @override
  State<_SearchableChoiceBody> createState() => _SearchableChoiceBodyState();
}

class _SearchableChoiceBodyState extends State<_SearchableChoiceBody> {
  final FocusNode _focusNode = FocusNode();
  bool _listPrimed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_primeListOnFirstFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_primeListOnFirstFocus);
    _focusNode.dispose();
    super.dispose();
  }

  /// RawAutocomplete builds its list only after the controller reports a
  /// change, so on the first focus nudge the selection and put it back: the
  /// full list then opens without typing.
  void _primeListOnFirstFocus() {
    if (_listPrimed || !_focusNode.hasFocus || !widget.enabled) return;
    _listPrimed = true;
    final controller = widget.controller;
    final value = controller.value;
    controller.value = value.copyWith(
      selection: value.selection.isValid
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection.collapsed(offset: value.text.length),
    );
    controller.value = value;
  }

  Iterable<String> _optionsFor(TextEditingValue value) {
    if (!widget.enabled) return const Iterable<String>.empty();

    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;

    return widget.options.where(
      (option) => option.toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flat = widget.flat;
    final label = widget.label;
    final hint = widget.hint;
    final enabled = widget.enabled;
    final radius = BorderRadius.circular(kSearchRadius);

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: _optionsFor,
      displayStringForOption: (option) => option,
      onSelected: (selection) => widget.onChanged?.call(selection),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, _) {
                final baseDecoration = flat
                    ? InputDecoration(
                        labelText: label,
                        hintText: hint.isEmpty ? null : hint,
                      )
                    : label != null
                    ? InputDecoration(
                        labelText: label,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.94),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: const BorderSide(
                            color: Color(0x22000000),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: const BorderSide(
                            color: Color(0x22000000),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: const BorderSide(
                            color: BrandTheme.redTop,
                            width: 1.2,
                          ),
                        ),
                      )
                    : pillInputDecoration(hint: hint);

                return TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: textEditingController,
                  focusNode: focusNode,
                  enabled: enabled,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => onFieldSubmitted(),
                  style: flat
                      ? AppText.body
                      : const TextStyle(
                          color: kTextDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                  decoration: baseDecoration.copyWith(
                    suffixIcon: !enabled
                        ? const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: kDisabledText,
                          )
                        : value.text.trim().isEmpty
                        ? const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: kTextMid,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: kTextMuted,
                            ),
                            onPressed: () {
                              textEditingController.clear();
                              widget.onChanged?.call('');
                              focusNode.unfocus();
                            },
                          ),
                  ),
                );
              },
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: flat
                  ? BoxDecoration(
                      color: Tokens.bg,
                      borderRadius: BorderRadius.circular(Tokens.radiusMd),
                      border: Border.all(color: Tokens.border),
                      boxShadow: Tokens.popoverShadow,
                    )
                  : catalogDialogDecoration(),
              constraints: const BoxConstraints(maxHeight: 220),
              child: items.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: flat ? Tokens.border : kBorderColor,
                      ),
                      itemBuilder: (context, index) {
                        final option = items[index];
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Text(
                              option,
                              style: flat
                                  ? AppText.small.copyWith(fontSize: 15)
                                  : const TextStyle(
                                      color: kTextDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                      height: 1.12,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
