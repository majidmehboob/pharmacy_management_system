import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class CustomAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String title;
  const CustomAppBar({super.key, this.title = 'Pharmacy Management System'});

  @override
  ConsumerState<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _CustomAppBarState extends ConsumerState<CustomAppBar> {
  late Timer _timer;
  late String _timeString;

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formatted = _formatDateTime(now);
    if (mounted) {
      setState(() {
        _timeString = formatted;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('EEE, MMM d, yyyy • hh:mm:ss a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          // Right: Real-time Clock, Notifications, Profile & Logout
          Row(
            children: [
              // Date-Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.clock,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeString,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Notification Bell
              Stack(
                children: [
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.bell,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications: All systems operating normally.')),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const VerticalDivider(color: AppColors.border, width: 1, indent: 20, endIndent: 20),
              const SizedBox(width: 16),

              // Active User Info & Menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Role: ${user?.role ?? "User"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          user?.role ?? 'Role',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
