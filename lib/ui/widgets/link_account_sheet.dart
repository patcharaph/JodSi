import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/service_providers.dart';
import '../../providers/locale_provider.dart';
import 'package:gap/gap.dart';

class LinkAccountSheet extends ConsumerWidget {
  const LinkAccountSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LinkAccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(24),
          const Icon(
            Icons.link_rounded,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const Gap(16),
          Text(
            ref.read(localeProvider).linkAccountTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Gap(8),
          Text(
            ref.read(localeProvider).linkAccountDesc,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(24),

          // LINE Login
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _linkLine(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06C755),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 20),
              label: Text(ref.read(localeProvider).loginWithLine),
            ),
          ),
          const Gap(12),

          // Google Sign-in
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _linkGoogle(context, ref),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.dividerColor),
              ),
              icon: const Icon(Icons.g_mobiledata_rounded,
                  size: 24, color: AppTheme.textPrimary),
              label: Text(
                ref.read(localeProvider).loginWithGoogle,
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ),
          const Gap(12),

          // Skip
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              ref.read(localeProvider).skipForNow,
              style: const TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void _linkLine(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).linkWithLine();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(localeProvider).lineLoginError(e.toString()))),
        );
      }
    }
  }

  void _linkGoogle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).linkWithGoogle();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(localeProvider).googleLoginError(e.toString()))),
        );
      }
    }
  }
}
