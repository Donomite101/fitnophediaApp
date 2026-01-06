import 'package:flutter/material.dart';
import '../app_theme.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final TextInputAction? textInputAction;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hintText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.white54 : Colors.black54;
    final Color fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          validator: widget.validator,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: widget.hintText,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppTheme.primaryGreen)
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.primaryGreen,
              ),
              onPressed: () =>
                  setState(() => _obscureText = !_obscureText),
            )
                : (widget.suffixIcon != null
                ? Icon(widget.suffixIcon, color: AppTheme.primaryGreen)
                : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppTheme.primaryGreen, width: 2),
            ),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          ),
        ),
      ],
    );
  }
}
