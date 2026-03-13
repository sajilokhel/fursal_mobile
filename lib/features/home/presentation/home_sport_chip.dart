import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sport_types.dart';
export '../../../core/sport_types.dart'
    show SportItem, kAllSports, kFeaturedSports, sportItemById, sportDisplayName, sportEmoji;

/// Featured sports shown as quick-access chips (5 items).
/// Use [kAllSports] when you need the full list of 15 sport types.
const List<SportItem> kSportItems = kFeaturedSports;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(25),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              sport.emoji,
              style: const TextStyle(
                fontSize: 18,
                height: 0.8,
              ),
            ),
            const SizedBox( width: 8),
            Text(
              sport.name,
              style: TextStyle(
                fontSize: 12,
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
