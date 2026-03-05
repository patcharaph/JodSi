import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/app_user.dart';
import 'service_providers.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  if (!authService.isAuthenticated) return null;
  return authService.getProfile();
});

final isAnonymousProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.isAnonymous;
});
