import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../ui/screens/recorder_screen.dart';
import '../../ui/screens/processing_screen.dart';
import '../../ui/screens/note_detail_screen.dart';
import '../../ui/screens/notes_list_screen.dart';
import '../../ui/screens/settings_screen.dart';
import '../../ui/screens/admin_dashboard_screen.dart';
import '../config/app_config.dart';
import '../config/supabase_config.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RecorderScreen(),
    ),
    GoRoute(
      path: '/processing/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return ProcessingScreen(noteId: noteId);
      },
    ),
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NotesListScreen(),
    ),
    GoRoute(
      path: '/notes/:noteId',
      builder: (context, state) {
        final noteId = state.pathParameters['noteId']!;
        return NoteDetailScreen(noteId: noteId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) {
        final email = SupabaseConfig.client.auth.currentUser?.email;
        final isAdmin = email != null &&
            AppConfig.adminEmails.contains(email.toLowerCase());
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(child: Text('You do not have admin access.')),
          );
        }
        return const AdminDashboardScreen();
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
