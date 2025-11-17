import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'service_providers.dart';

// Current User Provider
final currentUserProvider = StateProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.getCurrentUser();
});

// Is Logged In Provider
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.data(null)) {
    _checkAuth();
  }

  void _checkAuth() {
    final authService = ref.read(authServiceProvider);
    final user = authService.getCurrentUser();
    state = AsyncValue.data(user);
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final authResponse = await authService.register(
        email: email,
        username: username,
        password: password,
      );
      final user = User(
        id: authResponse.userId,
        email: authResponse.email,
        username: authResponse.username,
      );
      state = AsyncValue.data(user);
      ref.read(currentUserProvider.notifier).state = user;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final authResponse = await authService.login(
        email: email,
        password: password,
      );
      final user = User(
        id: authResponse.userId,
        email: authResponse.email,
        username: authResponse.username,
      );
      state = AsyncValue.data(user);
      ref.read(currentUserProvider.notifier).state = user;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AsyncValue.data(null);
    ref.read(currentUserProvider.notifier).state = null;
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});
