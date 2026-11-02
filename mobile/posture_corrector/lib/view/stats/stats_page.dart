import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_events.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';
import 'package:posture_corrector/view/reports/reports_page.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final SqlitePostureRepository _repository = SqlitePostureRepository();
  Map<DateTime, int> _heatmapData = {};

  List<_ChartData> _weeklyData = [];
  List<_ChartData> _monthlyData = [];

  List<_ChartData> _weeklySteps = [];
  List<_ChartData> _monthlySteps = [];

  List<_DualChartData> _weeklySitStand = [];
  List<_DualChartData> _monthlySitStand = [];

  bool _isLoading = true;
  String _viewType = "Week";

  int _todaySteps = 0;
  int _targetSteps = 5000;
  int _sittingMs = 0;
  int _standingMs = 0;

  @override
  void initState() {
    super.initState();
    AppEvents.refreshNotifier.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    AppEvents.refreshNotifier.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final languageCode = context.locale.languageCode;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    final heatmapRaw = await _repository.getDailyStatsBetween(
      threeMonthsAgo,
      now.add(const Duration(days: 1)),
    );
    if (!mounted) return;

    Map<DateTime, int> heatmapMins = {};
    heatmapRaw.forEach((date, ms) {
      heatmapMins[date] = (ms / 60000).toInt();
    });
    if (heatmapMins.isEmpty) {
      heatmapMins[DateTime(now.year, now.month, now.day)] = 0;
    }

    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final minDate = firstDayOfWeek.isBefore(firstDayOfMonth)
        ? firstDayOfWeek
        : firstDayOfMonth;

    final allStatsRaw = await _repository.getDailyAllStatsBetween(
      minDate,
      now.add(const Duration(days: 1)),
    );
    if (!mounted) return;

    List<_ChartData> weekPostureList = [];
    List<_ChartData> weekStepsList = [];
    List<_DualChartData> weekSitStandList = [];

    for (int i = 0; i < 7; i++) {
      final day = firstDayOfWeek.add(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);

      final stats = allStatsRaw[dayKey];
      final postureMins = ((stats?['totalUprightMs'] ?? 0) as int) / 60000;
      final steps = (stats?['maxSteps'] ?? 0) as int;
      final sitMins = ((stats?['totalSittingMs'] ?? 0) as int) / 60000;
      final standMins = ((stats?['totalStandingMs'] ?? 0) as int) / 60000;

      final label = DateFormat('E', languageCode).format(day);

      weekPostureList.add(_ChartData(label, postureMins));
      weekStepsList.add(_ChartData(label, steps.toDouble()));
      weekSitStandList.add(_DualChartData(label, sitMins, standMins));
    }

    List<_ChartData> monthPostureList = [];
    List<_ChartData> monthStepsList = [];
    List<_DualChartData> monthSitStandList = [];

    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 1; i <= lastDay; i++) {
      final day = DateTime(now.year, now.month, i);
      final stats = allStatsRaw[day];
      final postureMins = ((stats?['totalUprightMs'] ?? 0) as int) / 60000;
      final steps = (stats?['maxSteps'] ?? 0) as int;
      final sitMins = ((stats?['totalSittingMs'] ?? 0) as int) / 60000;
      final standMins = ((stats?['totalStandingMs'] ?? 0) as int) / 60000;

      final label = i.toString();

      monthPostureList.add(_ChartData(label, postureMins));
      monthStepsList.add(_ChartData(label, steps.toDouble()));
      monthSitStandList.add(_DualChartData(label, sitMins, standMins));
    }

    _targetSteps = await AppSettings.getTargetSteps();
    final activityStats = await _repository.getTodayActivityStats();

    if (mounted) {
      setState(() {
        _heatmapData = heatmapMins;

        _weeklyData = weekPostureList;
        _monthlyData = monthPostureList;

        _weeklySteps = weekStepsList;
        _monthlySteps = monthStepsList;

        _weeklySitStand = weekSitStandList;
        _monthlySitStand = monthSitStandList;

        _todaySteps = activityStats['maxSteps'] ?? 0;
        _sittingMs = activityStats['totalSittingMs'] ?? 0;
        _standingMs = activityStats['totalStandingMs'] ?? 0;

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadStats,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        title: Text("statistics".tr()),
                        backgroundColor: colors.surface,
                        foregroundColor: colors.onSurface,
                        elevation: 0,
                        centerTitle: false,
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 8.0,
                          bottom: 100.0,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildSectionTitle(
                              "postureStatsTitle".tr(),
                              Icons.accessibility_new_rounded,
                            ),
                            const SizedBox(height: 12),

                            _buildPostureSummaryCards(colors),
                            const SizedBox(height: 12),

                            _buildHeatmapCard(colors),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionTitle(
                                  "Performance".tr(),
                                  Icons.bar_chart_rounded,
                                ),
                                _buildViewToggler(colors),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildPostureChartCard(colors),

                            const SizedBox(height: 24),
                            Divider(color: Colors.black.withValues(alpha: 0.2)),
                            const SizedBox(height: 24),

                            _buildSectionTitle(
                              "activity".tr(),
                              Icons.directions_walk_rounded,
                            ),
                            const SizedBox(height: 12),

                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildStepsCard(colors)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSitStandDonutCard(colors),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActivitySummaryCards(colors),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionTitle(
                                  "activityChartsTitle".tr(),
                                  Icons.bar_chart_rounded,
                                ),
                                _buildViewToggler(colors),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text("stepsChartTitle".tr()),
                            _buildStepsChartCard(colors),
                            const SizedBox(height: 12),
                            Text("sitStandChartTitle".tr()),
                            _buildSitStandChartCard(colors),
                            const SizedBox(height: 16),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    shadowColor: colors.primary.withValues(alpha: 0.3),
                    child: _buildReportsButton(colors),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHeatmapCard(ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: HeatMap(
          datasets: _heatmapData,
          colorMode: ColorMode.color,
          startDate: DateTime.now().subtract(const Duration(days: 90)),
          endDate: DateTime.now(),
          size: 14,
          fontSize: 8,
          textColor: colors.onSurface,
          showColorTip: false,
          scrollable: true,
          defaultColor: colors.surfaceContainerHighest,
          colorsets: {
            1: colors.primary.withValues(alpha: 0.2),
            30: colors.primary.withValues(alpha: 0.4),
            60: colors.primary.withValues(alpha: 0.6),
            90: colors.primary.withValues(alpha: 0.8),
            120: colors.primary,
          },
          onClick: (value) {
            SmartDialog.showToast(
              "${value.day}/${value.month}: ${_heatmapData[value] ?? 0} ${"minsUnit".tr()}",
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewToggler(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleItem("Week", colors),
          _buildToggleItem("Month", colors),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String type, ColorScheme colors) {
    final bool isSelected = _viewType == type;
    return GestureDetector(
      onTap: () => setState(() => _viewType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          type.tr(),
          style: TextStyle(
            color: isSelected ? colors.onPrimary : colors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildPostureChartCard(ColorScheme colors) {
    final data = _viewType == "Week" ? _weeklyData : _monthlyData;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 180,
          child: SfCartesianChart(
            key: ValueKey("posture_$_viewType"),
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            primaryYAxis: NumericAxis(
              labelFormat: '{value}m',
              majorTickLines: const MajorTickLines(size: 0),
              axisLine: const AxisLine(width: 0),
              majorGridLines: MajorGridLines(
                color: colors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            tooltipBehavior: TooltipBehavior(enable: true, header: ''),
            series: <CartesianSeries<_ChartData, String>>[
              ColumnSeries<_ChartData, String>(
                dataSource: data,
                xValueMapper: (_ChartData d, _) => d.label,
                yValueMapper: (_ChartData d, _) => d.value,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: colors.primary,
                width: _viewType == "Week" ? 0.6 : 0.8,
                spacing: 0.1,
                animationDuration: 500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsChartCard(ColorScheme colors) {
    final data = _viewType == "Week" ? _weeklySteps : _monthlySteps;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 180,
          child: SfCartesianChart(
            key: ValueKey("steps_$_viewType"),
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            primaryYAxis: NumericAxis(
              majorTickLines: const MajorTickLines(size: 0),
              axisLine: const AxisLine(width: 0),
              majorGridLines: MajorGridLines(
                color: colors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              header: 'stepCount'.tr(),
            ),
            series: <CartesianSeries<_ChartData, String>>[
              ColumnSeries<_ChartData, String>(
                dataSource: data,
                xValueMapper: (_ChartData d, _) => d.label,
                yValueMapper: (_ChartData d, _) => d.value,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: Colors.green,
                width: _viewType == "Week" ? 0.6 : 0.8,
                spacing: 0.1,
                animationDuration: 500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSitStandChartCard(ColorScheme colors) {
    final data = _viewType == "Week" ? _weeklySitStand : _monthlySitStand;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 180,
          child: SfCartesianChart(
            key: ValueKey("sitstand_$_viewType"),
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            primaryYAxis: NumericAxis(
              labelFormat: '{value}m',
              majorTickLines: const MajorTickLines(size: 0),
              axisLine: const AxisLine(width: 0),
              majorGridLines: MajorGridLines(
                color: colors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            tooltipBehavior: TooltipBehavior(enable: true, header: ''),
            series: <CartesianSeries<_DualChartData, String>>[
              ColumnSeries<_DualChartData, String>(
                name: 'sitting'.tr(),
                dataSource: data,
                xValueMapper: (_DualChartData d, _) => d.label,
                yValueMapper: (_DualChartData d, _) => d.value1,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: Colors.deepPurpleAccent,
                width: _viewType == "Week" ? 0.4 : 0.6,
                spacing: 0.1,
                animationDuration: 500,
              ),
              ColumnSeries<_DualChartData, String>(
                name: 'standing'.tr(),
                dataSource: data,
                xValueMapper: (_DualChartData d, _) => d.label,
                yValueMapper: (_DualChartData d, _) => d.value2,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: Colors.orangeAccent,
                width: _viewType == "Week" ? 0.4 : 0.6,
                spacing: 0.1,
                animationDuration: 500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostureSummaryCards(ColorScheme colors) {
    double totalMins = 0;
    for (var d in _monthlyData) {
      totalMins += d.value;
    }
    int activeDays = _monthlyData.where((d) => d.value > 0).length;
    int avgMins = activeDays > 0 ? (totalMins / activeDays).toInt() : 0;

    return Row(
      children: [
        _buildStatTile(
          "Avg Daily".tr(),
          "$avgMins m",
          Icons.timer_rounded,
          Colors.blue,
          colors,
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          "Total Mth".tr(),
          "${totalMins.toInt()} m",
          Icons.calendar_month_rounded,
          Colors.orange,
          colors,
        ),
      ],
    );
  }

  Widget _buildActivitySummaryCards(ColorScheme colors) {
    double totalSteps = 0;
    for (var d in _monthlySteps) {
      totalSteps += d.value;
    }
    int activeDays = _monthlySteps.where((d) => d.value > 0).length;
    int avgSteps = activeDays > 0 ? (totalSteps / activeDays).toInt() : 0;

    double totalSitMins = 0;
    for (var d in _monthlySitStand) {
      totalSitMins += d.value1;
    }
    int activeSitDays = _monthlySitStand.where((d) => d.value1 > 0).length;
    int avgSitMins = activeSitDays > 0
        ? (totalSitMins / activeSitDays).toInt()
        : 0;

    return Row(
      children: [
        _buildStatTile(
          "avgStepsPerDay".tr(),
          "$avgSteps",
          Icons.directions_run_rounded,
          Colors.green,
          colors,
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          "avgSittingPerDay".tr(),
          "$avgSitMins m",
          Icons.airline_seat_recline_normal_rounded,
          Colors.deepPurpleAccent,
          colors,
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ColorScheme colors,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard(ColorScheme colors) {
    double progress = _targetSteps > 0 ? _todaySteps / _targetSteps : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_run_rounded,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "todaySteps".tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$_todaySteps",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            "/ $_targetSteps ${"target".tr()}",
            style: TextStyle(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colors.outlineVariant.withValues(alpha: 0.2),
            color: Colors.green,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildSitStandDonutCard(ColorScheme colors) {
    int sitMins = _sittingMs ~/ 60000;
    int standMins = _standingMs ~/ 60000;

    List<_PieData> pieData = [
      _PieData("sitting".tr(), sitMins.toDouble(), Colors.deepPurpleAccent),
      _PieData("standing".tr(), standMins.toDouble(), Colors.orangeAccent),
    ];

    if (sitMins == 0 && standMins == 0) {
      pieData = [
        _PieData(
          "noData".tr(),
          1,
          colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      height: 130,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "sitStandRatio".tr(),
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SfCircularChart(
                    margin: EdgeInsets.zero,
                    series: <CircularSeries<_PieData, String>>[
                      DoughnutSeries<_PieData, String>(
                        dataSource: pieData,
                        xValueMapper: (_PieData data, _) => data.label,
                        yValueMapper: (_PieData data, _) => data.value,
                        pointColorMapper: (_PieData data, _) => data.color,
                        innerRadius: '60%',
                        animationDuration: 800,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sitMins > 0 || standMins > 0) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              color: Colors.deepPurpleAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$sitMins${"minsUnit".tr()}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$standMins${"minsUnit".tr()}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text("noData".tr(), style: TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsButton(ColorScheme colors) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReportsPage()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primaryContainer,
              colors.primaryContainer.withValues(alpha: 0.5),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: colors.onPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'reportsButton'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'reportsButtonSubtitle'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;
  _ChartData(this.label, this.value);
}

class _DualChartData {
  final String label;
  final double value1;
  final double value2;
  _DualChartData(this.label, this.value1, this.value2);
}

class _PieData {
  final String label;
  final double value;
  final Color color;
  _PieData(this.label, this.value, this.color);
}
