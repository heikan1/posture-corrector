import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/models/eod_review_model.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';

class EodReviewDialog extends StatefulWidget {
  final String date;
  final VoidCallback? onSaved;

  const EodReviewDialog({
    super.key,
    required this.date,
    this.onSaved,
  });

  @override
  State<EodReviewDialog> createState() => _EodReviewDialogState();
}

class _EodReviewDialogState extends State<EodReviewDialog> {
  final SqlitePostureRepository _repo = SqlitePostureRepository();
  final TextEditingController _notesController = TextEditingController();

  int _energyLevel = 3;
  int _painLevel = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final notes = _notesController.text.trim();
    final review = EodReview(
      date: widget.date,
      energyLevel: _energyLevel,
      painLevel: _painLevel,
      notes: notes.length > 255 ? notes.substring(0, 255) : notes,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _repo.saveEodReview(review);
    setState(() => _isSaving = false);

    if (mounted) Navigator.of(context).pop();
    widget.onSaved?.call();
    SmartDialog.showToast('eodSavedToast'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'eodTitle'.tr(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.date,
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

            Text(
              'eodEnergy'.tr(),
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _buildEmojiSlider(
              value: _energyLevel,
              onChanged: (v) => setState(() => _energyLevel = v),
              emojis: ['😴', '😔', '😐', '😊', '⚡'],
              colors: colors,
            ),

            const SizedBox(height: 20),

            Text(
              'eodPain'.tr(),
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _buildEmojiSlider(
              value: _painLevel,
              onChanged: (v) => setState(() => _painLevel = v),
              emojis: ['😌', '😕', '😣', '😖', '🤕'],
              colors: colors,
            ),

            const SizedBox(height: 20),

            Text(
              'eodNotes'.tr(),
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLength: 255,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'eodNotesHint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                filled: true,
                fillColor: colors.surfaceContainerLow,
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                label: Text('eodSave'.tr()),
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

  Widget _buildEmojiSlider({
    required int value,
    required ValueChanged<int> onChanged,
    required List<String> emojis,
    required ColorScheme colors,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final selected = value == i + 1;
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.4),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  emojis[i],
                  style: TextStyle(fontSize: selected ? 24 : 20),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            5,
            (i) => Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 11,
                color: value == i + 1
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.4),
                fontWeight:
                    value == i + 1 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showEodReviewDialog(
  BuildContext context, {
  required String date,
  VoidCallback? onSaved,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EodReviewDialog(date: date, onSaved: onSaved),
  );
}
