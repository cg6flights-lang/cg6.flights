import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/features/messages/data/messages_repository.dart';
import 'package:cg6_flights/features/messages/domain/message.dart';
import 'package:cg6_flights/features/messages/domain/message_post.dart';
import 'package:cg6_flights/features/messages/presentation/message_compose_dialog.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/features/users/data/users_repository.dart';
import 'package:cg6_flights/features/users/domain/managed_profile.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _messagesRealtimeProvider = StreamProvider.autoDispose
    .family<AppResult<List<Message>>, String>(
      (ref, userId) =>
          ref.read(messagesRepositoryProvider).watchMessages(userId),
    );

final _messageReadsProvider =
    StreamProvider.autoDispose<AppResult<List<MessageRead>>>(
      (ref) => ref.read(messagesRepositoryProvider).watchMessageReads(),
    );

final _messagePostsProvider =
    StreamProvider.autoDispose<AppResult<List<MessagePost>>>(
      (ref) => ref.read(messagesRepositoryProvider).watchPosts(),
    );

final _messagePostCommentsProvider =
    StreamProvider.autoDispose<AppResult<List<MessagePostComment>>>(
      (ref) => ref.read(messagesRepositoryProvider).watchPostComments(),
    );

final _messagePostReadsProvider =
    StreamProvider.autoDispose<AppResult<List<MessagePostRead>>>(
      (ref) => ref.read(messagesRepositoryProvider).watchPostReads(),
    );

final _messageProfilesProvider =
    FutureProvider.autoDispose<AppResult<Map<String, ManagedProfile>>>((
      ref,
    ) async {
      final result = await ref.read(usersRepositoryProvider).listProfiles();
      return switch (result) {
        AppSuccess<List<ManagedProfile>>(data: final profiles) => AppSuccess({
          for (final profile in profiles)
            if (profile.status == ProfileStatus.active) profile.id: profile,
        }),
        AppFailure<List<ManagedProfile>>(error: final error) => AppFailure(
          error,
        ),
      };
    });

final _messageUnitsProvider =
    FutureProvider.autoDispose<AppResult<Map<String, UnitOption>>>((ref) async {
      final result = await ref.read(usersRepositoryProvider).listUnits();
      return switch (result) {
        AppSuccess<List<UnitOption>>(data: final units) => AppSuccess({
          for (final unit in units)
            if (unit.active) unit.id: unit,
        }),
        AppFailure<List<UnitOption>>(error: final error) => AppFailure(error),
      };
    });

