import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/models/posture_data.dart';
import 'package:posture_corrector/core/utils/app_sizes.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/repository/ble_service.dart';
import 'package:posture_corrector/core/repository/posture_persistence_manager.dart';
import 'package:posture_corrector/core/utils/app_events.dart';
import 'package:posture_corrector/view/widgets/weekly_progress_header.dart';
import 'package:posture_corrector/view/widgets/posture_stick_figure.dart';
import 'package:posture_corrector/view/widgets/posture_debug_table.dart';
import 'package:posture_corrector/core/utils/notification_service.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';
import 'package:posture_corrector/core/repository/achievement_service.dart';
import 'package:posture_corrector/view/home/calibration_page.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
  final ValueNotifier<Map<int, double>> _weeklyPostureNotifier = ValueNotifier(
    {},
  );
  final ValueNotifier<Map<int, double>> _weeklyStepsNotifier = ValueNotifier(
    {},
  );
  final ValueNotifier<Map<int, double>> _weeklyStandingNotifier = ValueNotifier(
    {},
  );
  final SqlitePostureRepository _repository = SqlitePostureRepository();

  int _targetPostureMins = 120;
  int _targetSteps = 5000;
  int _targetStandingMins = 60;
  String _displayName = "";
  String? _photoBase64;
  String? _photoURL;

  String _selectedDayName = "";
  int _selectedWeekday = DateTime.now().weekday;

  bool _isSyncing = false;
  bool _needsSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppEvents.refreshNotifier.addListener(_loadHeaderData);
    _loadHeaderData();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await NotificationService().setupFCM();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppEvents.refreshNotifier.removeListener(_loadHeaderData);
    super.dispose();
  }

  Future<void> _loadHeaderData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _displayName = data['displayName'] ?? user.displayName ?? "User";
            _photoBase64 = data['photoBase64'];
            _photoURL = data['photoURL'];

          });
        }
      }

      final tP = await AppSettings.getTargetDurationMins();
      final tS = await AppSettings.getTargetSteps();
      final tSt = await AppSettings.getTargetStandingMins();

      if (mounted) {
        setState(() {
          _targetPostureMins = tP;
          _targetSteps = tS;
          _targetStandingMins = tSt;
        });
      }

      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _selectedDayName = DateFormat(
            'EEEE',
            context.locale.languageCode,
          ).format(now);
        });
      }

      _syncWeeklyStats(isInitial: true);
    } catch (e) {
      AppLogger.e("Error loading header data", e);
    }
  }

  Future<void> _syncWeeklyStats({
    bool isManual = false,
    bool isInitial = false,
  }) async {
    if (_isSyncing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {

      if (isInitial) {
        final isEmpty = await _repository.isEmpty();
        if (isEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists && doc.data()?.containsKey('weeklyStats') == true) {
            final firestoreStats =
                doc.data()!['weeklyStats'] as Map<String, dynamic>;

            final now = DateTime.now();
            final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final startOfMonday = DateTime(
              firstDayOfWeek.year,
              firstDayOfWeek.month,
              firstDayOfWeek.day,
            );

            for (var entry in firestoreStats.entries) {
              final dayIndexStr = entry.key;
              final dayIndex = int.tryParse(dayIndexStr) ?? 1;
              final day = startOfMonday.add(Duration(days: dayIndex - 1));
              final dayKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

              final data = entry.value as Map<String, dynamic>;

              await _repository.saveSummary(
                day: dayKey,
                uprightMs: (data['uprightMins'] ?? 0) * 60000,
                steps: (data['steps'] ?? 0) as int,
                sittingMs: (data['sittingMins'] ?? 0) * 60000,
                standingMs: (data['standingMins'] ?? 0) * 60000,
              );
            }
          }
        }
      }

      final threshold = await AppSettings.getUprightThreshold();
      final target = await AppSettings.getTargetDurationMins();
      final targetSteps = await AppSettings.getTargetSteps();
      final targetStanding = await AppSettings.getTargetStandingMins();

      final statsJson = await _repository.calculateWeeklyStatsJson(
        threshold,
        target,
      );

      if (mounted) {
        setState(() {
          _targetPostureMins = target;
          _targetSteps = targetSteps;
          _targetStandingMins = targetStanding;

          Map<int, double> pP = {};
          Map<int, double> pS = {};
          Map<int, double> pSt = {};

          statsJson.forEach((key, value) {
            int k = int.parse(key);
            pP[k] = (value['postureProgress'] as num).toDouble();
            pS[k] = _targetSteps > 0
                ? (value['steps'] as num).toDouble() / _targetSteps
                : 0.0;
            pSt[k] = _targetStandingMins > 0
                ? (value['standingMins'] as num).toDouble() /
                      _targetStandingMins
                : 0.0;
          });

          _weeklyPostureNotifier.value = Map.from(pP);
          _weeklyStepsNotifier.value = Map.from(pS);
          _weeklyStandingNotifier.value = Map.from(pSt);
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'weeklyStats': statsJson,
            'targetDuration': target,
            'targetSteps': targetSteps,
            'targetStandingDuration': targetStanding,
            'lastSync': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _needsSync = false;
        });
      }

      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final friendsCount =
          (friendsSnapshot.data()?['friends'] as List?)?.length ?? 0;
      await AchievementService().checkAndAwardAchievements(
        stats: statsJson,
        friendCount: friendsCount,
      );

      if (isManual) {
        SmartDialog.showToast("Senkronizasyon başarılı!");
      }
    } catch (e) {
      AppLogger.e("Background sync failed", e);
      String errorMsg = "Senkronizasyon hatası!";
      if (e.toString().contains("Quota exceeded") ||
          e.toString().contains("RESOURCE_EXHAUSTED")) {
        errorMsg = "Firebase kotası doldu! Yarın tekrar deneyin.";
      } else if (e.toString().contains("TimeoutException")) {
        errorMsg = "Bağlantı zaman aşımına uğradı.";
      }
      if (isManual) SmartDialog.showToast(errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _syncWeeklyStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: WeeklyProgressHeaderDelegate(
              weeklyPostureNotifier: _weeklyPostureNotifier,
              weeklyStepsNotifier: _weeklyStepsNotifier,
              weeklyStandingNotifier: _weeklyStandingNotifier,
              targetPostureMins: _targetPostureMins,
              targetSteps: _targetSteps,
              targetStandingMins: _targetStandingMins,
              displayName: _displayName,
              photoBase64: _photoBase64,
              photoURL: _photoURL,
              selectedDayName: _selectedDayName,
              selectedWeekday: _selectedWeekday,
              isSyncing: _isSyncing,
              needsSync: _needsSync,
              onSyncTap: () => _syncWeeklyStats(isManual: true),
              onDayTap: (weekday) async {
                final now = DateTime.now();
                final dayDate = now.subtract(
                  Duration(days: now.weekday - weekday),
                );
                final dayName = DateFormat(
                  'EEEE',
                  context.locale.languageCode,
                ).format(dayDate);

                setState(() {
                  _selectedDayName = dayName;
                  _selectedWeekday = weekday;
                });
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                if (index == 0) {
                  return HomePageMainWidget(
                    onNewData:
                        ({
                          required upright,
                          required steps,
                          required standing,
                        }) {
                          final today = DateTime.now().weekday;

                          final p = _weeklyPostureNotifier.value;
                          final s = _weeklyStepsNotifier.value;
                          final st = _weeklyStandingNotifier.value;

                          p[today] = _targetPostureMins > 0
                              ? upright.inSeconds / (_targetPostureMins * 60)
                              : 0.0;
                          s[today] = _targetSteps > 0
                              ? steps / _targetSteps
                              : 0.0;
                          st[today] = _targetStandingMins > 0
                              ? standing.inSeconds / (_targetStandingMins * 60)
                              : 0.0;

                          _weeklyPostureNotifier.value = Map.from(p);
                          _weeklyStepsNotifier.value = Map.from(s);
                          _weeklyStandingNotifier.value = Map.from(st);

                          if (!_needsSync) {
                            setState(() {
                              _needsSync = true;
                            });
                          }
                        },
                  );
                }
                return const SizedBox.shrink();
              }, childCount: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  _ChartData(this.category, this.value, this.color, this.durationText);
  final String category;
  final double value;
  final Color color;
  final String durationText;
}

class HomePageMainWidget extends StatefulWidget {
  final Function({
    required Duration upright,
    required int steps,
    required Duration standing,
  })?
  onNewData;
  const HomePageMainWidget({super.key, this.onNewData});

  @override
  State<HomePageMainWidget> createState() => _HomePageMainWidgetState();
}

class _HomePageMainWidgetState extends State<HomePageMainWidget> {
  final PosturePersistenceManager _persistenceManager =
      PosturePersistenceManager();
  final SqlitePostureRepository _repository = SqlitePostureRepository();
  final BleService _bleService = BleService();

  StreamSubscription<PostureData>? _dataSubscription;
  StreamSubscription<bool>? _bulkSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  bool _isVibrationOn = true;
  int _vibrationDelay = 5;
  double _uprightThreshold = 15.0;
  int _targetDurationMins = 120;
  int _targetSteps = 5000;
  int _targetStandingMins = 60;

  Duration _todayUprightDuration = Duration.zero;
  int _todaySteps = 0;
  Duration _todayStandingDuration = Duration.zero;

  bool _isConnecting = false;
  bool _isBulkSyncing = false;
  bool _showDebugTable = false;

  int? _lastLiveTimestamp;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndData();
    _startRecording();
    _autoConnect();

    _connectionSubscription = _bleService.connectionStateStream.listen((
      isConnected,
    ) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
      if (isConnected) {
        int epochMs = DateTime.now().millisecondsSinceEpoch;
        _bleService.sendData(
          '{"vibration": $_isVibrationOn, "delay": $_vibrationDelay, "thresholdAngle": $_uprightThreshold, "syncTime": $epochMs}',
        );
      }
    });
  }

  Future<void> _autoConnect() async {
    setState(() {
      _isConnecting = true;
    });
    bool success = await _bleService.connectAndListen();
    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      if (!success) {
        SmartDialog.showToast("deviceNotFound".tr());
      }
    }
  }

  Future<void> _loadSettingsAndData() async {
    _uprightThreshold = await AppSettings.getUprightThreshold();
    _targetDurationMins = await AppSettings.getTargetDurationMins();
    _targetSteps = await AppSettings.getTargetSteps();
    _targetStandingMins = await AppSettings.getTargetStandingMins();
    _isVibrationOn = await AppSettings.getVibrationEnabled();
    _vibrationDelay = await AppSettings.getVibrationDelay();

    final dur = await _repository.calculateTodayUprightDuration(
      _uprightThreshold,
    );
    final activity = await _repository.getTodayActivityStats();

    if (mounted) {
      setState(() {
        _todayUprightDuration = dur;
        _todaySteps = activity['maxSteps'] ?? 0;
        _todayStandingDuration = Duration(
          milliseconds: activity['totalStandingMs'] ?? 0,
        );
      });
    }
  }

  void _startRecording() {

    _dataSubscription = _persistenceManager.postureDataStream.listen((
      postureData,
    ) {
      if (mounted) {
        setState(() {

          final int currentTs = postureData.timestamp;
          if (_lastLiveTimestamp != null) {
            final int diffMs = currentTs - _lastLiveTimestamp!;

            if (diffMs > 0 && diffMs <= 5000) {
              if (postureData.postureState == 0) {
                _todayUprightDuration += Duration(milliseconds: diffMs);
              }
              if (postureData.sitting == 0) {
                _todayStandingDuration += Duration(milliseconds: diffMs);
              }
            }
          }
          _lastLiveTimestamp = currentTs;

          _todaySteps = postureData.stepCount;

          widget.onNewData?.call(
            upright: _todayUprightDuration,
            steps: _todaySteps,
            standing: _todayStandingDuration,
          );
        });
      }
    });

    _bulkSubscription = _persistenceManager.bulkSyncStream.listen((
      isSyncing,
    ) async {
      if (mounted) {
        setState(() {
          _isBulkSyncing = isSyncing;
        });
      }

      if (!isSyncing) {

        _lastLiveTimestamp = null;
        final dur = await _repository.calculateTodayUprightDuration(
          _uprightThreshold,
        );
        final activity = await _repository.getTodayActivityStats();
        if (mounted) {
          setState(() {
            _todayUprightDuration = dur;
            _todaySteps = activity['maxSteps'] ?? 0;
            _todayStandingDuration = Duration(
              milliseconds: activity['totalStandingMs'] ?? 0,
            );

            widget.onNewData?.call(
              upright: _todayUprightDuration,
              steps: _todaySteps,
              standing: _todayStandingDuration,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _bulkSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  double get _progressPercent {
    int targetSecs = _targetDurationMins * 60;
    if (targetSecs == 0) return 0;
    double pct = _todayUprightDuration.inSeconds / targetSecs;
    return pct > 1.0 ? 1.0 : pct;
  }

  Future<void> _showDelayDialog() async {
    int? selectedDelay = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("vibSlopDur".tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("2 Saniye (Test)"),
                onTap: () => Navigator.pop(context, 2),
              ),
              ListTile(
                title: const Text("5 Saniye"),
                onTap: () => Navigator.pop(context, 5),
              ),
              ListTile(
                title: const Text("10 Saniye"),
                onTap: () => Navigator.pop(context, 10),
              ),
              ListTile(
                title: const Text("15 Saniye"),
                onTap: () => Navigator.pop(context, 15),
              ),
            ],
          ),
        );
      },
    );

    if (selectedDelay != null) {
      setState(() {
        _vibrationDelay = selectedDelay;
      });
      await AppSettings.setVibrationDelay(selectedDelay);
      _bleService.sendData('{"delay": $selectedDelay}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    AppSettings.getTargetDurationMins().then((val) {
      if (mounted && _targetDurationMins != val) {
        setState(() {
          _targetDurationMins = val;
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSizes.cardRadiusBig),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: AppSizes.cardPadding,
      child: StreamBuilder<bool>(
        stream: _bleService.connectionStateStream,
        initialData: _bleService.isConnected,
        builder: (context, connectionSnapshot) {
          bool isConnected = connectionSnapshot.data ?? false;

          if (!isConnected) {
            return _buildDisconnectedState(colors);
          }

          return _buildConnectedState(colors);
        },
      ),
    );
  }

  Widget _buildDisconnectedState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isConnecting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                "searchingSensor".tr(),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Icon(
                Icons.bluetooth_disabled,
                size: 60,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(height: 16),
              Text(
                "deviceDisconnected".tr(),
                style: TextStyle(
                  fontSize: 20,
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isConnecting
                    ? null
                    : () {
                        _autoConnect();
                      },
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth),
                label: Text(
                  _isConnecting ? "connecting".tr() : "connectToSensor".tr(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      int m = duration.inMinutes.remainder(60);
      return "${duration.inHours} ${"hoursUnit".tr()} $m ${"minsUnit".tr()}";
    } else {
      int m = duration.inMinutes;
      int s = duration.inSeconds.remainder(60);
      return "$m ${"minsUnit".tr()} $s ${"secsUnit".tr()}";
    }
  }

  Widget _buildConnectedState(ColorScheme colors) {
    return StreamBuilder<String>(
      stream: _bleService.dataStream,
      builder: (context, snapshot) {
        PostureData? liveData;
        String? rawJson;
        if (snapshot.hasData) {
          rawJson = snapshot.data!;
          try {
            liveData = PostureData.fromJson(jsonDecode(rawJson));
          } catch (_) {
            liveData = null;
          }
        }
        return _buildConnectedBody(colors, liveData, rawJson);
      },
    );
  }

  Widget _buildConnectedBody(
    ColorScheme colors,
    PostureData? liveData,
    String? rawJson,
  ) {
    final double percent = _progressPercent * 100;
    int totalMins = _targetDurationMins;
    Duration remaining = Duration(minutes: totalMins) - _todayUprightDuration;
    if (remaining.isNegative) remaining = Duration.zero;

    final List<_ChartData> chartData = [
      _ChartData(
        'completed'.tr(),
        percent,
        colors.primary,
        _formatDuration(_todayUprightDuration),
      ),
      _ChartData(
        'remaining'.tr(),
        100 - percent,
        colors.surfaceContainerHighest,
        _formatDuration(remaining),
      ),
    ];

    return Stack(
      children: [
        Column(
          spacing: AppSizes.p8,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 8.0,
                      children: [
                        CircularDayProgressIndicator(
                          progressPosture: _progressPercent,
                          progressSteps: _targetSteps > 0
                              ? _todaySteps / _targetSteps
                              : 0.0,
                          progressStanding: _targetStandingMins > 0
                              ? _todayStandingDuration.inSeconds /
                                    (_targetStandingMins * 60)
                              : 0.0,
                          isFuture: false,
                        ),
                        Text(
                          "${"target".tr()}: ${percent.toStringAsFixed(0)}%",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "homeTargetSubtitle".tr(
                        namedArgs: {
                          'target': _targetDurationMins.toString(),
                          'current': _todayUprightDuration.inMinutes.toString(),
                        },
                      ),
                      style: TextStyle(color: colors.outline, fontSize: 12),
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      liveData != null
                          ? BatteryShowcase(
                              batteryLevel: liveData.batteryLevel,
                              isCharging: liveData.isCharging,
                            )
                          : const SizedBox.shrink(),
                      IconButton(
                        onPressed: () => _bleService.disconnect(),
                        icon: Icon(
                          Icons.power_settings_new,
                          color: colors.error,
                        ),
                        tooltip: "disconnect".tr(),
                      ),

                    ],
                  ),
                ),
              ],
            ),

            SizedBox(
              width: double.infinity,
              height: 300,
              child: Stack(
                alignment: AlignmentGeometry.center,
                children: [
                  SfCircularChart(
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      builder:
                          (
                            dynamic data,
                            dynamic point,
                            dynamic series,
                            int pointIndex,
                            int seriesIndex,
                          ) {
                            final _ChartData cData = data as _ChartData;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.onSurface.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${cData.category}: ${cData.durationText}",
                                style: TextStyle(
                                  color: colors.surface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                    ),
                    series: <CircularSeries<_ChartData, String>>[
                      DoughnutSeries<_ChartData, String>(
                        innerRadius: '80%',
                        radius: '100%',
                        dataSource: chartData,
                        pointColorMapper: (_ChartData data, _) => data.color,
                        xValueMapper: (_ChartData data, _) => data.category,
                        yValueMapper: (_ChartData data, _) => data.value,
                      ),
                    ],
                  ),

                  if (rawJson == null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 50,
                          color: colors.primary,
                        ),
                      ],
                    )
                  else if (liveData == null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 50,
                          color: colors.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "dataNotReceived".tr(),
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    )
                  else
                    PostureStickFigure(
                      pitchUpper: liveData.pitchUpper,
                      pitchLower: liveData.pitchLower,
                      postureState: liveData.postureState,
                      stepCount: liveData.stepCount,
                    ),
                ],
              ),
            ),

            if (liveData != null)
              if (liveData.postureState == 0)
                Text(
                  "correctPostureState".tr(),
                  style: TextStyle(color: Colors.green),
                )
              else if (liveData.postureState == 1)
                Text(
                  "wrongPostureSlouching".tr(),
                  style: TextStyle(color: Colors.deepOrange),
                )
              else if (liveData.postureState == 2)
                Text(
                  "wrongPostureBack".tr(),
                  style: TextStyle(color: Colors.red),
                )
              else if (liveData.postureState == 3)
                Text(
                  "wrongPostureBoth".tr(),
                  style: TextStyle(color: Colors.black54),
                ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _showDebugTable = !_showDebugTable),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showDebugTable
                              ? Icons.keyboard_arrow_up
                              : Icons.bug_report,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showDebugTable ? "hideDebug".tr() : "showDebug".tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showDebugTable && liveData != null && rawJson != null)
                  PostureDebugTable(rawJson: rawJson, data: liveData),
              ],
            ),
            SizedBox(height: AppSizes.p4),

            Row(
              spacing: AppSizes.p8,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalibrationPage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: colors.onSecondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.multiline_chart_sharp,
                            color: colors.secondaryContainer,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "calibration".tr(),
                            style: TextStyle(color: colors.secondaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      bool newVal = !_isVibrationOn;
                      setState(() {
                        _isVibrationOn = newVal;
                      });
                      await AppSettings.setVibrationEnabled(newVal);
                      _bleService.sendData('{"vibration": $newVal}');
                    },
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: _isVibrationOn
                            ? colors.primary
                            : colors.onSecondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isVibrationOn ? Icons.vibration : Icons.smartphone,
                            color: _isVibrationOn
                                ? colors.onPrimary
                                : colors.secondaryContainer,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "vibration".tr(),
                            style: TextStyle(
                              color: _isVibrationOn
                                  ? colors.onPrimary
                                  : colors.secondaryContainer,
                            ),
                          ),

                          Switch(
                            value: _isVibrationOn,
                            onChanged: (val) async {
                              setState(() {
                                _isVibrationOn = val;
                              });
                              await AppSettings.setVibrationEnabled(val);
                              _bleService.sendData('{"vibration": $val}');
                            },
                            activeThumbColor: colors.secondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showDelayDialog,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: colors.onSecondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, color: colors.secondaryContainer),
                          const SizedBox(height: 4),
                          Text(
                            "vibSlopDur".tr(),
                            style: TextStyle(color: colors.secondaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_isBulkSyncing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      "syncing".tr(),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BatteryShowcase extends StatelessWidget {
  const BatteryShowcase({
    super.key,
    required this.batteryLevel,
    required this.isCharging,
  });
  final int batteryLevel;
  final bool isCharging;
  IconData get _icon {
    if (isCharging) return Icons.battery_charging_full_rounded;
    if (batteryLevel >= 80) return Icons.battery_full_rounded;
    if (batteryLevel >= 60) return Icons.battery_6_bar_rounded;
    if (batteryLevel >= 40) return Icons.battery_4_bar_rounded;
    if (batteryLevel >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          _icon,
          color: _icon == Icons.battery_alert_rounded
              ? Colors.red
              : Colors.green,
        ),
        Text(
          "$batteryLevel%",
          style: TextStyle(
            color: _icon == Icons.battery_alert_rounded
                ? Colors.red
                : Colors.green,
          ),
        ),
      ],
    );
  }
}
