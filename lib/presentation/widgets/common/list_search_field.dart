import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Compact search field shared by list screens (chats, characters).
class ListSearchField extends StatelessWidget {
  const ListSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.suffix,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: ChromeControls.fieldHeight,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            prefixIcon: const Icon(Icons.search, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: ChromeControls.fieldHeight,
              minHeight: ChromeControls.fieldHeight,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minHeight: ChromeControls.fieldHeight,
            ),
          ),
        ),
      ),
    );
  }
}
