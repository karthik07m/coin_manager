import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_intent.dart';
import '../models/ai_message.dart';
import '../providers/account_provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';

class AiAssistantScreen extends StatefulWidget {
  static const routeName = '/ai-assistant';

  final bool reserveBottomNavigationSpace;

  const AiAssistantScreen({
    super.key,
    this.reserveBottomNavigationSpace = false,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.fetchAllCategories();
      }
      if (!accountProvider.isLoaded) {
        await accountProvider.loadAccounts();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (Provider.of<AiAssistantProvider>(context, listen: false).isLoading) {
      return;
    }
    _controller.clear();

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    final aiProvider = Provider.of<AiAssistantProvider>(context, listen: false);

    await aiProvider.submitMessage(
      message: text,
      aiEnabled: settings.aiAssistantEnabled,
      functionUrl: settings.aiFunctionUrl,
      currencySymbol: settings.currencySymbol,
      currencyCode: settings.currencyCode,
      categories: categoryProvider.categories,
      accounts: accountProvider.accounts,
    );

    _scrollToBottom();
  }

  void _submitPrompt(String prompt) {
    _controller.text = prompt;
    _send();
  }

  void _preparePrompt(String prompt) {
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    _inputFocusNode.requestFocus();
  }

  void _handlePrompt(_AiPrompt prompt) {
    if (prompt.autoSubmit) {
      _submitPrompt(prompt.prompt);
    } else {
      _preparePrompt(prompt.prompt);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          Consumer<AiAssistantProvider>(
            builder: (context, provider, child) {
              if (provider.messages.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear chat',
                onPressed: provider.isLoading ? null : provider.clearMessages,
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBanner(context),
          Expanded(
            child: Consumer<AiAssistantProvider>(
              builder: (context, provider, child) {
                if (provider.messages.isEmpty) {
                  return _buildEmptyState(context);
                }

                return _buildConversation(context, provider);
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final isEnabled = settings.aiAssistantEnabled;
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            AppDimensions.spacing16,
            AppDimensions.spacing12,
            AppDimensions.spacing16,
            0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.primary.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(
              color: isEnabled
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : AppColors.warning.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isEnabled ? colorScheme.primary : AppColors.warning,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Icon(
                  isEnabled ? Icons.check_rounded : Icons.power_settings_new,
                  color: Colors.white,
                  size: AppDimensions.iconSmall,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnabled ? 'AI is ready' : 'AI is turned off',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    Text(
                      isEnabled
                          ? 'Quick commands run instantly on-device.'
                          : 'Quick commands still work — AI handles the rest.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: settings.toggleAiAssistant,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final prompts = _buildPromptData();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          children: [
            _AssistantIntroPanel(
              onPromptSelected: _preparePrompt,
            ),
            const SizedBox(height: AppDimensions.spacing20),
            Text(
              'Quick actions',
              style: AppTextStyles.bodyLarge.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            GridView.builder(
              itemCount: prompts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: AppDimensions.spacing12,
                crossAxisSpacing: AppDimensions.spacing12,
                childAspectRatio: isWide ? 1.15 : 1.22,
              ),
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return _PromptCard(
                  prompt: prompt,
                  onTap: () => _handlePrompt(prompt),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversation(
    BuildContext context,
    AiAssistantProvider provider,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing16,
        AppDimensions.spacing12,
        AppDimensions.spacing16,
        AppDimensions.spacing20,
      ),
      itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.messages.length) {
          return _buildTypingBubble(context);
        }

        final message = provider.messages[index];
        final isLast = index == provider.messages.length - 1;
        final bubble = _buildMessage(
          context,
          message,
          provider.pendingDraft != null,
        );

        final showSuggestions = isLast &&
            !provider.isLoading &&
            message.role == AiMessageRole.assistant &&
            message.suggestions.isNotEmpty &&
            provider.pendingDraft == null;

        final content = showSuggestions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bubble,
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 40,
                      bottom: AppDimensions.spacing12,
                    ),
                    child: Wrap(
                      spacing: AppDimensions.spacing8,
                      runSpacing: AppDimensions.spacing8,
                      children: message.suggestions
                          .map(
                            (suggestion) => ActionChip(
                              label: Text(
                                suggestion,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                              onPressed: () => _submitPrompt(suggestion),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMedium,
                                ),
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              backgroundColor: context.appSurface,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              )
            : bubble;

        // Animate only freshly arrived messages, not ones scrolled back
        // into view.
        final isRecent = DateTime.now()
                .difference(message.createdAt)
                .inMilliseconds <
            400;
        if (!isRecent) return content;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          ),
          child: content,
        );
      },
    );
  }

  Widget _buildMessage(
    BuildContext context,
    AiAssistantMessage message,
    bool hasActiveDraft,
  ) {
    final isUser = message.role == AiMessageRole.user;
    final draft = message.transactionDraft;
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width >= 700
        ? 560.0
        : MediaQuery.of(context).size.width * 0.86;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _MessageAvatar(
              icon: Icons.auto_awesome,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacing8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? colorScheme.primary : context.appSurface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      isUser ? AppDimensions.radiusMedium : 6,
                    ),
                    topRight: Radius.circular(
                      isUser ? 6 : AppDimensions.radiusMedium,
                    ),
                    bottomLeft:
                        const Radius.circular(AppDimensions.radiusMedium),
                    bottomRight:
                        const Radius.circular(AppDimensions.radiusMedium),
                  ),
                  border: Border.all(
                    color: isUser
                        ? colorScheme.primary
                        : context.appBorder.withValues(alpha: 0.75),
                  ),
                  boxShadow: isUser ? null : AppShadows.card,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isUser ? Colors.white : context.textPrimary,
                          height: 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                      if (draft != null && hasActiveDraft) ...[
                        const SizedBox(height: AppDimensions.spacing12),
                        const _TransactionDraftCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Row(
        children: [
          _MessageAvatar(
            icon: Icons.auto_awesome,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing12,
            ),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: context.appBorder),
            ),
            child: _TypingDots(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final bottomPadding =
        widget.reserveBottomNavigationSpace ? AppDimensions.spacing16 : 0.0;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.spacing16,
          AppDimensions.spacing8,
          AppDimensions.spacing16,
          AppDimensions.spacing12 + bottomPadding,
        ),
        decoration: BoxDecoration(
          color: context.appBackground,
          border: Border(
            top: BorderSide(color: context.appBorder),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Consumer<AiAssistantProvider>(
                builder: (context, provider, child) {
                  return TextField(
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => provider.isLoading ? null : _send(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message Coin AI',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0,
                      ),
                      prefixIcon: Icon(
                        Icons.auto_awesome_outlined,
                        color: context.textSecondary,
                        size: AppDimensions.iconSmall,
                      ),
                      filled: true,
                      fillColor: context.appSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing12,
                        vertical: AppDimensions.spacing12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Consumer<AiAssistantProvider>(
              builder: (context, provider, child) {
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    onPressed: provider.isLoading ? null : _send,
                    tooltip: 'Send',
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AiPrompt {
  final IconData icon;
  final String title;
  final String prompt;
  final bool autoSubmit;

  const _AiPrompt({
    required this.icon,
    required this.title,
    required this.prompt,
    this.autoSubmit = true,
  });
}

List<_AiPrompt> _buildPromptData() {
  return [
    const _AiPrompt(
      icon: Icons.add_card_outlined,
      title: 'Add expense',
      prompt: 'Add expense ',
      autoSubmit: false,
    ),
    const _AiPrompt(
      icon: Icons.savings_outlined,
      title: 'Add income',
      prompt: 'Add income ',
      autoSubmit: false,
    ),
    const _AiPrompt(
      icon: Icons.insights_outlined,
      title: 'This month',
      prompt: 'How much did I spend this month?',
    ),
    const _AiPrompt(
      icon: Icons.category_outlined,
      title: 'Top category',
      prompt: 'What is my top spending category this month?',
    ),
    const _AiPrompt(
      icon: Icons.account_balance_outlined,
      title: 'Net balance',
      prompt: 'What is my net balance this month?',
    ),
    const _AiPrompt(
      icon: Icons.event_repeat_outlined,
      title: 'Upcoming bills',
      prompt: 'Show my upcoming recurring payments',
    ),
  ];
}

class _AssistantIntroPanel extends StatelessWidget {
  final ValueChanged<String> onPromptSelected;

  const _AssistantIntroPanel({
    required this.onPromptSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: AppDimensions.iconMedium,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: AppTextStyles.h2.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    Text(
                      'Type things like "coffee 150" or "spent 500 on '
                      'groceries" and I\'ll log them instantly.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              _IntroActionChip(
                icon: Icons.receipt_long_outlined,
                label: 'Add transaction',
                onTap: () => onPromptSelected('Add expense '),
              ),
              _IntroActionChip(
                icon: Icons.query_stats_outlined,
                label: 'Monthly summary',
                onTap: () =>
                    onPromptSelected('How much did I spend this month?'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning! ☀️';
  if (hour < 17) return 'Good afternoon! 🌤️';
  return 'Good evening! 🌙';
}

class _IntroActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IntroActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: AppDimensions.iconSmall),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        side: BorderSide(color: context.appBorder),
      ),
    );
  }
}

/// Three bouncing dots shown while the assistant is thinking — livelier than
/// a spinner. One controller drives all three dots with phase offsets.
class _TypingDots extends StatefulWidget {
  final Color color;

  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value - index * 0.18) % 1.0;
            // Rise and fall within the first 60% of the cycle, rest after.
            final t = phase < 0.6 ? phase / 0.6 : 1.0;
            final bounce =
                t < 0.5 ? Curves.easeOut.transform(t * 2) : Curves.easeIn.transform(2 - t * 2);
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.color
                        .withValues(alpha: 0.45 + 0.55 * bounce),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MessageAvatar({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(
        icon,
        color: color,
        size: AppDimensions.iconSmall,
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final _AiPrompt prompt;
  final VoidCallback onTap;

  const _PromptCard({
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                prompt.icon,
                color: colorScheme.primary,
                size: AppDimensions.iconMedium,
              ),
              const Spacer(),
              Text(
                prompt.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                prompt.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionDraftCard extends StatefulWidget {
  const _TransactionDraftCard();

  @override
  State<_TransactionDraftCard> createState() => _TransactionDraftCardState();
}

class _TransactionDraftCardState extends State<_TransactionDraftCard> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _syncDraftFields(AiTransactionDraft draft) {
    if (!_titleFocusNode.hasFocus && _titleController.text != draft.title) {
      _titleController.text = draft.title;
    }

    final amountText = draft.amount.toStringAsFixed(
      draft.amount.truncateToDouble() == draft.amount ? 0 : 2,
    );
    if (!_amountFocusNode.hasFocus && _amountController.text != amountText) {
      _amountController.text = amountText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AiAssistantProvider, CategoryProvider, AccountProvider,
        SettingsProvider>(
      builder: (
        context,
        aiProvider,
        categoryProvider,
        accountProvider,
        settings,
        child,
      ) {
        final activeDraft = aiProvider.pendingDraft;
        if (activeDraft == null) {
          return const SizedBox.shrink();
        }
        _syncDraftFields(activeDraft);

        final matchingCategories = categoryProvider.categories
            .where((category) => category.isExpense == activeDraft.isExpense)
            .toList();
        final accounts = accountProvider.accounts;
        final categoryValue = matchingCategories.any(
          (category) => category.id == activeDraft.categoryId,
        )
            ? activeDraft.categoryId
            : null;
        final accountValue = accounts.any(
          (account) => account.id == activeDraft.accountId,
        )
            ? activeDraft.accountId
            : null;
        final typeColor =
            activeDraft.isExpense ? AppColors.negative : AppColors.positive;

        return Container(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          decoration: BoxDecoration(
            color: context.appBackground.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                    ),
                    child: Icon(
                      activeDraft.isExpense
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: typeColor,
                      size: AppDimensions.iconMedium,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Text(
                      'Review transaction',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  letterSpacing: 0,
                ),
                decoration: _draftInputDecoration(context, 'Title'),
                onChanged: aiProvider.updatePendingTitle,
              ),
              const SizedBox(height: AppDimensions.spacing8),
              TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                decoration: _draftInputDecoration(
                  context,
                  'Amount',
                  prefixText: settings.currencySymbol,
                ),
                onChanged: (value) {
                  final normalized = value.replaceAll(',', '').trim();
                  final amount = double.tryParse(normalized);
                  if (amount != null) {
                    aiProvider.updatePendingAmount(amount);
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spacing8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: activeDraft.date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    aiProvider.updatePendingDate(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(UtilityFunction.formateDate(activeDraft.date)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Wrap(
                spacing: AppDimensions.spacing8,
                runSpacing: AppDimensions.spacing8,
                children: [
                  _ReviewPill(
                    icon: activeDraft.isExpense
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    label: activeDraft.isExpense ? 'Expense' : 'Income',
                    color: typeColor,
                  ),
                  if (activeDraft.isRecurring)
                    _ReviewPill(
                      icon: Icons.repeat_rounded,
                      label: 'Recurring',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  if (activeDraft.needsCategoryReview ||
                      activeDraft.needsAccountReview)
                    _ReviewPill(
                      icon: Icons.error_outline,
                      label: 'Review needed',
                      color: AppColors.warning,
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),
              DropdownButtonFormField<int>(
                value: categoryValue,
                isExpanded: true,
                decoration: _draftInputDecoration(
                  context,
                  activeDraft.needsCategoryReview
                      ? 'Category needs review'
                      : 'Category',
                ),
                items: matchingCategories
                    .where((category) => category.id != null)
                    .map(
                      (category) => DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) aiProvider.updatePendingCategory(value);
                },
              ),
              const SizedBox(height: AppDimensions.spacing8),
              DropdownButtonFormField<int>(
                value: accountValue,
                isExpanded: true,
                decoration: _draftInputDecoration(
                  context,
                  activeDraft.needsAccountReview
                      ? 'Account needs review'
                      : 'Account',
                ),
                items: accounts
                    .where((account) => account.id != null)
                    .map(
                      (account) => DropdownMenuItem<int>(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) aiProvider.updatePendingAccount(value);
                },
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: aiProvider.cancelPendingDraft,
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppDimensions.buttonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final transactionProvider =
                            Provider.of<TransactionProvider>(
                          context,
                          listen: false,
                        );
                        await aiProvider.confirmPendingDraft(
                          transactionProvider,
                          currencySymbol: settings.currencySymbol,
                          currencyCode: settings.currencyCode,
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppDimensions.buttonHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

InputDecoration _draftInputDecoration(
  BuildContext context,
  String label, {
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    prefixText: prefixText,
    isDense: true,
    filled: true,
    fillColor: context.appSurface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.spacing12,
      vertical: AppDimensions.spacing12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      borderSide: BorderSide(color: context.appBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      borderSide: BorderSide(color: context.appBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _ReviewPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ReviewPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppDimensions.spacing4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
