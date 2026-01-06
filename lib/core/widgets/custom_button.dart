// core/widgets/custom_button.dart
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;  // ← nullable
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final bool isOutlined;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.isOutlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = backgroundColor ?? theme.colorScheme.primary;
    final Color onPrimaryColor = textColor ?? theme.colorScheme.onPrimary;

    // Use onPrimary for filled, primary for outlined
    final Color contentColor = isOutlined ? primaryColor : onPrimaryColor;

    final Widget child = isLoading
        ? SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(contentColor),
      ),
    )
        : Text(
      text,
      style: TextStyle(
        color: contentColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    // Use MaterialStateProperty for consistent styling
    return isOutlined
        ? OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: primaryColor, width: 2),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 48), // Let parent control width
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    )
        : ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        shape: shape,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }
}