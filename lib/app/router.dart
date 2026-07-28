import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/custom_drawer.dart';
import '../core/widgets/custom_appbar.dart';
import '../features/auth/providers/auth_provider.dart';

// Screens
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/inventory/screens/inventory_list_screen.dart';
import '../features/inventory/screens/add_edit_medicine_screen.dart';
import '../features/prescription/screens/prescription_list_screen.dart';
import '../features/prescription/screens/create_prescription_screen.dart';
import '../features/prescription/screens/prescription_detail_screen.dart';
import '../features/sales/screens/pos_screen.dart';
import '../features/sales/screens/sales_history_screen.dart';
import '../features/sales/screens/invoice_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/users/screens/user_management_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class ShellLayout extends StatelessWidget {
  final Widget child;
  const ShellLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final GoRouterState routerState = GoRouterState.of(context);
    final String path = routerState.matchedLocation;
    String title = 'Pharmacy Management System';

    if (path.startsWith('/dashboard')) title = 'Pharmacy Dashboard';
    if (path.startsWith('/inventory')) title = 'Medicine Inventory';
    if (path.startsWith('/prescriptions')) title = 'Prescription Management';
    if (path.startsWith('/sales/pos')) title = 'Point of Sale (POS)';
    if (path.startsWith('/sales/history')) title = 'Sales Transactions';
    if (path.startsWith('/sales/invoice')) title = 'Sale Invoice';
    if (path.startsWith('/reports')) title = 'Reports & Analytics';
    if (path.startsWith('/settings')) title = 'System Settings';
    if (path.startsWith('/users')) title = 'User Accounts & Roles';

    return Scaffold(
      body: Row(
        children: [
          const CustomDrawer(),
          Expanded(
            child: Column(
              children: [
                CustomAppBar(title: title),
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login';

      if (!authState.isAuthenticated && !loggingIn) {
        return '/login';
      }
      if (authState.isAuthenticated && loggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ShellLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          
          // Inventory
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddEditMedicineScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  return AddEditMedicineScreen(medicineId: id);
                },
              ),
            ],
          ),

          // Prescriptions
          GoRoute(
            path: '/prescriptions',
            builder: (context, state) => const PrescriptionListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreatePrescriptionScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return PrescriptionDetailScreen(prescriptionId: id);
                },
              ),
            ],
          ),

          // Sales
          GoRoute(
            path: '/sales/pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/sales/history',
            builder: (context, state) => const SalesHistoryScreen(),
          ),
          GoRoute(
            path: '/sales/invoice/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return InvoiceScreen(saleId: id);
            },
          ),

          // Reports, Settings & User Management
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
        ],
      ),
    ],
  );
});

final goRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
  ],
);
