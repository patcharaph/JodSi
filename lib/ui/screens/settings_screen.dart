import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../widgets/link_account_sheet.dart';
import '../widgets/feedback_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isAnonymous = ref.watch(isAnonymousProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(localeProvider).settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryLight,
                    child: userAsync.when(
                      data: (user) {
                        if (user?.avatarUrl != null) {
                          return ClipOval(
                            child: Image.network(
                              user!.avatarUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return const Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: AppTheme.primaryColor,
                        );
                      },
                      loading: () => const CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                      error: (_, __) => const Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const Gap(12),
                  userAsync.when(
                    data: (user) => Text(
                      user?.displayName ?? ref.read(localeProvider).anonymousUser,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    loading: () => Text(ref.read(localeProvider).loading),
                    error: (_, __) => Text(ref.read(localeProvider).anonymousUser),
                  ),
                  const Gap(4),
                  _IdentityBadge(isAnonymous: isAnonymous),
                  if (isAnonymous) ...[
                    const Gap(16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => LinkAccountSheet.show(context),
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: Text(ref.read(localeProvider).linkAccount),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Gap(16),

          // Usage card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.read(localeProvider).usage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(12),
                  userAsync.when(
                    data: (user) {
                      final used = user?.usageMinMonth ?? 0;
                      final limit = user?.maxRecordingMinutes ?? 15;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ref.read(localeProvider).plan),
                              _PlanBadge(plan: user?.plan ?? 'free'),
                            ],
                          ),
                          const Gap(8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ref.read(localeProvider).limitPerSession),
                              Text(ref.read(localeProvider).minutes(limit)),
                            ],
                          ),
                          const Gap(8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ref.read(localeProvider).usedThisMonth),
                              Text(ref.read(localeProvider).minutes(used)),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text(ref.read(localeProvider).cannotLoadData),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),

          // Warning for anonymous users
          if (isAnonymous)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        ref.read(localeProvider).anonymousWarning,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Gap(16),

          // App info
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(ref.read(localeProvider).languageSetting),
                  trailing: Text(ref.watch(localeProvider).languageLabel),
                  onTap: () {
                    ref.read(localeProvider.notifier).toggle();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_rounded),
                  title: Text(ref.read(localeProvider).feedback),
                  onTap: () => FeedbackSheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded),
                  title: Text(ref.read(localeProvider).adminDashboard),
                  onTap: () => context.push('/admin'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(ref.read(localeProvider).version),
                  trailing: const Text(AppConfig.appVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(ref.read(localeProvider).signOut),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ref.read(localeProvider);
        return AlertDialog(
          title: Text(l10n.signOutTitle),
          content: Text(l10n.signOutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: Text(l10n.signOut),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/');
    }
  }
}

class _IdentityBadge extends StatelessWidget {
  final bool isAnonymous;
  const _IdentityBadge({required this.isAnonymous});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAnonymous ? Colors.grey.shade100 : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAnonymous ? 'Anonymous' : 'Linked',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isAnonymous ? AppTheme.textTertiary : AppTheme.primaryDark,
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isPro = plan == 'pro';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro ? AppTheme.primaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPro ? 'Pro' : 'Free',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPro ? Colors.white : AppTheme.textTertiary,
        ),
      ),
    );
  }
}
