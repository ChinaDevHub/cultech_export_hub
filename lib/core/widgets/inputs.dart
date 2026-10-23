import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Bold label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.artisan = false, this.trailing});

  final String text;
  final bool artisan;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: artisan ? 10 : 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: artisan ? AppText.aLabel : AppText.label)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Wraps a field and paints the 4 px brandLight focus glow.
class FocusGlow extends StatefulWidget {
  const FocusGlow({super.key, required this.child, required this.radius, this.focusNode});

  final Widget child;
  final double radius;
  final FocusNode? focusNode;

  @override
  State<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<FocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _focused ? AppShadows.focusGlow : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Text input: white, 1.5 px line2 border, brand border + glow on focus.
/// `artisan: true` → radius 16, 19 px text, 16 px padding, 16 px label.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.artisan = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofillHints,
    this.enabled = true,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.labelTrailing,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final bool artisan;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? labelTrailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final radius = artisan ? AppRadii.inputArtisan : AppRadii.input;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: c, width: artisan ? 2 : 1.5),
    );

    final field = FocusGlow(
      radius: radius,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: obscureText ? 1 : maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: artisan
            ? AppText.body(19, weight: FontWeight.w600)
            : AppText.body(16, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body(artisan ? 18 : 15, color: AppColors.muted),
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: AppColors.muted, size: artisan ? 26 : 20),
          suffixIcon: suffix,
          contentPadding: artisan
              ? const EdgeInsets.all(16)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: border(AppColors.line2),
          enabledBorder: border(AppColors.line2),
          focusedBorder: border(AppColors.brand),
          errorBorder: border(AppColors.danger),
          focusedErrorBorder: border(AppColors.danger),
          errorStyle: AppText.body(
            artisan ? 15 : 13,
            weight: FontWeight.w600,
            color: AppColors.danger,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FieldLabel(label!, artisan: artisan, trailing: labelTrailing),
        field,
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(helper!, style: artisan ? AppText.aHint : AppText.caption),
          ),
      ],
    );
  }
}

/// The artisan's huge price input: Fraunces 44/800 + "AZN" suffix.
class PriceInput extends StatefulWidget {
  const PriceInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.hint = '0',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  final bool autofocus;

  @override
  State<PriceInput> createState() => _PriceInputState();
}

class _PriceInputState extends State<PriceInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.artisanButton),
          border: Border.all(color: focused ? AppColors.brand : AppColors.line2, width: 2.5),
          boxShadow: focused ? AppShadows.focusGlow : const [],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                style: AppText.display(44, weight: FontWeight.w800, height: 1.2),
                // Explicit "no border" for every state: the app theme's
                // enabled/focused borders would otherwise draw a box inside.
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppText.display(44, weight: FontWeight.w800, color: AppColors.line2),
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AZN',
              style: AppText.body(22, weight: FontWeight.w800, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parses a price typed by the artisan ("120", "120,5").
double? parsePrice(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  return v;
}

/// A large, tappable select that opens a bottom sheet of options.
/// Better than a dropdown for older users (big targets, readable list).
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.label,
    this.hint = '',
    this.artisan = false,
    this.icon,
    this.sheetTitle,
    this.validatorMessage,
  });

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final String? label;
  final String hint;
  final bool artisan;
  final IconData? icon;
  final String? sheetTitle;
  final String? validatorMessage;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sheetTitle ?? label case final title?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(title, style: artisan ? AppText.aH2 : AppText.h3),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final o = options[i];
                  final selected = o == value;
                  return Material(
                    color: selected ? AppColors.brandLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(ctx, o),
                      child: Container(
                        constraints: BoxConstraints(minHeight: artisan ? 60 : 50),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                labelOf(o),
                                style: AppText.body(
                                  artisan ? 19 : 16,
                                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                                  color: selected ? AppColors.brand : AppColors.ink,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.brand),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final radius = artisan ? AppRadii.inputArtisan : AppRadii.input;
    final hasValue = value != null;
    return FormField<T>(
      initialValue: value,
      validator: validatorMessage == null ? null : (_) => value == null ? validatorMessage : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) FieldLabel(label!, artisan: artisan),
          Semantics(
            button: true,
            label: label,
            value: hasValue ? labelOf(value as T) : null,
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                constraints: BoxConstraints(minHeight: artisan ? 62 : 50),
                padding: EdgeInsets.symmetric(horizontal: artisan ? 16 : 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: state.hasError ? AppColors.danger : AppColors.line2,
                    width: artisan ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: AppColors.muted, size: artisan ? 26 : 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        hasValue ? labelOf(value as T) : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          artisan ? 19 : 16,
                          weight: hasValue ? FontWeight.w600 : FontWeight.w500,
                          color: hasValue ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: AppColors.ink2, size: artisan ? 30 : 24),
                  ],
                ),
              ),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                state.errorText!,
                style: AppText.body(
                  artisan ? 15 : 13,
                  weight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill segmented control (soft2 track, white active thumb).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.large = false,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.soft2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, label) in options)
              Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.base),
                    curve: AppMotion.curve,
                    constraints: BoxConstraints(minHeight: large ? 48 : 40),
                    padding: EdgeInsets.symmetric(horizontal: large ? 20 : 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? AppColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: v == value ? AppShadows.small : const [],
                    ),
                    child: Text(
                      label,
                      style: AppText.body(
                        large ? 16 : 14,
                        weight: FontWeight.w700,
                        color: v == value ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
