import 'package:flutter/material.dart';

/// Labelled text field used across auth + profile forms.
class HlopplTextField extends StatelessWidget {
  const HlopplTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.inputPrefixText,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;

  /// Inline non-editable prefix, e.g. a country dial code like "+91".
  final String? inputPrefixText;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            prefixText: inputPrefixText != null ? '$inputPrefixText ' : null,
            prefixStyle: Theme.of(context).textTheme.bodyLarge,
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
