import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart';
import '../../providers/providers.dart';
import '../../services/api_exception.dart';
import '../../services/event_service.dart';
import '../common/hloppl_button.dart';

/// Opens the premium paywall as a bottom sheet. Returns `true` if the user
/// successfully upgraded. [reason] is an optional one-line context ("50 km
/// visibility is a premium feature").
Future<bool> showPremiumPlansSheet(BuildContext context, {String? reason}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PremiumPlansSheet(reason: reason),
  );
  return result ?? false;
}

const _premiumPerks = [
  'Unlimited events every month',
  'No ticket limit (free hosts cap at 50)',
  'Reach up to 50 km (free caps at 25 km)',
  'Automatic reminders before your event',
];

class _PremiumPlansSheet extends ConsumerStatefulWidget {
  const _PremiumPlansSheet({this.reason});
  final String? reason;

  @override
  ConsumerState<_PremiumPlansSheet> createState() => _PremiumPlansSheetState();
}

class _PremiumPlansSheetState extends ConsumerState<_PremiumPlansSheet> {
  String _selected = 'monthly';
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(eventServiceProvider).subscribe(plan: _selected);
      ref.invalidate(eventQuotaProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Premium activated — create away! 🎉')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(eventPlansProvider);
    // Fallback catalog so the sheet still works if the plans call fails.
    final plans = plansAsync.asData?.value ??
        const [
          PremiumPlan(code: 'monthly', label: '1 month', priceInr: 99, days: 30),
          PremiumPlan(code: 'quarterly', label: '3 months', priceInr: 219, days: 90),
        ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Go Premium',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          if (widget.reason != null) ...[
            const SizedBox(height: 6),
            Text(widget.reason!,
                style: const TextStyle(color: AppColors.mutedText)),
          ],
          const SizedBox(height: 16),
          for (final perk in _premiumPerks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(perk)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (final p in plans)
            _PlanTile(
              plan: p,
              selected: _selected == p.code,
              onTap: () => setState(() => _selected = p.code),
            ),
          const SizedBox(height: 16),
          HlopplButton(
            label: 'Upgrade now',
            isLoading: _busy,
            onPressed: _subscribe,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile(
      {required this.plan, required this.selected, required this.onTap});
  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Per-month effective price, to highlight the quarterly saving.
    final perMonth = (plan.priceInr / (plan.days / 30)).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.tertiary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.mutedText,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('≈ ₹$perMonth / month',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text('₹${plan.priceInr}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
