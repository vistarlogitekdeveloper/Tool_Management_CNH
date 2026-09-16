import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Label above field, matching the prototype's `.field` block.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
  });

  final String label;
  final Widget child;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label,
                ),
                children: required
                    ? const [TextSpan(text: ' *', style: TextStyle(color: AppColors.red))]
                    : null,
              ),
            ),
          ),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hint!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ),
        ],
      );
}

/// Two fields side by side on wide dialogs, stacked on a phone (`.frow`).
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children, this.spacing = 14});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  children[i],
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        },
      );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 17, color: AppColors.muted),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: suffix,
          filled: true,
          fillColor: enabled ? AppColors.panel : AppColors.line2,
        ),
      );
}

/// Integer-only field with +/- steppers — quantities are entered constantly on
/// the shop floor and a stepper beats a keyboard on a tablet.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.enabled = true,
    this.helper,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final canDecrease = enabled && value > min;
    final canIncrease = enabled && (max == null || value < max!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(Insets.radiusSm),
            color: enabled ? AppColors.panel : AppColors.line2,
          ),
          child: Row(
            children: [
              _stepper(Icons.remove_rounded, canDecrease, () => onChanged(value - 1)),
              Expanded(
                child: TextFormField(
                  key: ValueKey('qty-$value'),
                  initialValue: '$value',
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (raw) {
                    final parsed = int.tryParse(raw);
                    if (parsed == null) return;
                    final clamped = max == null ? parsed.clamp(min, 1 << 30) : parsed.clamp(min, max!);
                    if (clamped != value) onChanged(clamped);
                  },
                ),
              ),
              _stepper(Icons.add_rounded, canIncrease, () => onChanged(value + 1)),
            ],
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(helper!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ),
      ],
    );
  }

  Widget _stepper(IconData icon, bool active, VoidCallback onTap) => SizedBox(
        width: 40,
        child: IconButton(
          onPressed: active ? onTap : null,
          icon: Icon(icon, size: 17),
          color: AppColors.brand,
          disabledColor: AppColors.line,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      );
}

/// Styled dropdown with the same border treatment as the text fields.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.muted),
        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
        hint: hint == null
            ? null
            : Text(hint!, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? AppColors.panel : AppColors.line2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        ),
      );
}

/// Read-only text field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.hintText = 'Select a date',
    this.enabled = true,
    this.clearable = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String hintText;
  final bool enabled;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: firstDate ?? DateTime(now.year - 5),
                lastDate: lastDate ?? DateTime(now.year + 5),
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(Insets.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? AppColors.panel : AppColors.line2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => onChanged(null),
                  visualDensity: VisualDensity.compact,
                  color: AppColors.muted,
                )
              : const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.muted),
        ),
        child: Text(
          value == null ? hintText : Fmt.date(value),
          style: TextStyle(
            fontSize: 13.5,
            color: value == null ? AppColors.muted : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// The search box in filter bars.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.controller,
    this.hintText = 'Search…',
    this.width = 260,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hintText;
  final double width;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            isDense: true,
            filled: true,
            fillColor: AppColors.panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          ),
        ),
      );
}

/// Segmented control (`.seg`) — the All / Issued / Overdue / Returned switcher.
class SegmentedFilter<T> extends StatelessWidget {
  const SegmentedFilter({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<({T value, String label, int? count})> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(Insets.radiusSm),
          color: AppColors.panel,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final seg in segments)
              InkWell(
                onTap: () => onChanged(seg.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  color: seg.value == value ? AppColors.brand : Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        seg.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: seg.value == value ? Colors.white : AppColors.muted,
                        ),
                      ),
                      if (seg.count != null && seg.count! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: seg.value == value
                                ? Colors.white.withValues(alpha: 0.22)
                                : AppColors.slateSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${seg.count}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: seg.value == value ? Colors.white : AppColors.slate,
                            ),
                          ),
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

/// Wraps filter controls with consistent spacing above a grid.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.controls, this.trailing});

  final List<Widget> controls;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: controls,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: Insets.md), trailing!],
          ],
        ),
      );
}

/// Compact dropdown used inside filter bars (fixed width, no label).
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.width = 180,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.muted),
          style: const TextStyle(fontSize: 13, color: AppColors.ink),
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppColors.panel,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          ),
        ),
      );
}
