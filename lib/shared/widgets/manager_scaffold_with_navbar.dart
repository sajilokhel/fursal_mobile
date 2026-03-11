import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';

class ManagerScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ManagerScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  // Visual order: Home, Bookings, [ScanQR center], Payments, My Venue
  // Maps visual position → branch index
  static const _branchAtVisual = [0, 1, 4, 2, 3];

  @override
  Widget build(BuildContext context) {
    final currentBranch = navigationShell.currentIndex;
    final currentVisual = _branchAtVisual.indexOf(currentBranch);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: false,
      // backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: navigationShell,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: currentVisual == 0,
                onTap: () => _go(0),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Bookings',
                selected: currentVisual == 1,
                onTap: () => _go(1),
              ),
              // Center QR button
              Expanded(
                child: GestureDetector(
                  onTap: () => _go(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              Color(0xFFD44F0A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          currentVisual == 2
                              ? Icons.qr_code_scanner
                              : Icons.qr_code_scanner_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.payment_outlined,
                activeIcon: Icons.payment,
                label: 'Payments',
                selected: currentVisual == 3,
                onTap: () => _go(3),
              ),
              _NavItem(
                icon: Icons.store_mall_directory_outlined,
                activeIcon: Icons.store_mall_directory,
                label: 'My Venue',
                selected: currentVisual == 4,
                onTap: () => _go(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(int visualIndex) {
    final branch = _branchAtVisual[visualIndex];
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppTheme.primaryColor : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
