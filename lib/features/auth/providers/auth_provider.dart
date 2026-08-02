import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/user_model.dart';
import '../../inventory/providers/inventory_provider.dart';

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final DatabaseHelper _dbHelper;

  AuthNotifier(this._dbHelper)
      : super(
          AuthState(
            user: null,
            isAuthenticated: false,
          ),
        );

  Future<bool> login(String username, String password) async {
    final u = username.trim();
    final p = password.trim();

    if (u.isEmpty || p.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter username and password');
      return false;
    }

    try {
      // Authenticate against database users table
      final userMap = await _dbHelper.authenticateUser(u, p);
      if (userMap != null) {
        final userModel = UserModel.fromJson(userMap);
        state = AuthState(
          user: userModel,
          isAuthenticated: true,
        );

        // Log successful login activity
        await _dbHelper.logActivity(userModel.name, userModel.role, 'User Login', details: 'Logged in as ${userModel.username}');
        return true;
      }

      state = state.copyWith(errorMessage: 'Invalid username or password.');
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Authentication error: ${e.toString()}');
      return false;
    }
  }

  void setCurrentUser(UserModel user) {
    state = AuthState(user: user, isAuthenticated: true);
  }

  void logout() {
    state = AuthState(user: null, isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return AuthNotifier(dbHelper);
});
