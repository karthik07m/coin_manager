import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/ai_intent.dart';
import '../models/ai_message.dart';
import '../providers/account_provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/budget_period.dart';
import '../utilities/budget_scope_summary.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';

class AiAssistantScreen extends StatefulWidget {
  static const routeName = '/ai-assistant';

  final bool reserveBottomNavigationSpace;

  /// Jumps to the Charts tab. Summary replies offer it as a chip, since a
  /// month's spending is easier to read as a chart than as a list.
  final VoidCallback? onOpenCharts;

  const AiAssistantScreen({
    super.key,
    this.reserveBottomNavigationSpace = false,
    this.onOpenCharts,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Voice input: on-device speech recognition feeding the same text pipeline.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;
  bool _hasText = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          // The engine stops itself on silence — reflect that in the UI.
          if (status == 'notListening' || status == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (!_speechReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Voice input unavailable — check the microphone permission.'),
            ),
          );
        }
        return;
      }
    }

    HapticFeedback.lightImpact();
    setState(() => _isListening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    // Live transcript in the input field; auto-send on the final result.
    _controller.text = result.recognizedWords;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      setState(() => _isListening = false);
      _send();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
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
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// This month's budget and what has been spent against it, measured on
  /// the budget's own basis so the assistant quotes the number the budget
  /// screen shows.
  static ({double total, double spent}) monthBudget(BuildContext context) {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final now = DateTime.now();
    final monthStart = BudgetPeriod.startOfMonth(now);
    final monthEnd = BudgetPeriod.endOfMonth(now);
    final monthKey = BudgetPeriod.keyFor(now);
    final total = budgetProvider.getTotalBudget(monthKey);
    final spent = BudgetScopeSummary.compute(
      monthExpenses: transactionProvider.transactions
          .where((t) =>
              t.isExpense &&
              !t.isTransfer &&
              !t.date.isBefore(monthStart) &&
              !t.date.isAfter(monthEnd))
          .toList(),
      amountOf: transactionProvider.baseAmount,
      scope: budgetProvider.getScope(monthKey),
      budgetedCategoryIds: BudgetScopeSummary.budgetedCategoryIds(
        categories: categoryProvider.categories,
        budgetFor: (name) => budgetProvider.getBudget(name, monthKey),
      ),
    ).countedSpent;
    return (total: total, spent: spent);
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
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final budget = monthBudget(context);

    _scrollToBottom();
    await aiProvider.submitMessage(
      message: text,
      aiEnabled: settings.aiAssistantEnabled,
      functionUrl: settings.aiFunctionUrl,
      currencySymbol: settings.currencySymbol,
      currencyCode: settings.currencyCode,
      categories: categoryProvider.categories,
      accounts: accountProvider.accounts,
      transactionProvider: transactionProvider,
      budgetTotal: budget.total,
      budgetSpent: budget.spent,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: context.appAccentSurface,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.auto_awesome,
                    color: colorScheme.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coinly Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Selector<SettingsProvider, bool>(
                      selector: (_, settings) => settings.aiAssistantEnabled,
                      builder: (context, cloud, _) => Text(
                          cloud
                              ? 'Cloud AI enabled · Beta'
                              : 'On-device assistant · Beta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption
                              .copyWith(color: context.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Consumer2<SettingsProvider, AiAssistantProvider>(
            builder: (context, settings, ai, child) {
              return PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'cloud':
                      settings.toggleAiAssistant(!settings.aiAssistantEnabled);
                    case 'clear':
                      ai.clearMessages();
                    case 'help':
                      _submitPrompt('Help');
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'cloud',
                    checked: settings.aiAssistantEnabled,
                    child: const Text('Cloud AI for free-form text'),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.help_outline_rounded),
                      title: Text('What can I ask?'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    enabled: ai.messages.isNotEmpty && !ai.isLoading,
                    child: const ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('Clear chat'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
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
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final prompts = _buildPromptData();

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
        final columns = constraints.maxWidth >= 760
            ? (largeText ? 2 : 3)
            : constraints.maxWidth >= 360 && !largeText
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          children: [
            _SectionLabel('Try asking'),
            const SizedBox(height: AppDimensions.spacing8),
            SizedBox(
              height: 24 + MediaQuery.textScalerOf(context).scale(14) * 1.5,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // Let chips paint into the page's side padding so the row
                // reads as scrollable instead of chopped 16px from the edge.
                clipBehavior: Clip.none,
                itemCount: _starterQuestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimensions.spacing8),
                itemBuilder: (context, index) => _SuggestionChip(
                  label: _starterQuestions[index],
                  onTap: () => _submitPrompt(_starterQuestions[index]),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing20),
            _SectionLabel('Quick actions'),
            const SizedBox(height: AppDimensions.spacing8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final prompt in prompts)
                  SizedBox(
                    width: cardWidth,
                    child: _PromptCard(
                        prompt: prompt, onTap: () => _handlePrompt(prompt)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Center(
              child: Text(
                context.watch<SettingsProvider>().aiAssistantEnabled
                    ? 'Cloud AI is on. Manage it in the menu above.'
                    : 'On-device mode · Your commands stay on your phone',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 0,
                ),
              ),
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
        final previous = index > 0 ? provider.messages[index - 1] : null;
        // Group consecutive assistant messages: only the first shows the
        // avatar, which keeps a long answer + follow-up from looking like
        // two speakers.
        final showAvatar = message.role == AiMessageRole.assistant &&
            (previous == null || previous.role != AiMessageRole.assistant);
        final bubble = _buildMessage(
          context,
          message,
          provider.pendingDraft != null,
          showAvatar: showAvatar,
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
                  // Wrap, not a fixed-height horizontal list: the old 36px
                  // row was shorter than a chip (24px padding + a 12px line),
                  // so every follow-up was clipped top and bottom — worse at
                  // larger system text — and chips past the edge were hidden.
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 40,
                      bottom: AppDimensions.spacing12,
                    ),
                    child: Wrap(
                      spacing: AppDimensions.spacing8,
                      runSpacing: AppDimensions.spacing8,
                      children: [
                        for (final chip in message.suggestions)
                          _SuggestionChip(
                            label: chip,
                            onTap: () {
                              if (chip == AiAssistantProvider.openChartsChip &&
                                  widget.onOpenCharts != null) {
                                widget.onOpenCharts!();
                              } else {
                                _submitPrompt(chip);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : bubble;

        // Animate only freshly arrived messages, not ones scrolled back
        // into view.
        final isRecent =
            DateTime.now().difference(message.createdAt).inMilliseconds < 400;
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
    bool hasActiveDraft, {
    required bool showAvatar,
  }) {
    final isUser = message.role == AiMessageRole.user;
    final draft = message.transactionDraft;
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width >= 700
        ? 560.0
        : MediaQuery.of(context).size.width * 0.86;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            showAvatar
                ? _MessageAvatar(
                    icon: Icons.auto_awesome,
                    color: colorScheme.primary,
                  )
                : const SizedBox(width: 32),
            const SizedBox(width: AppDimensions.spacing8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                color: isUser ? colorScheme.primary : context.appSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppDimensions.radiusMedium),
                  topRight: const Radius.circular(AppDimensions.radiusMedium),
                  bottomLeft: Radius.circular(
                    isUser ? AppDimensions.radiusMedium : 6,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 6 : AppDimensions.radiusMedium,
                  ),
                ),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(
                      ClipboardData(text: message.text.replaceAll('**', '')),
                    );
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1),
                      ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MessageText(
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
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMedium),
                topRight: Radius.circular(AppDimensions.radiusMedium),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(AppDimensions.radiusMedium),
              ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.spacing12,
          AppDimensions.spacing8,
          AppDimensions.spacing12,
          AppDimensions.spacing12 + bottomPadding,
        ),
        decoration: BoxDecoration(
          color: context.appBackground,
          border: Border(
            top: BorderSide(color: context.appBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Consumer<AiAssistantProvider>(
                builder: (context, provider, child) {
                  return AnimatedContainer(
                    duration: AppDurations.fast,
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening
                            ? AppColors.negative.withValues(alpha: 0.6)
                            : context.appBorder,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _inputFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) =>
                                provider.isLoading ? null : _send(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              letterSpacing: 0,
                            ),
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? 'Listening…'
                                  : 'Try "coffee 150" or "how\'s my budget?"',
                              // One line, ellipsized: under Inter's wider
                              // metrics the hint wrapped and grew the bar.
                              hintMaxLines: 1,
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: _isListening
                                    ? AppColors.negative
                                    : context.textSecondary,
                                letterSpacing: 0,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                18,
                                12,
                                8,
                                12,
                              ),
                            ),
                          ),
                        ),
                        // Voice input: tap to speak, the transcript auto-sends.
                        _PulsingMic(
                          listening: _isListening,
                          onTap: _toggleListening,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Consumer<AiAssistantProvider>(
              builder: (context, provider, child) {
                final canSend = _hasText && !provider.isLoading;
                return AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: canSend
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: canSend ? _send : null,
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
                        : Icon(Icons.arrow_upward_rounded,
                            color: canSend
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant),
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

const _starterQuestions = [
  'How much did I spend this week?',
  'How\'s my budget?',
  'Biggest expense this month',
  'What\'s my net worth?',
  'My spending habits',
  'Compare this month vs last',
  'Show recent transactions',
];

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
      icon: Icons.swap_horiz_rounded,
      title: 'Transfer',
      prompt: 'Transfer ',
      autoSubmit: false,
    ),
    const _AiPrompt(
      icon: Icons.search_rounded,
      title: 'Find',
      prompt: 'Find ',
      autoSubmit: false,
    ),
    const _AiPrompt(
      icon: Icons.category_outlined,
      title: 'Top category',
      prompt: 'What is my top spending category this month?',
    ),
    const _AiPrompt(
      icon: Icons.event_repeat_outlined,
      title: 'Upcoming bills',
      prompt: 'Show my upcoming recurring payments',
    ),
  ];
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: context.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Renders `**bold**` spans; everything else is plain text.
class _MessageText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _MessageText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    if (parts.length < 3) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style:
                  i.isOdd ? style.copyWith(fontWeight: FontWeight.w800) : null,
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: context.cardBorder,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mic button that breathes while listening.
class _PulsingMic extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;

  const _PulsingMic({required this.listening, required this.onTap});

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant _PulsingMic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.listening ? AppColors.negative : context.textSecondary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.listening
              ? AppColors.negative.withValues(alpha: 0.10 + 0.15 * _pulse.value)
              : Colors.transparent,
        ),
        child: child,
      ),
      child: IconButton(
        onPressed: widget.onTap,
        tooltip: widget.listening ? 'Stop listening' : 'Speak a command',
        visualDensity: VisualDensity.compact,
        icon: Icon(
          widget.listening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: color,
          // The tooltip alone didn't reach TalkBack.
          semanticLabel: widget.listening ? 'Stop listening' : 'Speak a command',
        ),
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
            final bounce = t < 0.5
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform(2 - t * 2);
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.45 + 0.55 * bounce),
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
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
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
      color: context.appSurface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: context.cardBorder,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  prompt.icon,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  prompt.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (!prompt.autoSubmit)
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: context.textSecondary,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review & save',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          'Tap any field to change it',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
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
                  // The account fallback is the default account, which is
                  // what the user wants nine times out of ten — only a
                  // guessed category is worth a warning.
                  if (activeDraft.needsCategoryReview)
                    _ReviewPill(
                      icon: Icons.error_outline,
                      label: 'Check category',
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
                      ? 'Category (best guess)'
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
                      ? 'Account (default)'
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
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
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
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save'),
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
