import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';

class AppSidebar extends StatelessWidget {
  final String? displayName;
  final String? email;
  final String? photoURL;

  const AppSidebar({
    super.key,
    this.displayName,
    this.email,
    this.photoURL,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (displayName?.isNotEmpty == true ? displayName! : 'U')
        .substring(0, 1)
        .toUpperCase();

    return Drawer(
      width: 285,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFFD44F0A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sports_soccer,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SajiloKhel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // User row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: photoURL != null
                          ? NetworkImage(photoURL!)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      child: photoURL == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email != null)
                            Text(
                              email!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Menu Items ───────────────────────────────────────
          _SidebarItem(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile/edit');
            },
          ),
          _SidebarItem(
            icon: Icons.lock_reset_outlined,
            title: 'Reset Password',
            onTap: () {
              Navigator.of(context).pop();
              _showResetPasswordDialog(context);
            },
          ),
          _SidebarItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile/help');
            },
          ),
          _SidebarItem(
            icon: Icons.cancel_outlined,
            title: 'Cancel & Refund',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/profile/cancel-refund');
            },
          ),

          const Spacer(),
          const Divider(height: 1),

          _SidebarItem(
            icon: Icons.logout,
            title: 'Logout',
            color: Colors.red,
            onTap: () {
              Navigator.of(context).pop();
              FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context) {
    final userEmail = email;
    if (userEmail == null || userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No email address found for this account.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('A password reset link will be sent to:\n$userEmail'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: userEmail);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: color == null
          ? Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20)
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
