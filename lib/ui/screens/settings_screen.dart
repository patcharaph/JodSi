import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../widgets/link_account_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isAnonymous = ref.watch(isAnonymousProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
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
                      user?.displayName ?? 'ผู้ใช้ไม่ระบุชื่อ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    loading: () => const Text('กำลังโหลด...'),
                    error: (_, __) => const Text('ผู้ใช้ไม่ระบุชื่อ'),
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
                        label: const Text('เชื่อมบัญชี'),
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
                    'การใช้งาน',
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
                              const Text('แพลน'),
                              _PlanBadge(plan: user?.plan ?? 'free'),
                            ],
                          ),
                          const Gap(8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('จำกัดต่อครั้ง'),
                              Text('$limit นาที'),
                            ],
                          ),
                          const Gap(8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ใช้ไปเดือนนี้'),
                              Text('$used นาที'),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('ไม่สามารถโหลดข้อมูลได้'),
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
                        'คุณยังไม่ได้เชื่อมบัญชี หากลบแอปหรือเปลี่ยนเครื่อง โน้ตทั้งหมดจะหายไป',
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
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('เวอร์ชัน'),
                  trailing: const Text(AppConfig.appVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('ออกจากระบบ'),
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
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text(
          'หากคุณเป็นผู้ใช้ Anonymous ข้อมูลทั้งหมดจะหายไป',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
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
