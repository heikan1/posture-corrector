import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';

class AiOnboardingDialog extends StatefulWidget {
  final VoidCallback? onCompleted;

  const AiOnboardingDialog({super.key, this.onCompleted});

  @override
  State<AiOnboardingDialog> createState() => _AiOnboardingDialogState();
}

class _AiOnboardingDialogState extends State<AiOnboardingDialog> {
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _painCtrl = TextEditingController();

  String _workType = 'office';
  final Set<int> _workDays = {1, 2, 3, 4, 5};

  bool _isSaving = false;

  static const List<String> _dayLabels = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final h = await AppSettings.getAiHeightCm();
    final w = await AppSettings.getAiWeightKg();
    final pain = await AppSettings.getAiPainDescription();
    final wt = await AppSettings.getAiWorkType();
    final wd = await AppSettings.getAiWorkDays();
    if (mounted) {
      setState(() {
        if (h > 0) _heightCtrl.text = h.toString();
        if (w > 0) _weightCtrl.text = w.toString();
        _painCtrl.text = pain;
        _workType = wt;
        _workDays
          ..clear()
          ..addAll(wd);
      });
    }
  }

  Future<void> _save() async {
    final height = int.tryParse(_heightCtrl.text) ?? 0;
    final weight = int.tryParse(_weightCtrl.text) ?? 0;

    if (height < 100 || height > 250) {
      _showError('Lütfen geçerli bir boy giriniz (100–250 cm).');
      return;
    }
    if (weight < 30 || weight > 300) {
      _showError('Lütfen geçerli bir kilo giriniz (30–300 kg).');
      return;
    }
    if (_workDays.isEmpty) {
      _showError('Lütfen en az bir çalışma günü seçiniz.');
      return;
    }

    setState(() => _isSaving = true);

    await AppSettings.setAiHeightCm(height);
    await AppSettings.setAiWeightKg(weight);
    await AppSettings.setAiPainDescription(_painCtrl.text.trim());
    await AppSettings.setAiWorkType(_workType);
    await AppSettings.setAiWorkDays(_workDays.toList()..sort());
    await AppSettings.setAiProfileSaved(true);

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop();
    widget.onCompleted?.call();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _painCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.smart_toy_rounded, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'aiOnboardingTitle'.tr(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'aiOnboardingSubtitle'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _heightCtrl,
                    label: 'aiHeight'.tr(),
                    suffix: 'cm',
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _weightCtrl,
                    label: 'aiWeight'.tr(),
                    suffix: 'kg',
                    colors: colors,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text('aiPain'.tr(), style: textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _painCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'aiPainHint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                filled: true,
                fillColor: colors.surfaceContainerLow,
              ),
            ),

            const SizedBox(height: 20),

            Text('aiWorkType'.tr(), style: textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildWorkTypeChips(colors),

            const SizedBox(height: 20),

            Text('aiWorkDays'.tr(), style: textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildWorkDayChips(colors),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text('aiOnboardingSave'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ColorScheme colors,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colors.surfaceContainerLow,
      ),
    );
  }

  Widget _buildWorkTypeChips(ColorScheme colors) {
    final types = [
      ('office', 'aiWorkOffice'.tr(), Icons.computer_rounded),
      ('standing', 'aiWorkStanding'.tr(), Icons.accessibility_new_rounded),
      ('mixed', 'aiWorkMixed'.tr(), Icons.swap_horiz_rounded),
    ];

    return Row(
      children: types.map((t) {
        final selected = _workType == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _workType = t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.$3, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.5), size: 20),
                  const SizedBox(height: 4),
                  Text(
                    t.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWorkDayChips(ColorScheme colors) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(7, (i) {
        final dayIdx = i + 1;
        final selected = _workDays.contains(dayIdx);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _workDays.remove(dayIdx);
              } else {
                _workDays.add(dayIdx);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _dayLabels[i],
              style: TextStyle(
                fontSize: 11,
                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }
}

Future<void> showAiOnboardingDialog(
  BuildContext context, {
  VoidCallback? onCompleted,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AiOnboardingDialog(onCompleted: onCompleted),
  );
}
