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
    return GestureDetector(
      onTap: () => onSelected?.call(label),
      child: Container(
        margin: EdgeInsets.only(right: 10),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          // DIFFERENT UI WHEN SELECTED
          gradient: selected
              ? LinearGradient(
            colors: [
              Colors.green.shade400,
              Colors.blue.shade400,
            ],
          )
              : null,

          color: selected ? null : Colors.grey.shade200,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
