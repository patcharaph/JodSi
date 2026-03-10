import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/service_providers.dart';
import '../../providers/locale_provider.dart';
import 'package:gap/gap.dart';

class LinkAccountSheet extends ConsumerStatefulWidget {
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
  ConsumerState<LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends ConsumerState<LinkAccountSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showEmailForm = false;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(localeProvider);

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
            l10n.linkAccountTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Gap(8),
          Text(
            l10n.linkAccountDesc,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(24),

          if (_showEmailForm) ...[
            // Email/Password form
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                prefixIcon: const Icon(Icons.email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                prefixIcon: const Icon(Icons.lock_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const Gap(8),
              Text(
                _errorText!,
                style: const TextStyle(
                    color: AppTheme.errorColor, fontSize: 13),
              ),
            ],
            const Gap(16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.loginWithEmail),
              ),
            ),
            const Gap(8),
            TextButton(
              onPressed: () => setState(() {
                _showEmailForm = false;
                _errorText = null;
              }),
              child: Text(l10n.back,
                  style: const TextStyle(color: AppTheme.textTertiary)),
            ),
          ] else ...[
            // Email Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showEmailForm = true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.email_rounded, size: 20),
                label: Text(l10n.loginWithEmail),
              ),
            ),
            const Gap(12),

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
                label: Text(l10n.loginWithLine),
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
                  l10n.loginWithGoogle,
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            ),
            const Gap(12),

            // Skip
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.skipForNow,
                style: const TextStyle(color: AppTheme.textTertiary),
              ),
            ),
          ],
          const Gap(8),
        ],
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = ref.read(localeProvider).emailPasswordRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithEmail(
            email: email,
            password: password,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = ref.read(localeProvider).emailLoginError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