enum _MessagesMode { chat, posts }

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final _searchController = TextEditingController();
  final _chatController = TextEditingController();
  final _postController = TextEditingController();
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _markingMessageIds = {};
  final Set<String> _markingPostIds = {};
  final Set<String> _commentingPostIds = {};

  _MessagesMode _mode = _MessagesMode.chat;
  String? _selectedConversationId;
  MessagePostScope _postScope = MessagePostScope.global;
  String? _postUnitId;
  bool _sendingChat = false;
  bool _posting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _chatController.dispose();
    _postController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openNewChat() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const MessageComposeDialog(),
    );
    if (sent == true && mounted) _refresh();
  }

  void _refresh() {
    final userId = ref.read(sessionControllerProvider).user?.id;
    if (userId != null) ref.invalidate(_messagesRealtimeProvider(userId));
    ref
      ..invalidate(_messageReadsProvider)
      ..invalidate(_messagePostsProvider)
      ..invalidate(_messagePostCommentsProvider)
      ..invalidate(_messagePostReadsProvider)
      ..invalidate(_messageProfilesProvider)
      ..invalidate(_messageUnitsProvider);
  }

  Future<void> _sendChat(_ChatConversation conversation, AppUser user) async {
    final body = _chatController.text.trim();
    if (body.isEmpty || _sendingChat) return;
    setState(() => _sendingChat = true);
    final result = await ref
        .read(messagesRepositoryProvider)
        .sendMessage(
          senderId: user.id,
          recipientId: conversation.counterpartId,
          body: body,
        );
    if (!mounted) return;
    setState(() => _sendingChat = false);
    switch (result) {
      case AppSuccess<void>():
        _chatController.clear();
        _refresh();
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _markConversationRead({
    required _ChatConversation conversation,
    required List<MessageRead> reads,
    required AppUser user,
  }) async {
    final readIds = reads
        .where((read) => read.profileId == user.id)
        .map((read) => read.messageId)
        .toSet();
    final unreadIds = conversation.messages
        .where((message) => message.recipientId == user.id)
        .where((message) => !readIds.contains(message.id))
        .map((message) => message.id)
        .where((id) => !_markingMessageIds.contains(id))
        .toSet();
    if (unreadIds.isEmpty) return;

    _markingMessageIds.addAll(unreadIds);
    final result = await ref
        .read(messagesRepositoryProvider)
        .markMessagesRead(profileId: user.id, messageIds: unreadIds);
    _markingMessageIds.removeAll(unreadIds);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_messageReadsProvider);
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _createPost(AppUser user) async {
    final body = _postController.text.trim();
    if (body.isEmpty || _posting) return;

    final unitId = _postScope == MessagePostScope.global
        ? null
        : (user.role?.isGlobal == true ? _postUnitId : user.unitId);
    if (_postScope == MessagePostScope.unit && unitId == null) {
      _showSnack(AppLocalizations.of(context).t('messages.unitRequired'));
      return;
    }

    setState(() => _posting = true);
    final result = await ref
        .read(messagesRepositoryProvider)
        .createPost(scope: _postScope, unitId: unitId, body: body);
    if (!mounted) return;
    setState(() => _posting = false);
    switch (result) {
      case AppSuccess<void>():
        _postController.clear();
        _refresh();
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _addComment(MessagePost post, AppUser user) async {
    final controller = _commentControllers[post.id];
    final body = controller?.text.trim() ?? '';
    if (body.isEmpty || _commentingPostIds.contains(post.id)) return;

    setState(() => _commentingPostIds.add(post.id));
    final result = await ref
        .read(messagesRepositoryProvider)
        .addPostComment(postId: post.id, body: body);
    if (!mounted) return;
    setState(() => _commentingPostIds.remove(post.id));
    switch (result) {
      case AppSuccess<void>():
        controller?.clear();
        await _markPostRead(post.id, user.id, silent: true);
        _refresh();
      case AppFailure<void>(error: final error):
        _showSnack(error.message);
    }
  }

  Future<void> _markPostRead(
    String postId,
    String profileId, {
    bool silent = false,
  }) async {
    if (_markingPostIds.contains(postId)) return;
    setState(() => _markingPostIds.add(postId));
    final result = await ref
        .read(messagesRepositoryProvider)
        .markPostRead(postId: postId, profileId: profileId);
    if (!mounted) return;
    setState(() => _markingPostIds.remove(postId));
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_messagePostReadsProvider);
      case AppFailure<void>(error: final error):
        if (!silent) _showSnack(error.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (user == null) {
      return DataStateView(
        kind: DataStateKind.permissionDenied,
        title: l10n.t('auth.loginRequired'),
      );
    }

    final messagesAsync = ref.watch(_messagesRealtimeProvider(user.id));
    final readsAsync = ref.watch(_messageReadsProvider);
    final postsAsync = ref.watch(_messagePostsProvider);
    final commentsAsync = ref.watch(_messagePostCommentsProvider);
    final postReadsAsync = ref.watch(_messagePostReadsProvider);
    final profilesAsync = ref.watch(_messageProfilesProvider);
    final unitsAsync = ref.watch(_messageUnitsProvider);

    final messages = _dataOrEmpty(messagesAsync);
    final reads = _dataOrEmpty(readsAsync);
    final posts = _dataOrEmpty(postsAsync);
    final comments = _dataOrEmpty(commentsAsync);
    final postReads = _dataOrEmpty(postReadsAsync);
    final profiles = _dataOrEmpty(profilesAsync);
    final units = _dataOrEmpty(unitsAsync);

    final conversations = _buildConversations(
      messages: messages,
      reads: reads,
      profiles: profiles,
      currentUserId: user.id,
      query: _searchController.text,
    );
    final selectedConversation = _selectedConversation(
      conversations,
      preferFirst: MediaQuery.sizeOf(context).width >= 760,
    );
    if (selectedConversation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _markConversationRead(
            conversation: selectedConversation,
            reads: reads,
            user: user,
          );
        }
      });
    }

    final postViews = _buildPostViews(
      posts: posts,
      comments: comments,
      reads: postReads,
      profiles: profiles,
      units: units,
      currentUserId: user.id,
    );
    final error = _firstError([
      messagesAsync,
      readsAsync,
      postsAsync,
      commentsAsync,
      postReadsAsync,
      profilesAsync,
      unitsAsync,
    ]);
    final isLoading = [
      messagesAsync,
      readsAsync,
      postsAsync,
      commentsAsync,
      postReadsAsync,
      profilesAsync,
      unitsAsync,
    ].any((async) => async.isLoading);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final tablet = constraints.maxWidth >= 760;
              if (!tablet) {
                return _MobileMessagesLayout(
                  mode: _mode,
                  onModeChanged: (mode) => setState(() {
                    _mode = mode;
                    if (mode == _MessagesMode.posts) {
                      _selectedConversationId = null;
                    }
                  }),
                  onRefresh: _refresh,
                  isLoading: isLoading,
                  error: error,
                  canSend: session.can(AppPermission.messagesSend),
                  canCreatePost: session.can(AppPermission.messagePostsCreate),
                  canComment: session.can(AppPermission.messagePostsComment),
                  conversations: conversations,
                  selectedConversation: selectedConversation,
                  onOpenNewChat: _openNewChat,
                  onSelectConversation: (conversation) =>
                      setState(() => _selectedConversationId = conversation.id),
                  onBackToConversations: () =>
                      setState(() => _selectedConversationId = null),
                  chatController: _chatController,
                  sendingChat: _sendingChat,
                  onSendChat: selectedConversation == null
                      ? null
                      : () => _sendChat(selectedConversation, user),
                  searchController: _searchController,
                  onSearchChanged: (_) => setState(() {}),
                  posts: postViews,
                  units: units.values.toList()
                    ..sort((a, b) => a.name.compareTo(b.name)),
                  user: user,
                  postScope: _postScope,
                  postUnitId: _postUnitId,
                  onPostScopeChanged: (scope) => setState(() {
                    _postScope = scope;
                    if (scope == MessagePostScope.global) _postUnitId = null;
                  }),
                  onPostUnitChanged: (unitId) =>
                      setState(() => _postUnitId = unitId),
                  postController: _postController,
                  posting: _posting,
                  onCreatePost: () => _createPost(user),
                  commentControllers: _commentControllers,
                  commentingPostIds: _commentingPostIds,
                  markingPostIds: _markingPostIds,
                  onAddComment: (post) => _addComment(post, user),
                  onMarkPostRead: (post) => _markPostRead(post.id, user.id),
                );
              }

              return Row(
                children: [
                  _ModePanel(
                    mode: _mode,
                    onModeChanged: (mode) => setState(() {
                      _mode = mode;
                      if (mode == _MessagesMode.posts) {
                        _selectedConversationId = null;
                      }
                    }),
                    onRefresh: _refresh,
                    isLoading: isLoading,
                    error: error,
                    canSend: session.can(AppPermission.messagesSend),
                    canCreatePost: session.can(
                      AppPermission.messagePostsCreate,
                    ),
                    unreadCount: conversations.fold<int>(
                      0,
                      (count, conversation) => count + conversation.unreadCount,
                    ),
                  ),
                  if (_mode == _MessagesMode.chat) ...[
                    _PanelDivider(vertical: true),
                    SizedBox(
                      width: wide ? 350 : 310,
                      child: _ConversationListPanel(
                        conversations: conversations,
                        selectedId: selectedConversation?.id,
                        canSend: session.can(AppPermission.messagesSend),
                        searchController: _searchController,
                        onSearchChanged: (_) => setState(() {}),
                        onNewChat: _openNewChat,
                        onSelect: (conversation) => setState(
                          () => _selectedConversationId = conversation.id,
                        ),
                      ),
                    ),
                    _PanelDivider(vertical: true),
                    Expanded(
                      child: _ChatThreadPanel(
                        conversation: selectedConversation,
                        canSend: session.can(AppPermission.messagesSend),
                        currentUser: user,
                        controller: _chatController,
                        sending: _sendingChat,
                        onSend: selectedConversation == null
                            ? null
                            : () => _sendChat(selectedConversation, user),
                      ),
                    ),
                  ] else ...[
                    _PanelDivider(vertical: true),
                    Expanded(
                      child: _PostsPanel(
                        posts: postViews,
                        units: units.values.toList()
                          ..sort((a, b) => a.name.compareTo(b.name)),
                        user: user,
                        canCreate: session.can(
                          AppPermission.messagePostsCreate,
                        ),
                        canComment: session.can(
                          AppPermission.messagePostsComment,
                        ),
                        postScope: _postScope,
                        postUnitId: _postUnitId,
                        onScopeChanged: (scope) => setState(() {
                          _postScope = scope;
                          if (scope == MessagePostScope.global) {
                            _postUnitId = null;
                          }
                        }),
                        onUnitChanged: (unitId) =>
                            setState(() => _postUnitId = unitId),
                        controller: _postController,
                        posting: _posting,
                        onCreate: () => _createPost(user),
                        commentControllers: _commentControllers,
                        commentingPostIds: _commentingPostIds,
                        markingPostIds: _markingPostIds,
                        onAddComment: (post) => _addComment(post, user),
                        onMarkRead: (post) => _markPostRead(post.id, user.id),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  _ChatConversation? _selectedConversation(
    List<_ChatConversation> conversations, {
    required bool preferFirst,
  }) {
    for (final conversation in conversations) {
      if (conversation.id == _selectedConversationId) return conversation;
    }
    if (preferFirst && conversations.isNotEmpty) return conversations.first;
    return null;
  }
}

class _MobileMessagesLayout extends StatelessWidget {
  const _MobileMessagesLayout({
    required this.mode,
    required this.onModeChanged,
    required this.onRefresh,
    required this.isLoading,
    required this.error,
    required this.canSend,
    required this.canCreatePost,
    required this.canComment,
    required this.conversations,
    required this.selectedConversation,
    required this.onOpenNewChat,
    required this.onSelectConversation,
    required this.onBackToConversations,
    required this.chatController,
    required this.sendingChat,
    required this.onSendChat,
    required this.searchController,
    required this.onSearchChanged,
    required this.posts,
    required this.units,
    required this.user,
    required this.postScope,
    required this.postUnitId,
    required this.onPostScopeChanged,
    required this.onPostUnitChanged,
    required this.postController,
    required this.posting,
    required this.onCreatePost,
    required this.commentControllers,
    required this.commentingPostIds,
    required this.markingPostIds,
    required this.onAddComment,
    required this.onMarkPostRead,
  });

  final _MessagesMode mode;
  final ValueChanged<_MessagesMode> onModeChanged;
  final VoidCallback onRefresh;
  final bool isLoading;
  final AppError? error;
  final bool canSend;
  final bool canCreatePost;
  final bool canComment;
  final List<_ChatConversation> conversations;
  final _ChatConversation? selectedConversation;
  final VoidCallback onOpenNewChat;
  final ValueChanged<_ChatConversation> onSelectConversation;
  final VoidCallback onBackToConversations;
  final TextEditingController chatController;
  final bool sendingChat;
  final VoidCallback? onSendChat;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<_PostView> posts;
  final List<UnitOption> units;
  final AppUser user;
  final MessagePostScope postScope;
  final String? postUnitId;
  final ValueChanged<MessagePostScope> onPostScopeChanged;
  final ValueChanged<String?> onPostUnitChanged;
  final TextEditingController postController;
  final bool posting;
  final VoidCallback onCreatePost;
  final Map<String, TextEditingController> commentControllers;
  final Set<String> commentingPostIds;
  final Set<String> markingPostIds;
  final ValueChanged<MessagePost> onAddComment;
  final ValueChanged<MessagePost> onMarkPostRead;

  @override
  Widget build(BuildContext context) {
    final showThread =
        mode == _MessagesMode.chat && selectedConversation != null;
    return Column(
      children: [
        _ModePanel(
          mode: mode,
          onModeChanged: onModeChanged,
          onRefresh: onRefresh,
          isLoading: isLoading,
          error: error,
          canSend: canSend,
          canCreatePost: canCreatePost,
          unreadCount: conversations.fold<int>(
            0,
            (count, conversation) => count + conversation.unreadCount,
          ),
          compact: true,
        ),
        _PanelDivider(vertical: false),
        Expanded(
          child: switch (mode) {
            _MessagesMode.chat when showThread => _ChatThreadPanel(
              conversation: selectedConversation,
              canSend: canSend,
              currentUser: user,
              controller: chatController,
              sending: sendingChat,
              onSend: onSendChat,
              onBack: onBackToConversations,
            ),
            _MessagesMode.chat => _ConversationListPanel(
              conversations: conversations,
              selectedId: selectedConversation?.id,
              canSend: canSend,
              searchController: searchController,
              onSearchChanged: onSearchChanged,
              onNewChat: onOpenNewChat,
              onSelect: onSelectConversation,
            ),
            _MessagesMode.posts => _PostsPanel(
              posts: posts,
              units: units,
              user: user,
              canCreate: canCreatePost,
              canComment: canComment,
              postScope: postScope,
              postUnitId: postUnitId,
              onScopeChanged: onPostScopeChanged,
              onUnitChanged: onPostUnitChanged,
              controller: postController,
              posting: posting,
              onCreate: onCreatePost,
              commentControllers: commentControllers,
              commentingPostIds: commentingPostIds,
              markingPostIds: markingPostIds,
              onAddComment: onAddComment,
              onMarkRead: onMarkPostRead,
            ),
          },
        ),
      ],
    );
  }
}

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.mode,
    required this.onModeChanged,
    required this.onRefresh,
    required this.isLoading,
    required this.error,
    required this.canSend,
    required this.canCreatePost,
    required this.unreadCount,
    this.compact = false,
  });

  final _MessagesMode mode;
  final ValueChanged<_MessagesMode> onModeChanged;
  final VoidCallback onRefresh;
  final bool isLoading;
  final AppError? error;
  final bool canSend;
  final bool canCreatePost;
  final int unreadCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final content = [
      Row(
        children: [
          Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.t('messages.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.t('messages.refresh'),
            onPressed: onRefresh,
            icon: AnimatedRotation(
              turns: isLoading ? 0.5 : 0,
              duration: const Duration(milliseconds: 450),
              child: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ModeButton(
        icon: Icons.chat_bubble_outline,
        label: l10n.t('messages.chat'),
        selected: mode == _MessagesMode.chat,
        badge: unreadCount > 0 ? unreadCount.toString() : null,
        onTap: () => onModeChanged(_MessagesMode.chat),
      ),
      const SizedBox(height: 10),
      _ModeButton(
        icon: Icons.campaign_outlined,
        label: l10n.t('messages.posts'),
        selected: mode == _MessagesMode.posts,
        onTap: () => onModeChanged(_MessagesMode.posts),
      ),
      const SizedBox(height: 18),
      _StatusPill(
        icon: Icons.sensors,
        label: l10n.t('messages.realtimeBadge'),
        color: theme.colorScheme.primary,
      ),
      if (error != null) ...[
        const SizedBox(height: 10),
        _StatusPill(
          icon: Icons.warning_amber_outlined,
          label: error!.message,
          color: theme.colorScheme.error,
        ),
      ],
      const Spacer(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _PermissionChip(
            icon: Icons.send_outlined,
            label: l10n.t('messages.privateChat'),
            active: canSend,
          ),
          _PermissionChip(
            icon: Icons.edit_note_outlined,
            label: l10n.t('messages.postComposer'),
            active: canCreatePost,
          ),
        ],
      ),
    ];

    return SizedBox(
      width: compact ? null : 260,
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: content.take(4).toList(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.72)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badge != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationListPanel extends StatelessWidget {
  const _ConversationListPanel({
    required this.conversations,
    required this.selectedId,
    required this.canSend,
    required this.searchController,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onSelect,
  });

  final List<_ChatConversation> conversations;
  final String? selectedId;
  final bool canSend;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewChat;
  final ValueChanged<_ChatConversation> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('messages.conversations'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canSend)
                IconButton.filledTonal(
                  tooltip: l10n.t('messages.newChat'),
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.t('messages.searchHint'),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: conversations.isEmpty
                ? DataStateView(
                    kind: DataStateKind.empty,
                    title: l10n.t('messages.emptyConversations'),
                    message: l10n.t('messages.noConversationBody'),
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationTile(
                        conversation: conversation,
                        selected:
                            conversation.id == selectedId ||
                            (selectedId == null && index == 0),
                        onTap: () => onSelect(conversation),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final _ChatConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.62)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ProfileAvatar(
                label: conversation.title,
                active: conversation.hasFreshInbound,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          conversation.lastMessage.shortTime,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          _UnreadBadge(count: conversation.unreadCount)
                        else if (conversation.isLastRead)
                          Icon(Icons.done_all, size: 16, color: scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatThreadPanel extends StatelessWidget {
  const _ChatThreadPanel({
    required this.conversation,
    required this.canSend,
    required this.currentUser,
    required this.controller,
    required this.sending,
    required this.onSend,
    this.onBack,
  });

  final _ChatConversation? conversation;
  final bool canSend;
  final AppUser currentUser;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback? onSend;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final conversation = this.conversation;
    if (conversation == null) {
      return DataStateView(
        kind: DataStateKind.empty,
        title: l10n.t('messages.noChat'),
        message: l10n.t('messages.noChatBody'),
      );
    }

    return Column(
      children: [
        _ChatHeader(conversation: conversation, onBack: onBack),
        _PanelDivider(vertical: false),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
            ),
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              itemCount: conversation.messages.length,
              itemBuilder: (context, reverseIndex) {
                final index = conversation.messages.length - 1 - reverseIndex;
                final message = conversation.messages[index];
                return _MessageBubble(
                  message: message,
                  mine: message.senderId == currentUser.id,
                  read: conversation.readMessageIds.contains(message.id),
                );
              },
            ),
          ),
        ),
        _PanelDivider(vertical: false),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: canSend && !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: canSend
                        ? l10n.t('messages.chatHint')
                        : l10n.t('messages.readOnly'),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: canSend && !sending ? onSend : null,
                tooltip: l10n.t('messages.send'),
                icon: sending
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, this.onBack});

  final _ChatConversation conversation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 4),
          ],
          _ProfileAvatar(label: conversation.title, active: true, large: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      icon: Icons.lock_outline,
                      label: l10n.t('messages.privateChat'),
                      color: theme.colorScheme.primary,
                    ),
                    _StatusPill(
                      icon: Icons.circle,
                      label: l10n.t('messages.connected'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.t('messages.profile'),
            onPressed: () => _showProfileSheet(context, conversation),
            icon: const Icon(Icons.badge_outlined),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context, _ChatConversation conversation) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ProfileAvatar(label: conversation.title, active: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      conversation.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ProfileLine(
                label: l10n.t('messages.role'),
                value: conversation.role,
              ),
              _ProfileLine(
                label: l10n.t('messages.unitScope'),
                value: conversation.unitName,
              ),
              _ProfileLine(
                label: l10n.t('messages.email'),
                value: conversation.email,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.read,
  });

  final Message message;
  final bool mine;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(
            left: mine ? 48 : 0,
            right: mine ? 0 : 48,
            top: 5,
            bottom: 5,
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
          decoration: BoxDecoration(
            color: mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.82),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 5),
              bottomRight: Radius.circular(mine ? 5 : 18),
            ),
            border: Border.all(
              color: mine
                  ? scheme.primary.withValues(alpha: 0.25)
                  : scheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.shortTime,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      read ? Icons.done_all : Icons.done,
                      size: 16,
                      color: read ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsPanel extends StatelessWidget {
  const _PostsPanel({
    required this.posts,
    required this.units,
    required this.user,
    required this.canCreate,
    required this.canComment,
    required this.postScope,
    required this.postUnitId,
    required this.onScopeChanged,
    required this.onUnitChanged,
    required this.controller,
    required this.posting,
    required this.onCreate,
    required this.commentControllers,
    required this.commentingPostIds,
    required this.markingPostIds,
    required this.onAddComment,
    required this.onMarkRead,
  });

  final List<_PostView> posts;
  final List<UnitOption> units;
  final AppUser user;
  final bool canCreate;
  final bool canComment;
  final MessagePostScope postScope;
  final String? postUnitId;
  final ValueChanged<MessagePostScope> onScopeChanged;
  final ValueChanged<String?> onUnitChanged;
  final TextEditingController controller;
  final bool posting;
  final VoidCallback onCreate;
  final Map<String, TextEditingController> commentControllers;
  final Set<String> commentingPostIds;
  final Set<String> markingPostIds;
  final ValueChanged<MessagePost> onAddComment;
  final ValueChanged<MessagePost> onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PostsHeader(count: posts.length),
                if (canCreate) ...[
                  const SizedBox(height: 16),
                  _PostComposer(
                    units: units,
                    user: user,
                    scope: postScope,
                    unitId: postUnitId,
                    onScopeChanged: onScopeChanged,
                    onUnitChanged: onUnitChanged,
                    controller: controller,
                    posting: posting,
                    onCreate: onCreate,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DataStateView(
              kind: DataStateKind.empty,
              title: l10n.t('messages.noPosts'),
              message: l10n.t('messages.noPostsBody'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            sliver: SliverList.separated(
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final view = posts[index];
                final controller = commentControllers.putIfAbsent(
                  view.post.id,
                  TextEditingController.new,
                );
                return _PostCard(
                  view: view,
                  canComment: canComment,
                  controller: controller,
                  commenting: commentingPostIds.contains(view.post.id),
                  markingRead: markingPostIds.contains(view.post.id),
                  onAddComment: () => onAddComment(view.post),
                  onMarkRead: () => onMarkRead(view.post),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PostsHeader extends StatelessWidget {
  const _PostsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.campaign_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.t('messages.posts'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _StatusPill(
          icon: Icons.timeline_outlined,
          label: '$count',
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _PostComposer extends StatelessWidget {
  const _PostComposer({
    required this.units,
    required this.user,
    required this.scope,
    required this.unitId,
    required this.onScopeChanged,
    required this.onUnitChanged,
    required this.controller,
    required this.posting,
    required this.onCreate,
  });

  final List<UnitOption> units;
  final AppUser user;
  final MessagePostScope scope;
  final String? unitId;
  final ValueChanged<MessagePostScope> onScopeChanged;
  final ValueChanged<String?> onUnitChanged;
  final TextEditingController controller;
  final bool posting;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final globalUser = user.role?.isGlobal == true;
    final validUnitId = units.any((unit) => unit.id == unitId) ? unitId : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProfileAvatar(label: user.displayName, active: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.t('messages.postComposer'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              enabled: !posting,
              decoration: InputDecoration(
                hintText: l10n.t('messages.postHint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(l10n.t('messages.globalScope')),
                  avatar: const Icon(Icons.public, size: 18),
                  selected: scope == MessagePostScope.global,
                  onSelected: globalUser && !posting
                      ? (_) => onScopeChanged(MessagePostScope.global)
                      : null,
                ),
                ChoiceChip(
                  label: Text(l10n.t('messages.unitScope')),
                  avatar: const Icon(Icons.business_outlined, size: 18),
                  selected: scope == MessagePostScope.unit,
                  onSelected: !posting
                      ? (_) => onScopeChanged(MessagePostScope.unit)
                      : null,
                ),
                if (scope == MessagePostScope.unit && globalUser)
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: validUnitId,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.t('messages.unitScope'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: [
                        for (final unit in units)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text('${unit.code} - ${unit.name}'),
                          ),
                      ],
                      onChanged: posting ? null : onUnitChanged,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: posting ? null : onCreate,
                  icon: posting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(
                    posting
                        ? l10n.t('messages.publishing')
                        : l10n.t('messages.publish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.view,
    required this.canComment,
    required this.controller,
    required this.commenting,
    required this.markingRead,
    required this.onAddComment,
    required this.onMarkRead,
  });

  final _PostView view;
  final bool canComment;
  final TextEditingController controller;
  final bool commenting;
  final bool markingRead;
  final VoidCallback onAddComment;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProfileAvatar(label: view.authorName, active: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${view.authorRole} - ${view.post.shortTime}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  icon: view.post.scope == MessagePostScope.global
                      ? Icons.public
                      : Icons.business_outlined,
                  label: view.scopeLabel(context),
                  color: view.post.scope == MessagePostScope.global
                      ? scheme.primary
                      : scheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(view.post.body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatusPill(
                  icon: Icons.mode_comment_outlined,
                  label: '${view.commentCount} ${l10n.t('messages.comments')}',
                  color: scheme.primary,
                ),
                _StatusPill(
                  icon: Icons.visibility_outlined,
                  label: '${view.readCount} ${l10n.t('messages.reads')}',
                  color: scheme.secondary,
                ),
                if (!view.hasRead)
                  OutlinedButton.icon(
                    onPressed: markingRead ? null : onMarkRead,
                    icon: markingRead
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(l10n.t('messages.confirmRead')),
                  )
                else
                  _StatusPill(
                    icon: Icons.verified_outlined,
                    label: l10n.t('messages.readConfirmed'),
                    color: Colors.green,
                  ),
              ],
            ),
            if (view.comments.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final comment in view.comments.take(6))
                _CommentTile(
                  comment: comment,
                  authorName: view.commentAuthor(comment),
                ),
            ],
            if (canComment) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !commenting,
                      decoration: InputDecoration(
                        hintText: l10n.t('messages.commentHint'),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: commenting ? null : onAddComment,
                    tooltip: l10n.t('messages.comment'),
                    icon: commenting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.reply_outlined),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.authorName});

  final MessagePostComment comment;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileAvatar(label: authorName, small: true),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(comment.body, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.label,
    this.active = false,
    this.large = false,
    this.small = false,
  });

  final String label;
  final bool active;
  final bool large;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = small ? 28.0 : (large ? 48.0 : 42.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
            ),
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: Text(
                Message.initials(label),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            right: -1,
            bottom: -1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: const SizedBox.square(dimension: 12),
            ),
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return _StatusPill(icon: icon, label: label, color: color);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.7);
    return vertical
        ? VerticalDivider(width: 1, thickness: 1, color: color)
        : Divider(height: 1, thickness: 1, color: color);
  }
}

class _ChatConversation {
  const _ChatConversation({
    required this.id,
    required this.counterpartId,
    required this.title,
    required this.subtitle,
    required this.email,
    required this.role,
    required this.unitName,
    required this.messages,
    required this.lastMessage,
    required this.unreadCount,
    required this.hasFreshInbound,
    required this.isLastRead,
    required this.readMessageIds,
    required this.searchText,
  });

  final String id;
  final String counterpartId;
  final String title;
  final String subtitle;
  final String email;
  final String role;
  final String unitName;
  final List<Message> messages;
  final Message lastMessage;
  final int unreadCount;
  final bool hasFreshInbound;
  final bool isLastRead;
  final Set<String> readMessageIds;
  final String searchText;
}

class _PostView {
  const _PostView({
    required this.post,
    required this.authorName,
    required this.authorRole,
    required this.unitName,
    required this.comments,
    required this.commentAuthors,
    required this.readCount,
    required this.hasRead,
  });

  final MessagePost post;
  final String authorName;
  final String authorRole;
  final String unitName;
  final List<MessagePostComment> comments;
  final Map<String, String> commentAuthors;
  final int readCount;
  final bool hasRead;

  int get commentCount => comments.length;

  String commentAuthor(MessagePostComment comment) =>
      commentAuthors[comment.authorId] ?? 'Usuario';

  String scopeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (post.scope == MessagePostScope.global) {
      return l10n.t('messages.globalScope');
    }
    return unitName.isEmpty ? l10n.t('messages.unitScope') : unitName;
  }
}

List<_ChatConversation> _buildConversations({
  required List<Message> messages,
  required List<MessageRead> reads,
  required Map<String, ManagedProfile> profiles,
  required String currentUserId,
  required String query,
}) {
  final grouped = <String, List<Message>>{};
  for (final message in messages) {
    final counterpartId = message.counterpartId(currentUserId);
    if (counterpartId == null || counterpartId.isEmpty) continue;
    grouped.putIfAbsent(counterpartId, () => []).add(message);
  }

  final readByMessage = <String, Set<String>>{};
  for (final read in reads) {
    readByMessage.putIfAbsent(read.messageId, () => {}).add(read.profileId);
  }

  final conversations = <_ChatConversation>[];
  for (final entry in grouped.entries) {
    final list = entry.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final last = list.last;
    final profile = profiles[entry.key];
    final title = profile?.displayName ?? last.counterpartName(currentUserId);
    final role =
        profile?.role?.labelEs ?? last.counterpartRole(currentUserId) ?? '';
    final unitName = profile?.unitName ?? '';
    final email = profile?.email ?? last.counterpartEmail(currentUserId) ?? '';
    final subtitleParts = [
      if (role.isNotEmpty) role,
      if (unitName.isNotEmpty) unitName,
      if (email.isNotEmpty) email,
    ];
    final unread = list
        .where((message) => message.recipientId == currentUserId)
        .where(
          (message) =>
              !(readByMessage[message.id]?.contains(currentUserId) ?? false),
        )
        .length;
    final isLastRead =
        last.senderId == currentUserId &&
        (readByMessage[last.id]?.contains(entry.key) ?? false);
    final readMessageIds = readByMessage.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toSet();
    final searchText = [
      title,
      role,
      unitName,
      email,
      for (final message in list) message.body,
    ].join(' ').toLowerCase();
    conversations.add(
      _ChatConversation(
        id: 'user:${entry.key}',
        counterpartId: entry.key,
        title: title,
        subtitle: subtitleParts.isEmpty ? 'Chat' : subtitleParts.join(' - '),
        email: email,
        role: role,
        unitName: unitName,
        messages: List.unmodifiable(list),
        lastMessage: last,
        unreadCount: unread,
        hasFreshInbound: unread > 0,
        isLastRead: isLastRead,
        readMessageIds: readMessageIds,
        searchText: searchText,
      ),
    );
  }

  final normalizedQuery = query.trim().toLowerCase();
  conversations.sort(
    (a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt),
  );
  if (normalizedQuery.isEmpty) return conversations;
  return conversations
      .where(
        (conversation) => conversation.searchText.contains(normalizedQuery),
      )
      .toList();
}

List<_PostView> _buildPostViews({
  required List<MessagePost> posts,
  required List<MessagePostComment> comments,
  required List<MessagePostRead> reads,
  required Map<String, ManagedProfile> profiles,
  required Map<String, UnitOption> units,
  required String currentUserId,
}) {
  final commentsByPost = <String, List<MessagePostComment>>{};
  for (final comment in comments) {
    commentsByPost.putIfAbsent(comment.postId, () => []).add(comment);
  }

  final readsByPost = <String, Set<String>>{};
  for (final read in reads) {
    readsByPost.putIfAbsent(read.postId, () => {}).add(read.profileId);
  }

  final sorted = [...posts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return [
    for (final post in sorted)
      _PostView(
        post: post,
        authorName: profiles[post.authorId]?.displayName ?? 'Usuario',
        authorRole: profiles[post.authorId]?.role?.labelEs ?? '',
        unitName: post.unitId == null ? '' : (units[post.unitId!]?.name ?? ''),
        comments: (commentsByPost[post.id] ?? [])
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        commentAuthors: {
          for (final profile in profiles.values)
            profile.id: profile.displayName,
        },
        readCount: readsByPost[post.id]?.length ?? 0,
        hasRead: readsByPost[post.id]?.contains(currentUserId) ?? false,
      ),
  ];
}

T _dataOrEmpty<T>(AsyncValue<AppResult<T>> async) {
  final value = async.asData?.value;
  if (value is AppSuccess<T>) return value.data;
  if (T == List<Message>) return <Message>[] as T;
  if (T == List<MessageRead>) return <MessageRead>[] as T;
  if (T == List<MessagePost>) return <MessagePost>[] as T;
  if (T == List<MessagePostComment>) return <MessagePostComment>[] as T;
  if (T == List<MessagePostRead>) return <MessagePostRead>[] as T;
  if (T == Map<String, ManagedProfile>) return <String, ManagedProfile>{} as T;
  if (T == Map<String, UnitOption>) return <String, UnitOption>{} as T;
  throw StateError('Unsupported empty type $T');
}

AppError? _firstError(List<AsyncValue<AppResult<Object?>>> values) {
  for (final async in values) {
    final value = async.asData?.value;
    if (value is AppFailure<Object?>) return value.error;
    if (async.hasError) {
      return const AppError(
        code: 'MESSAGES_LOAD_FAILED',
        message: 'No se pudo cargar los mensajes.',
        category: AppErrorCategory.data,
        severity: AppErrorSeverity.high,
      );
    }
  }
  return null;
}
