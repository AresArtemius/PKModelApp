import 'package:flutter/material.dart';

import 'brand_theme.dart';
import 'ui_constants.dart';

class SearchableChoiceField extends StatelessWidget {
  const SearchableChoiceField({
    super.key,
    required this.controller,
    required this.options,
    this.onChanged,
    this.enabled = true,
    this.hint = '',
    this.label,
  });

  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String hint;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kSearchRadius);

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        if (!enabled) return const Iterable<String>.empty();

        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return options;

        return options.where((option) => option.toLowerCase().contains(query));
      },
      displayStringForOption: (option) => option,
      onSelected: (selection) {
        controller.text = selection;
        onChanged?.call(selection);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (textEditingController.text != controller.text) {
              textEditingController.value = TextEditingValue(
                text: controller.text,
                selection: TextSelection.collapsed(
                  offset: controller.text.length,
                ),
              );
            }

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, _) {
                controller.value = value;

                final baseDecoration = label != null
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
                  controller: textEditingController,
                  focusNode: focusNode,
                  enabled: enabled,
                  onChanged: (value) {
                    controller.text = value;
                    onChanged?.call(value);
                  },
                  style: const TextStyle(
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
                              controller.clear();
                              textEditingController.clear();
                              onChanged?.call('');
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
              decoration: catalogDialogDecoration(),
              constraints: const BoxConstraints(maxHeight: 220),
              child: items.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: kBorderColor),
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
                              style: const TextStyle(
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
