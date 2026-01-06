import 'package:flutter/material.dart';

class ExerciseCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(String)? onSelected;

  const ExerciseCategoryChip({
    Key? key,
    required this.label,
    this.selected = false,
    this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onSelected?.call(label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected 
              ? const Color(0xFF00E676) 
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
          border: Border.all(
            color: selected 
                ? const Color(0xFF00E676) 
                : (isDark ? Colors.white10 : Colors.transparent),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            color: selected 
                ? Colors.black 
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
