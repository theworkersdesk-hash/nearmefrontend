import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/support_ticket_model.dart';
import '../../providers/support_provider.dart';
import 'new_ticket_screen.dart';
import 'support_common.dart';
import 'ticket_detail_screen.dart';

/// Help & Support hub: a short FAQ, plus the user's own requests split into
/// Active and History (resolved/closed) tabs.
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportListProvider('active').notifier).refresh();
      ref.read(supportListProvider('closed').notifier).refresh();
    });
  }

  Future<void> _newRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewTicketScreen()),
    );
    if (created == true && mounted) {
      ref.read(supportListProvider('active').notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Help & Support'),
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.mutedText,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Active'), Tab(text: 'History')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newRequest,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
        ),
        body: const TabBarView(
          children: [
            _TicketList(
              filter: 'active',
              emptyText: 'No active requests.\nTap “New Request” to get help.',
              header: _FaqSection(),
            ),
            _TicketList(
              filter: 'closed',
              emptyText: 'No past requests yet.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends ConsumerWidget {
  const _TicketList({required this.filter, required this.emptyText, this.header});
  final String filter;
  final String emptyText;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supportListProvider(filter));
    final notifier = ref.read(supportListProvider(filter).notifier);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (header != null) header!,
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            _Empty(icon: Icons.error_outline, text: state.error!)
          else if (state.tickets.isEmpty)
            _Empty(icon: Icons.inbox_outlined, text: emptyText)
          else ...[
            for (final t in state.tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TicketCard(
                  ticket: t,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TicketDetailScreen(ticketId: t.id)));
                    // Status may have changed (closed/reopened) — refresh both tabs.
                    if (context.mounted) {
                      ref.read(supportListProvider('active').notifier).refresh();
                      ref.read(supportListProvider('closed').notifier).refresh();
                    }
                  },
                ),
              ),
            if (state.hasMore)
              Center(
                child: TextButton(
                  onPressed: notifier.loadMore,
                  child: state.isLoadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Load more'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});
  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ticket.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.label_outline,
                      size: 14, color: AppColors.mutedText),
                  const SizedBox(width: 4),
                  Text(ticket.category.label,
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(timeAgo(ticket.lastMessageAt),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.disabled),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

/// Static FAQ shown above the Active tab.
class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _faqs = [
    (
      q: 'How does discovery work?',
      a: 'We show people near you based on your location and filters. Turn on location and set your range from the Discover filters.'
    ),
    (
      q: 'How do connections work?',
      a: 'Tap “Say Hii” to send a request. When the other person accepts, you can chat in the Messages tab.'
    ),
    (
      q: 'How do I change my phone or email?',
      a: 'Raise an Account request below and our team will verify and update it for you.'
    ),
    (
      q: 'I found a safety issue. What do I do?',
      a: 'Use the “Safety / Report” category below and attach a screenshot. We review these on priority.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequently asked',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppShapes.card),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _faqs.length; i++)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    title: Text(_faqs[i].q,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_faqs[i].a,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Your requests',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
    );
  }
}
