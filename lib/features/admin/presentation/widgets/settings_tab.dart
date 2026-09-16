import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../models/master_data.dart';
import '../../../shell/data/masters_repository.dart';
import 'delivery_panel.dart';

/// The configurable workflow rules the RFQ asks for: approval thresholds,
/// calibration windows, whether over-issue is permitted, which alerts fire.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  static const _categoryLabels = <String, (String, IconData)>{
    'general': ('Plant', Icons.factory_outlined),
    'issue': ('Issue & Return', Icons.swap_horiz_rounded),
    'calibration': ('Calibration', Icons.schedule_rounded),
    'maintenance': ('Repair & Scrap', Icons.handyman_outlined),
    'purchase': ('Purchase', Icons.shopping_cart_outlined),
    'alerts': ('Automated Alerts', Icons.notifications_active_outlined),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      child: AsyncView<List<AppSetting>>(
        value: settings,
        onRetry: () => ref.invalidate(settingsProvider),
        loading: const BlockSkeleton(height: 300),
        data: (all) {
          final grouped = <String, List<AppSetting>>{};
          for (final setting in all) {
            grouped.putIfAbsent(setting.category, () => []).add(setting);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeBar(
                tone: NoticeTone.info,
                icon: Icons.info_outline_rounded,
                message: 'These rules take effect immediately across every screen. '
                    'Each change is written to the audit trail with your name.',
              ),
              for (final entry in _orderedGroups(grouped)) ...[
                SectionCard(
                  title: _categoryLabels[entry.key]?.$1 ?? entry.key,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final setting in entry.value) _SettingRow(setting: setting),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],

              // The switches above decide whether alerts are emailed or texted;
              // this says whether that is actually working.
              const DeliveryPanel(),
            ],
          );
        },
      ),
    );
  }

  /// Keep a stable, meaningful order rather than whatever the map yields.
  List<MapEntry<String, List<AppSetting>>> _orderedGroups(
    Map<String, List<AppSetting>> grouped,
  ) {
    final order = _categoryLabels.keys.toList();
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a.key);
        final bi = order.indexOf(b.key);
        return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
      });
    return entries;
  }
}

class _SettingRow extends ConsumerStatefulWidget {
  const _SettingRow({required this.setting});

  final AppSetting setting;

  @override
  ConsumerState<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends ConsumerState<_SettingRow> {
  late final TextEditingController _controller;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setting = widget.setting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  setting.label ?? setting.key,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  setting.description ?? setting.key,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
                ),
                if (setting.updatedByName != null)
                  Text(
                    'Last changed by ${setting.updatedByName} · ${Fmt.ago(setting.updatedAt)}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Insets.lg),
          SizedBox(width: 210, child: _control(setting)),
        ],
      ),
    );
  }

  Widget _control(AppSetting setting) {
    if (setting.dataType == 'boolean') {
      return Align(
        alignment: Alignment.centerRight,
        child: Switch.adaptive(
          value: setting.asBoolValue,
          onChanged: _saving ? null : (v) => _save(v),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType:
                setting.dataType == 'number' ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => setState(() => _dirty = true),
            onSubmitted: (_) => _saveText(setting),
          ),
        ),
        if (_dirty) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: _saving ? null : () => _saveText(setting),
            icon: _saving
                ? const SizedBox(
                    width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            color: AppColors.green,
            tooltip: 'Save',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  void _saveText(AppSetting setting) {
    final raw = _controller.text.trim();
    final value = setting.dataType == 'number' ? num.tryParse(raw) : raw;
    if (setting.dataType == 'number' && value == null) {
      context.toast('${setting.label ?? setting.key} must be a number', kind: ToastKind.warning);
      return;
    }
    _save(value);
  }

  Future<void> _save(Object? value) async {
    setState(() => _saving = true);
    try {
      await ref.read(mastersRepositoryProvider).updateSetting(widget.setting.key, value);
      ref.invalidate(settingsProvider);
      if (mounted) {
        setState(() => _dirty = false);
        context.toast('${widget.setting.label ?? widget.setting.key} updated');
      }
    } catch (error) {
      if (mounted) context.showApiError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
