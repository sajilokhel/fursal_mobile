import 'package:flutter/material.dart';
import '../../domain/venue.dart';
import '../../../../core/theme.dart';
import '../../../../core/sport_types.dart';

class VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onSeeDetails;
  final VoidCallback onViewOnMap;

  const VenueCard({
    super.key,
    required this.venue,
    required this.onSeeDetails,
    required this.onViewOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSeeDetails,
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
          // Image Section (Left)
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey.shade100,
                    child: venue.imageUrls.isNotEmpty
                        ? Image.network(
                            venue.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.sports_soccer,
                              size: 40,
                              color: Colors.grey.shade300,
                            ),
                          )
                        : Icon(
                            Icons.sports_soccer,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Info Section (Right)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 16, color: AppTheme.secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        venue.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${venue.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.address ?? 'Address not available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_outlined,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${sportEmoji(venue.sportType)} ${sportDisplayName(venue.sportType)}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.0,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Rs. ${venue.pricePerHour.toInt()}/hr',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 14, 13, 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _OverlayButton(
                          text: 'Map',
                          icon: Icons.location_on,
                          onTap: onViewOnMap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OverlayButton(
                          text: 'Book Now',
                          onTap: onSeeDetails,
                          // icon: Icons.arrow_forward,
                          backgroundColor: AppTheme.primaryColor,
                        
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _OverlayButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? backgroundColor; 

  const _OverlayButton({
    required this.text,
    this.icon,
    required this.onTap,
    this.backgroundColor, 
  });

  @override
  Widget build(BuildContext context) {
    final Color finalBgColor = backgroundColor ?? 
        (icon != null ? const Color(0xFF1F1F1F) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: finalBgColor, // 4. Use the calculated color here
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: Colors.white,), // Example: Adjusted for visibility
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                // Ensure text remains readable against the background
                color: finalBgColor == Colors.white ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}