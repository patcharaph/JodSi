import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/app_user.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous =>
      currentUser?.isAnonymous ?? true;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInAnonymously() async {
    return await _client.auth.signInAnonymously();
  }

  Future<void> ensureAuthenticated() async {
    if (!isAuthenticated) {
      await signInAnonymously();
    }
  }

  Future<AuthResponse> linkWithGoogle() async {
    // For mobile, use signInWithOAuth or signInWithIdToken
    // This is a placeholder — actual implementation depends on
    // google_sign_in package for getting the ID token
    throw UnimplementedError(
      'Google sign-in requires google_sign_in package setup',
    );
  }

  Future<bool> linkWithLine() async {
    // LINE Login requires LINE SDK setup
    // This is a placeholder for the OAuth flow
    throw UnimplementedError(
      'LINE login requires LINE SDK setup',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AppUser?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  Future<AppUser> ensureProfile() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final existing = await getProfile();
    if (existing != null) return existing;

    // Create profile for new user
    final newUser = AppUser(
      id: userId,
      isAnonymous: isAnonymous,
      createdAt: DateTime.now(),
    );

    await _client.from('users').insert(newUser.toJson());
    return newUser;
  }
}
