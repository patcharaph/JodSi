import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class FeedbackSheet extends ConsumerStatefulWidget {
  final String? noteId;

  const FeedbackSheet({super.key, this.noteId});

  static Future<void> show(BuildContext context, {String? noteId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FeedbackSheet(noteId: noteId),
    );
  }

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _messageController = TextEditingController();
  String _selectedType = 'general';
  int? _rating;
  bool _isSubmitting = false;

  final _types = [
    ('general', 'General', Icons.chat_rounded),
    ('bug', 'Bug Report', Icons.bug_report_rounded),
    ('feature', 'Feature Request', Icons.lightbulb_rounded),
    ('quality', 'Quality Feedback', Icons.star_rounded),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localeProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),

          Text(
            l10n.feedbackTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Gap(4),
          Text(
            l10n.feedbackDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Gap(16),

          // Type selector
          Wrap(
            spacing: 8,
            children: _types.map((t) {
              final isSelected = _selectedType == t.$1;
              return ChoiceChip(
                avatar: Icon(t.$3, size: 18),
                label: Text(t.$2),
                selected: isSelected,
                selectedColor: AppTheme.primaryLight,
                onSelected: (_) => setState(() => _selectedType = t.$1),
              );
            }).toList(),
          ),
          const Gap(16),

          // Rating (optional)
          if (_selectedType == 'quality') ...[
            Text(l10n.feedbackRating,
                style: Theme.of(context).textTheme.bodyMedium),
            const Gap(8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= (_rating ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const Gap(8),
          ],

          // Message
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.feedbackHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
          const Gap(16),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.feedbackSubmit),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;
      if (userId == null) return;

      final feedbackService = ref.read(feedbackServiceProvider);
      await feedbackService.submitFeedback(
        userId: userId,
        type: _selectedType,
        message: message,
        noteId: widget.noteId,
        rating: _rating,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(localeProvider).feedbackThanks),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
