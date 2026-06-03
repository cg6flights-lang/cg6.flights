import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/messages/data/messages_repository.dart';
import 'package:cg6_flights/features/users/data/users_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageComposeDialog extends ConsumerStatefulWidget {
  const MessageComposeDialog({
    super.key,
    this.initialRecipientId,
    this.initialBody,
  });

  final String? initialRecipientId;
  final String? initialBody;

  @override
  ConsumerState<MessageComposeDialog> createState() =>
      _MessageComposeDialogState();
}

class _MessageComposeDialogState extends ConsumerState<MessageComposeDialog> {
  String? _recipientId;
  late final TextEditingController _bodyCtrl;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recipientId = widget.initialRecipientId;
    _bodyCtrl = TextEditingController(text: widget.initialBody ?? '');
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionControllerProvider);
    final userId = session.user?.id;
    final recipientId = _recipientId;
    final body = _bodyCtrl.text.trim();

    if (userId == null) return;
    if (recipientId == null || recipientId.isEmpty) {
      setState(() => _error = l10n.t('messages.recipientRequired'));
      return;
    }
    if (body.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final result = await ref
        .read(messagesRepositoryProvider)
        .sendMessage(senderId: userId, recipientId: recipientId, body: body);

    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        Navigator.of(context).pop(true);
      case AppFailure<void>(error: final error):
        setState(() {
          _sending = false;
          _error = error.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usersAsync = ref.watch(_usersProvider);
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: scheme.primary),
          const SizedBox(width: 10),
          Text(l10n.t('messages.newChat')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              usersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(l10n.t('messages.loadFailed')),
                data: (users) {
                  final options = users
                      .where((user) => user.id != currentUserId)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _recipientId,
                    decoration: InputDecoration(
                      labelText: l10n.t('messages.to'),
                      hintText: l10n.t('messages.recipientHint'),
                    ),
                    items: [
                      for (final user in options)
                        DropdownMenuItem(
                          value: user.id,
                          child: Text(
                            user.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _sending
                        ? null
                        : (value) => setState(() => _recipientId = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                enabled: !_sending,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.t('messages.body'),
                  hintText: l10n.t('messages.replyHint'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            _sending ? l10n.t('messages.sending') : l10n.t('messages.send'),
          ),
        ),
      ],
    );
  }
}

final _usersProvider = FutureProvider<List<_UserOption>>((ref) async {
  final repo = ref.read(usersRepositoryProvider);
  final result = await repo.listProfiles();
  if (result case AppSuccess(data: final profiles)) {
    return profiles
        .map(
          (profile) => _UserOption(
            id: profile.id,
            displayName: profile.displayName,
            unitName: profile.unitName,
          ),
        )
        .toList();
  }
  return [];
});

class _UserOption {
  const _UserOption({
    required this.id,
    required this.displayName,
    this.unitName,
  });

  final String id;
  final String displayName;
  final String? unitName;

  String get label => unitName == null || unitName!.isEmpty
      ? displayName
      : '$displayName · $unitName';
}
