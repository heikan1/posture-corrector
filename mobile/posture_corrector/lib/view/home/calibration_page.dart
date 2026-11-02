import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:posture_corrector/core/repository/ble_service.dart';
import 'package:posture_corrector/core/repository/posture_persistence_manager.dart';

enum _CalibStep { instruction, calibrating, result }

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage>
    with TickerProviderStateMixin {
  final BleService _ble = BleService();
  final PosturePersistenceManager _pm = PosturePersistenceManager();

  _CalibStep _step = _CalibStep.instruction;
  bool? _calibResult;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  late final AnimationController _spinCtrl;

  late final AnimationController _resultCtrl;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultOpacity;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultScale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut));
    _resultOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    setState(() => _step = _CalibStep.calibrating);
    _ble.sendData('{"calibration": true}');

    bool? result;
    try {
      result = await _pm.calibResultStream.first.timeout(
        const Duration(seconds: 30),
      );
    } catch (_) {
      result = false;
    }

    if (!mounted) return;
    setState(() {
      _calibResult = result;
      _step = _CalibStep.result;
    });
    _resultCtrl.forward();

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _step == _CalibStep.instruction
            ? IconButton(
                icon: Icon(Icons.close, color: colors.onSurface),
                onPressed: () => Navigator.pop(context),
              )
            : const SizedBox.shrink(),
        title: Text(
          'calibDialogTitle'.tr(),
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: _buildStep(colors),
        ),
      ),
    );
  }

  Widget _buildStep(ColorScheme colors) {
    switch (_step) {
      case _CalibStep.instruction:
        return _InstructionStep(
          key: const ValueKey('instruction'),
          pulse: _pulse,
          colors: colors,
          onStart: _startCalibration,
          onCancel: () => Navigator.pop(context),
        );
      case _CalibStep.calibrating:
        return _CalibratingStep(
          key: const ValueKey('calibrating'),
          spinCtrl: _spinCtrl,
          colors: colors,
        );
      case _CalibStep.result:
        return _ResultStep(
          key: const ValueKey('result'),
          success: _calibResult ?? false,
          scaleAnim: _resultScale,
          opacityAnim: _resultOpacity,
          colors: colors,
        );
    }
  }
}

class _InstructionStep extends StatelessWidget {
  final Animation<double> pulse;
  final ColorScheme colors;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _InstructionStep({
    super.key,
    required this.pulse,
    required this.colors,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          AnimatedBuilder(
            animation: pulse,
            builder: (_, child) =>
                Transform.scale(scale: pulse.value, child: child),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primaryContainer, colors.secondaryContainer],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.accessibility_new_rounded,
                size: 80,
                color: colors.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'calibDialogTitle'.tr(),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'calibDialogBody'.tr(),
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          _TipTile(
            icon: Icons.straighten_rounded,
            text: 'calibTip1'.tr(),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _TipTile(
            icon: Icons.do_not_disturb_on_outlined,
            text: 'calibTip2'.tr(),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _TipTile(
            icon: Icons.timer_outlined,
            text: 'calibTip3'.tr(),
            colors: colors,
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'calibDialogStart'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(onPressed: onCancel, child: Text('cancel'.tr())),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CalibratingStep extends StatelessWidget {
  final AnimationController spinCtrl;
  final ColorScheme colors;

  const _CalibratingStep({
    super.key,
    required this.spinCtrl,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primaryContainer.withValues(alpha: 0.4),
                    ),
                  ),

                  AnimatedBuilder(
                    animation: spinCtrl,
                    builder: (_, w) => Transform.rotate(
                      angle: spinCtrl.value * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(140, 140),
                        painter: _ArcPainter(color: colors.primary),
                      ),
                    ),
                  ),

                  Icon(Icons.sensors_rounded, size: 52, color: colors.primary),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'calibDialogTitle'.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'calibWaiting'.tr(),
              style: textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  final bool success;
  final Animation<double> scaleAnim;
  final Animation<double> opacityAnim;
  final ColorScheme colors;

  const _ResultStep({
    super.key,
    required this.success,
    required this.scaleAnim,
    required this.opacityAnim,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Color accent = success ? colors.primary : colors.error;
    final Color accentBg = success
        ? colors.primaryContainer
        : colors.errorContainer;

    return Center(
      child: AnimatedBuilder(
        animation: scaleAnim,
        builder: (_, child) => FadeTransition(
          opacity: opacityAnim,
          child: ScaleTransition(scale: scaleAnim, child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentBg,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 72,
                  color: accent,
                ),
              ),

              const SizedBox(height: 36),

              Text(
                success ? 'calibSuccess'.tr() : 'calibFail'.tr(),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              Text(
                success
                    ? 'calibSuccessSubtitle'.tr()
                    : 'calibFailSubtitle'.tr(),
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colors;

  const _TipTile({
    required this.icon,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
