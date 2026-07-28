import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseHelperProvider);
      final list = await db.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user accounts: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showAddEditUserDialog([UserModel? user]) {
    final isEdit = user != null;
    final usernameController = TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final nameController = TextEditingController(text: user?.name ?? '');
    String selectedRole = user?.role ?? 'Pharmacist';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit User Account (${user.name})' : 'Add New Staff User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        hintText: 'e.g. admin, pharmacist',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Dr. Majid Mehboob',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'New Password (optional)' : 'Password *',
                        hintText: isEdit ? 'Leave blank to keep existing password' : 'Enter password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role *'),
                      items: const [
                        DropdownMenuItem(value: 'Admin', child: Text('Admin (Full Access)')),
                        DropdownMenuItem(value: 'Pharmacist', child: Text('Pharmacist (Inventory & Prescriptions)')),
                        DropdownMenuItem(value: 'Cashier', child: Text('Cashier (POS Sales & Checkout)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final uname = usernameController.text.trim();
                          final name = nameController.text.trim();
                          final pwd = passwordController.text.trim();

                          if (uname.isEmpty || name.isEmpty || (!isEdit && pwd.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all required fields.'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final db = ref.read(databaseHelperProvider);
                            final currentUser = ref.read(authProvider).user;

                            if (isEdit) {
                              final updated = UserModel(id: user.id, username: uname, name: name, role: selectedRole);
                              await db.updateUser(updated, newPassword: pwd.isEmpty ? null : pwd);

                              // Update active session if editing current logged-in user
                              if (currentUser?.id == user.id || currentUser?.username.toLowerCase() == user.username.toLowerCase()) {
                                ref.read(authProvider.notifier).setCurrentUser(updated);
                              }

                              await db.logActivity(currentUser?.name ?? 'Admin', currentUser?.role ?? 'Admin', 'Updated User Account', details: 'Updated user: $uname ($selectedRole)');
                            } else {
                              final newUser = UserModel(
                                id: const Uuid().v4(),
                                username: uname,
                                name: name,
                                role: selectedRole,
                              );
                              await db.insertUser(newUser, pwd);
                              await db.logActivity(currentUser?.name ?? 'Admin', currentUser?.role ?? 'Admin', 'Created User Account', details: 'Added user: $uname ($selectedRole)');
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              await _loadUsers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'User updated successfully' : 'User created successfully'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save user: ${e.toString()}'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update User' : 'Create User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteUser(UserModel u) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User Account'),
          content: Text('Are you sure you want to delete account ${u.name} (${u.username})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final db = ref.read(databaseHelperProvider);
                  await db.deleteUser(u.id);
                  Navigator.pop(context);
                  await _loadUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User ${u.username} deleted successfully.')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete user: ${e.toString()}'), backgroundColor: AppColors.danger),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final isAdmin = currentUser?.role == 'Admin';

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text('Access Restricted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Only Administrators can access User Account Management.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Accounts & Access Control',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditUserDialog(),
                  icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14),
                  label: const Text('Add Staff User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Users Table Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 16)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadUsers,
                                  child: const Text('Retry Loading Users'),
                                ),
                              ],
                            ),
                          )
                        : _users.isEmpty
                            ? const Center(child: Text('No users found in database.'))
                            : SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(AppColors.background),
                                  columns: const [
                                    DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _users.map((u) {
                                    final isSelf = currentUser?.id == u.id || currentUser?.username == u.username;

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              if (isSelf) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('You', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(u.username)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: u.role == 'Admin'
                                                  ? AppColors.primary.withOpacity(0.1)
                                                  : u.role == 'Pharmacist'
                                                      ? AppColors.secondary.withOpacity(0.1)
                                                      : AppColors.accent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              u.role,
                                              style: TextStyle(
                                                color: u.role == 'Admin'
                                                    ? AppColors.primary
                                                    : u.role == 'Pharmacist'
                                                        ? AppColors.secondary
                                                        : AppColors.accent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14, color: AppColors.secondary),
                                                onPressed: () => _showAddEditUserDialog(u),
                                                tooltip: 'Edit User Credentials & Role',
                                              ),
                                              if (!isSelf)
                                                IconButton(
                                                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: AppColors.danger),
                                                  onPressed: () => _confirmDeleteUser(u),
                                                  tooltip: 'Delete User Account',
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
