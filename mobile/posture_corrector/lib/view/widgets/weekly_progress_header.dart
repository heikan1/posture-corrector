import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:posture_corrector/core/utils/app_sizes.dart';

class WeeklyProgressHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double fixedMaxExtent = 245;
  final double fixedMinExtent = 78;

  final ValueNotifier<Map<int, double>> weeklyPostureNotifier;
  final ValueNotifier<Map<int, double>> weeklyStepsNotifier;
  final ValueNotifier<Map<int, double>> weeklyStandingNotifier;

  final int targetPostureMins;
  final int targetSteps;
  final int targetStandingMins;

  final String displayName;
  final String? photoBase64;
  final String? photoURL;
  final String selectedDayName;
  final int selectedWeekday;
  final Function(int weekday)? onDayTap;
  final bool isSyncing;
  final bool needsSync;
  final VoidCallback? onSyncTap;

  WeeklyProgressHeaderDelegate({
    required this.weeklyPostureNotifier,
    required this.weeklyStepsNotifier,
    required this.weeklyStandingNotifier,
    required this.targetPostureMins,
    required this.targetSteps,
    required this.targetStandingMins,
    required this.displayName,
    required this.selectedDayName,
    required this.selectedWeekday,
    this.photoBase64,
    this.photoURL,
    this.onDayTap,
    this.isSyncing = false,
    this.needsSync = false,
    this.onSyncTap,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;

    final double shrinkRatio = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    final double topContentOpacity = (1 - (shrinkRatio * 1.5)).clamp(0.0, 1.0);

    final now = DateTime.now();
    final int todayWeekday = now.weekday;

    ImageProvider? avatarProvider;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      avatarProvider = MemoryImage(base64Decode(photoBase64!));
    } else if (photoURL != null && photoURL!.isNotEmpty) {
      avatarProvider = NetworkImage(photoURL!);
    }

    final String firstName = displayName.split(' ').first;

    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.cardRadiusBig),
          bottomRight: Radius.circular(AppSizes.cardRadiusBig),
        ),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: 20 - (shrinkOffset * 0.1),
              left: AppSizes.pagePadding.left,
              right: AppSizes.pagePadding.right,
              child: Opacity(
                opacity: topContentOpacity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    RepaintBoundary(
                                      child: CircleAvatar(
                                        radius: 17,
                                        backgroundColor: colors.surface,
                                        backgroundImage: avatarProvider,
                                        child: avatarProvider == null
                                            ? Icon(
                                                Icons.person,
                                                size: 18,
                                                color: colors.primary,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'welcomeMessage'.tr(
                                          namedArgs: {'user': firstName},
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (onSyncTap != null)
                                IconButton(
                                  onPressed: isSyncing ? null : onSyncTap,
                                  icon: isSyncing
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.primary,
                                          ),
                                        )
                                      : Stack(
                                          children: [
                                            Icon(
                                              Icons.cloud_sync,
                                              color: needsSync
                                                  ? Colors.orange
                                                  : colors.primary,
                                              size: 24,
                                            ),
                                            if (needsSync)
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    1,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 8,
                                                        minHeight: 8,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                  tooltip: needsSync
                                      ? "needsSync".tr()
                                      : "syncNow".tr(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'EEEE, d MMMM',
                              context.locale.languageCode,
                            ).format(now),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 100 - (shrinkRatio * 85),
              left: AppSizes.pagePadding.left,
              right: AppSizes.pagePadding.right,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  weeklyPostureNotifier,
                  weeklyStepsNotifier,
                  weeklyStandingNotifier,
                ]),
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      int weekday = index + 1;
                      DateTime dayDate = now.subtract(
                        Duration(days: now.weekday - weekday),
                      );
                      String dayName = DateFormat(
                        'EEEE',
                        context.locale.languageCode,
                      ).format(dayDate).substring(0, 3).toUpperCase();
                      final bool isSelected = weekday == selectedWeekday;

                      return BuildDayProgress(
                        day: dayName,
                        progPosture:
                            weeklyPostureNotifier.value[weekday] ?? 0.0,
                        progSteps: weeklyStepsNotifier.value[weekday] ?? 0.0,
                        progStanding:
                            weeklyStandingNotifier.value[weekday] ?? 0.0,
                        isToday: weekday == todayWeekday,
                        isSelected: isSelected,
                        isFuture: DateTime(
                          dayDate.year,
                          dayDate.month,
                          dayDate.day,
                        ).isAfter(DateTime(now.year, now.month, now.day)),
                        onTap: () {
                          if (onDayTap != null) onDayTap!(weekday);
                        },
                      );
                    }),
                  );
                },
              ),
            ),

            Positioned(
              top: 180 - (shrinkRatio * 110),
              left: 16,
              right: 16,
              child: Opacity(
                opacity: 1.0 - (shrinkRatio * 1.2).clamp(0.0, 1.0),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    weeklyPostureNotifier,
                    weeklyStepsNotifier,
                    weeklyStandingNotifier,
                  ]),
                  builder: (context, _) {
                    return WeeklyDetailBar(
                      dayName: selectedDayName,
                      postureProgress:
                          weeklyPostureNotifier.value[selectedWeekday] ?? 0.0,
                      stepsProgress:
                          weeklyStepsNotifier.value[selectedWeekday] ?? 0.0,
                      standingProgress:
                          weeklyStandingNotifier.value[selectedWeekday] ?? 0.0,
                      targetPostureMins: targetPostureMins,
                      targetSteps: targetSteps,
                      targetStandingMins: targetStandingMins,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => fixedMaxExtent;

  @override
  double get minExtent => fixedMinExtent;

  @override
  bool shouldRebuild(covariant WeeklyProgressHeaderDelegate oldDelegate) {
    return oldDelegate.displayName != displayName ||
        oldDelegate.selectedWeekday != selectedWeekday ||
        oldDelegate.photoBase64 != photoBase64 ||
        oldDelegate.photoURL != photoURL ||
        oldDelegate.isSyncing != isSyncing ||
        oldDelegate.needsSync != needsSync ||
        oldDelegate.targetPostureMins != targetPostureMins ||
        oldDelegate.targetSteps != targetSteps ||
        oldDelegate.targetStandingMins != targetStandingMins ||
        oldDelegate.selectedDayName != selectedDayName;
  }
}

class BuildDayProgress extends StatelessWidget {
  const BuildDayProgress({
    super.key,
    required this.day,
    required this.progPosture,
    required this.progSteps,
    required this.progStanding,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    this.onTap,
  });

  final String day;
  final double progPosture;
  final double progSteps;
  final double progStanding;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    bool hasData = progPosture > 0 || progSteps > 0 || progStanding > 0;
    bool isSuccess = progPosture >= 1.0;
    IconData statusIcon;
    Color statusColor;

    if (isFuture) {
      statusIcon = Icons.lock_clock;
      statusColor = colors.onSurface.withValues(alpha: 0.3);
    } else if (isSuccess) {
      statusIcon = Icons.check_circle_rounded;
      statusColor = Colors.green;
    } else if (hasData) {
      statusIcon = Icons.arrow_upward_rounded;
      statusColor = colors.primary;
    } else {
      statusIcon = Icons.remove;
      statusColor = colors.onSurface.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _buildNestedIndicator(colors),
          const SizedBox(height: 4),
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(height: 2),
          Text(
            day,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 2,
            width: 14,
            decoration: BoxDecoration(
              color: isToday
                  ? colors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedIndicator(ColorScheme colors) {
    final Color inactiveColor = colors.onSurface.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: isFuture ? 0 : (progPosture > 0 ? progPosture : 0.0),
                strokeWidth: 2.5,
                backgroundColor: inactiveColor,
                color: isFuture
                    ? inactiveColor
                    : (progPosture >= 1.0 ? Colors.green : colors.primary),
              ),
            ),

            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: isFuture ? 0 : (progSteps > 0 ? progSteps : 0.0),
                strokeWidth: 2.5,
                backgroundColor: inactiveColor,
                color: isFuture ? inactiveColor : Colors.green,
              ),
            ),

            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: isFuture ? 0 : (progStanding > 0 ? progStanding : 0.0),
                strokeWidth: 2.5,
                backgroundColor: inactiveColor,
                color: isFuture ? inactiveColor : Colors.orangeAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeeklyDetailBar extends StatefulWidget {
  final String dayName;
  final double postureProgress;
  final double stepsProgress;
  final double standingProgress;
  final int targetPostureMins;
  final int targetSteps;
  final int targetStandingMins;

  const WeeklyDetailBar({
    super.key,
    required this.dayName,
    required this.postureProgress,
    required this.stepsProgress,
    required this.standingProgress,
    required this.targetPostureMins,
    required this.targetSteps,
    required this.targetStandingMins,
  });

  @override
  State<WeeklyDetailBar> createState() => _WeeklyDetailBarState();
}

class _WeeklyDetailBarState extends State<WeeklyDetailBar> {
  int _currentIndex = 0;
  final List<String> _titles = ["Duruş", "Adım", "Ayakta"];
  final List<IconData> _icons = [
    Icons.accessibility,
    Icons.directions_walk,
    Icons.man,
  ];

  void _next() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % 3;
    });
  }

  void _prev() {
    setState(() {
      _currentIndex = (_currentIndex - 1) % 3;
      if (_currentIndex < 0) _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    double progress = 0;
    String valueText = "";
    Color activeColor = colors.primary;

    if (_currentIndex == 0) {
      progress = widget.postureProgress;
      int currentVal = (progress * widget.targetPostureMins).toInt();
      valueText = "$currentVal / ${widget.targetPostureMins} dk";
      activeColor = colors.primary;
    } else if (_currentIndex == 1) {
      progress = widget.stepsProgress;
      int currentVal = (progress * widget.targetSteps).toInt();
      valueText = "$currentVal / ${widget.targetSteps} ${"stepCount".tr()}";
      activeColor = Colors.green;
    } else if (_currentIndex == 2) {
      progress = widget.standingProgress;
      int currentVal = (progress * widget.targetStandingMins).toInt();
      valueText =
          "$currentVal / ${widget.targetStandingMins} ${"minsUnit".tr()}";
      activeColor = Colors.orangeAccent;
    }

    if (progress >= 1.0) {
      activeColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _prev,
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_icons[_currentIndex], size: 14, color: activeColor),
                    SizedBox(width: 8),
                    Text(
                      _titles[_currentIndex],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  "%${(progress * 100).toStringAsFixed(0)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _next,
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class CircularDayProgressIndicator extends StatelessWidget {
  const CircularDayProgressIndicator({
    super.key,
    required this.progressPosture,
    required this.progressSteps,
    required this.progressStanding,
    required this.isFuture,
  });

  final double progressPosture;
  final double progressSteps;
  final double progressStanding;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color inactiveColor = colors.onSurface.withValues(alpha: 0.1);

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              value: isFuture
                  ? 0
                  : (progressPosture > 0 ? progressPosture : 0.0),
              strokeWidth: 2.5,
              backgroundColor: inactiveColor,
              color: isFuture
                  ? inactiveColor
                  : (progressPosture >= 1.0 ? Colors.green : colors.primary),
            ),
          ),

          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: isFuture ? 0 : (progressSteps > 0 ? progressSteps : 0.0),
              strokeWidth: 2.5,
              backgroundColor: inactiveColor,
              color: isFuture ? inactiveColor : Colors.green,
            ),
          ),

          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: isFuture
                  ? 0
                  : (progressStanding > 0 ? progressStanding : 0.0),
              strokeWidth: 2.5,
              backgroundColor: inactiveColor,
              color: isFuture ? inactiveColor : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }
}
