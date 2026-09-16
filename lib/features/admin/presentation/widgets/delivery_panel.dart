import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/alert.dart';
import '../../../alerts/data/alerts_repository.dart';

/// Alert delivery — the operational view behind the email/SMS switches.
///
/// The switches themselves live with the other workflow rules above; this panel
/// answers the question that follows: is anything actually going out? It exists
/// because "the reminders aren't arriving" has four different causes — not
/// configured, switched off, below the severity floor, or the relay refused it —
/// and only the first two are visible from a settings toggle.
class DeliveryPanel extends ConsumerStatefulWidget {
  const DeliveryPanel({super.key});

  @override
  ConsumerState<DeliveryPanel> createState() => _DeliveryPanelState();
}

class _DeliveryPanelState extends ConsumerState<DeliveryPanel> {
  String? _busyChannel;
  bool _dispatching = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(deliverySummaryProvider);

    return AsyncView<DeliverySummary>(
      value: summary,
      onRetry: () => ref.invalidate(deliverySummaryProvider),
      loading: const BlockSkeleton(height: 200),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The dangerous state: switched on, but the transport was never set
          // up. Nothing is sent and nothing complains, so say so loudly.
          if (s.emailMisconfigured || s.smsMisconfigured)
            NoticeBar(
              tone: NoticeTone.danger,
              icon: Icons.error_outline_rounded,
              message: [
                if (s.emailMisconfigured) 'Email alerts are switched on but ${s.email.reason}.',
                if (s.smsMisconfigured) 'SMS alerts are switched on but ${s.sms.reason}.',
                'Nothing is being delivered.',
              ].join(' '),
            )
          else if (!s.anyLive)
            const NoticeBar(
              tone: NoticeTone.info,
              icon: Icons.notifications_off_outlined,
              message: 'Alert delivery is off. Alerts still appear in the bell and on the '
                  'dashboard; they are not emailed or texted. Turn a channel on under '
                  'Automated Alerts above once the transport is configured.',
            ),

          SectionCard(
            title: 'Alert delivery',
            subtitle: 'Only alerts of ${s.minSeverity} or above are sent — the rest stay in the bell',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _channels(context, s),
                const SizedBox(height: Insets.lg),
                _counts(s),
                const SizedBox(height: Insets.lg),
                _actions(s),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          _log(),
        ],
      ),
    );
  }

  Widget _channels(BuildContext context, DeliverySummary s) {
    final cards = [
      _ChannelCard(
        icon: Icons.mail_outline_rounded,
        name: 'Email',
        enabled: s.emailEnabled,
        configured: s.email.configured,
        detail: s.email.configured
            ? '${s.email.host}${s.email.authenticated ? ' · authenticated' : ''}\nfrom ${s.email.from}'
            : s.email.reason,
      ),
      _ChannelCard(
        icon: Icons.sms_outlined,
        name: 'SMS',
        enabled: s.smsEnabled,
        configured: s.sms.configured,
        detail: s.sms.configured ? s.sms.host : s.sms.reason,
      ),
    ];

    if (context.isMobile) {
      return Column(
        children: [
          for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: Insets.md), child: card),
        ],
      );
    }
    return Row(
      children: [
        for (final card in cards) ...[
          Expanded(child: card),
          if (card != cards.last) const SizedBox(width: Insets.md),
        ],
      ],
    );
  }

  Widget _counts(DeliverySummary s) => Wrap(
        spacing: Insets.xl,
        runSpacing: Insets.md,
        children: [
          _stat('Sent, last 24h', '${s.sent24h}', AppColors.green),
          _stat('Queued', '${s.pending}', s.pending > 0 ? AppColors.amber : AppColors.muted),
          _stat('Failed', '${s.failed}', s.failed > 0 ? AppColors.red : AppColors.muted),
          _stat('Skipped', '${s.skipped}', AppColors.muted),
          _stat('Last sent', Fmt.dateTime(s.lastSentAt), AppColors.ink),
        ],
      );

  Widget _stat(String label, String value, Color colour) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colour),
          ),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      );

  Widget _actions(DeliverySummary s) => Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.sm,
        children: [
          OutlinedButton.icon(
            onPressed: _busyChannel != null || !s.email.configured
                ? null
                : () => _test('EMAIL'),
            icon: _busyChannel == 'EMAIL'
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.mail_outline_rounded, size: 16),
            label: const Text('Send test email to me'),
          ),
          OutlinedButton.icon(
            onPressed:
                _busyChannel != null || !s.sms.configured ? null : () => _test('SMS'),
            icon: _busyChannel == 'SMS'
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sms_outlined, size: 16),
            label: const Text('Send test SMS to me'),
          ),
          if (s.pending > 0)
            FilledButton.icon(
              onPressed: _dispatching ? null : _dispatch,
              icon: _dispatching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text('Send ${s.pending} queued now'),
            ),
        ],
      );

  Widget _log() {
    final filter = ref.watch(deliveryLogFilterProvider);
    final log = ref.watch(deliveryLogProvider);

    return SectionCard(
      title: 'Delivery log',
      subtitle: 'Recipients are masked — this is a diagnostic, not a contact list',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            controls: [
              SegmentedFilter<String?>(
                value: filter,
                onChanged: (value) =>
                    ref.read(deliveryLogFilterProvider.notifier).state = value,
                segments: const [
                  (value: null, label: 'All', count: null),
                  (value: 'PENDING', label: 'Queued', count: null),
                  (value: 'SENT', label: 'Sent', count: null),
                  (value: 'FAILED', label: 'Failed', count: null),
                  (value: 'SKIPPED', label: 'Skipped', count: null),
                ],
              ),
            ],
            trailing: OutlinedButton.icon(
              onPressed: () => ref
                ..invalidate(deliveryLogProvider)
                ..invalidate(deliverySummaryProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ),
          AsyncView<List<DeliveryRecord>>(
            value: log,
            onRetry: () => ref.invalidate(deliveryLogProvider),
            loading: const GridSkeleton(),
            data: (rows) => DataGrid<DeliveryRecord>(
              rows: rows,
              minWidth: 860,
              emptyIcon: Icons.outgoing_mail,
              emptyMessage: 'Nothing has been queued for delivery yet.',
              columns: [
                GridColumn<DeliveryRecord>(
                  label: 'Channel',
                  width: 88,
                  cell: (r) => Row(
                    children: [
                      Icon(
                        r.isEmail ? Icons.mail_outline_rounded : Icons.sms_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(r.isEmail ? 'Email' : 'SMS', style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                GridColumn<DeliveryRecord>(
                  label: 'To',
                  flex: 3,
                  cell: (r) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        r.userName ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        r.recipient ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                GridColumn<DeliveryRecord>(
                  label: 'Alert',
                  flex: 3,
                  hideBelow: ScreenSize.desktop,
                  cell: (r) => Text(
                    r.subject ?? r.alertType ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                GridColumn<DeliveryRecord>(
                  label: 'Status',
                  width: 108,
                  cell: (r) => Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(r.status, dense: true),
                  ),
                ),
                GridColumn<DeliveryRecord>(
                  label: 'When',
                  flex: 2,
                  cell: (r) => Text(
                    r.status == 'PENDING'
                        ? 'next try ${Fmt.dateTime(r.nextAttemptAt)}'
                        : Fmt.dateTime(r.sentAt ?? r.queuedAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                GridColumn<DeliveryRecord>(
                  label: 'Detail',
                  flex: 3,
                  hideBelow: ScreenSize.wide,
                  cell: (r) => r.lastError == null
                      ? const Text('—', style: TextStyle(fontSize: 12, color: AppColors.muted))
                      : Tooltip(
                          message: r.lastError!,
                          child: Text(
                            r.lastError!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.redInk),
                          ),
                        ),
                ),
              ],
              mobileCardBuilder: (r) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.subject ?? r.alertType ?? '—',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      StatusChip(r.status, dense: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.isEmail ? 'Email' : 'SMS'} to ${r.userName ?? '—'} · ${r.recipient ?? '—'}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  Text(
                    r.status == 'PENDING'
                        ? 'attempt ${r.attempts} · next try ${Fmt.dateTime(r.nextAttemptAt)}'
                        : Fmt.dateTime(r.sentAt ?? r.queuedAt),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  if (r.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.lastError!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.redInk, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _test(String channel) async {
    setState(() => _busyChannel = channel);
    try {
      final result = await ref.read(alertsRepositoryProvider).testDelivery(channel);
      if (mounted) context.toast(result['message']?.toString() ?? 'Test message sent');
    } catch (error) {
      if (mounted) context.showApiError(error);
    } finally {
      if (mounted) setState(() => _busyChannel = null);
      ref
        ..invalidate(deliveryLogProvider)
        ..invalidate(deliverySummaryProvider);
    }
  }

  Future<void> _dispatch() async {
    setState(() => _dispatching = true);
    try {
      final result = await ref.read(alertsRepositoryProvider).dispatchDeliveries();
      if (mounted) {
        context.toast(
          '${result['sent'] ?? 0} sent, ${result['retrying'] ?? 0} retrying, '
          '${result['failed'] ?? 0} failed, ${result['skipped'] ?? 0} skipped',
        );
      }
    } catch (error) {
      if (mounted) context.showApiError(error);
    } finally {
      if (mounted) setState(() => _dispatching = false);
      ref
        ..invalidate(deliveryLogProvider)
        ..invalidate(deliverySummaryProvider);
    }
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.configured,
    this.detail,
  });

  final IconData icon;
  final String name;
  final bool enabled;
  final bool configured;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    // Three states, and the middle one is the trap: switched on, not set up.
    final (label, tone) = !configured
        ? (enabled ? 'Switched on, not configured' : 'Not configured', AppColors.red)
        : enabled
            ? ('Live', AppColors.green)
            : ('Configured, switched off', AppColors.amber);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.hover,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(Insets.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: Insets.sm),
              Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              detail!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
