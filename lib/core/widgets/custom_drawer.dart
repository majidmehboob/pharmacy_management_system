import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';

// Collapsed state provider
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class CustomDrawer extends ConsumerWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final GoRouterState routerState = GoRouterState.of(context);
    final currentRoute = routerState.matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 70 : 250,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Logo area
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const FaIcon(
                  FontAwesomeIcons.houseMedical,
                  color: AppColors.accent,
                  size: 28,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PharmaSuite',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.house,
                  label: 'Dashboard',
                  route: '/dashboard',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.pills,
                  label: 'Inventory',
                  route: '/inventory',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.filePrescription,
                  label: 'Prescriptions',
                  route: '/prescriptions',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.cashRegister,
                  label: 'Sales (POS)',
                  route: '/sales/pos',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.chartSimple,
                  label: 'Reports',
                  route: '/reports',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: FontAwesomeIcons.gear,
                  label: 'Settings',
                  route: '/settings',
                  currentRoute: currentRoute,
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),
          // Collapse Toggle Button
          const Divider(color: Colors.white12, height: 1),
          InkWell(
            onTap: () {
              ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: FaIcon(
                isCollapsed ? FontAwesomeIcons.angleRight : FontAwesomeIcons.angleLeft,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required FaIconData icon,
    required String label,
    required String route,
    required String currentRoute,
    required bool isCollapsed,
  }) {
    // Exact or prefix match for routes (e.g. /inventory/add matches /inventory)
    final bool isSelected = currentRoute == route || 
        (route != '/dashboard' && route != '/reports' && route != '/settings' && currentRoute.startsWith(route));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: isCollapsed ? label : '',
        // alignment: Alignment.centerRight,
        child: InkWell(
          onTap: () {
            context.go(route);
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isCollapsed ? 0 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? const Border(left: BorderSide(color: AppColors.accent, width: 4))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                FaIcon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
