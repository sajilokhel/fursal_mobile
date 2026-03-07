import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class SportItem {
  final String name;
  final String emoji;

  const SportItem({required this.name, required this.emoji});
}

const List<SportItem> kSportItems = [
  SportItem(name: 'Futsal', emoji: '⚽'),
  SportItem(name: 'Badminton', emoji: '🏸'),
  SportItem(name: 'Cricket', emoji: '🏏'),
  SportItem(name: 'Basketball', emoji: '🏀'),
  SportItem(name: 'Table Tennis', emoji: '🏓'),
];

class HomeSportChip extends StatelessWidget {
  final SportItem sport;
  final bool isSelected;
  final VoidCallback onTap;

  const HomeSportChip({
    super.key,
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(sport.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              sport.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
