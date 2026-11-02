import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/models/daily_report_model.dart';
import 'package:posture_corrector/core/repository/report_service.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';
import 'package:posture_corrector/view/reports/ai_onboarding_dialog.dart';
import 'package:posture_corrector/view/reports/eod_review_dialog.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportService _reportService = ReportService();

  List<DailyReport> _reports = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  final String _yesterday = ReportService.yesterday;

  bool _hasYesterdayReport = false;
  bool _hasYesterdayEod = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _reportService.getReports();
      final hasReport = await _reportService.hasReport(_yesterday);
      final hasEod = await _reportService.hasEodReview(_yesterday);

      if (mounted) {
        setState(() {
          _reports = reports;
          _hasYesterdayReport = hasReport;
          _hasYesterdayEod = hasEod;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGenerateReport() async {

    final profileSaved = await AppSettings.getAiProfileSaved();
    if (!profileSaved && mounted) {
      await showAiOnboardingDialog(
        context,
        onCompleted: () async {

          await _onGenerateReport();
        },
      );
      return;
    }

    if (!_hasYesterdayEod && mounted) {
      await showEodReviewDialog(
        context,
        date: _yesterday,
        onSaved: () async {
          setState(() => _hasYesterdayEod = true);

          await _generateReport();
        },
      );
      return;
    }

    await _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    SmartDialog.showLoading(msg: 'reportGenerating'.tr());

    try {
      final report = await _reportService.generateReport(_yesterday);
      SmartDialog.dismiss();
      if (mounted) {
        setState(() {
          _reports.insert(0, report);
          _hasYesterdayReport = true;
          _isGenerating = false;
        });
      }
      SmartDialog.showToast('reportGenerated'.tr());
    } catch (e) {
      SmartDialog.dismiss();
      if (mounted) setState(() => _isGenerating = false);

      String msg;
      if (e.toString().contains('eod_required')) {
        msg = 'reportEodRequired'.tr();
      } else if (e.toString().contains('empty_response')) {
        msg = 'reportEmptyResponse'.tr();
      } else {
        msg = 'reportGenerateError'.tr();
      }
      SmartDialog.showToast(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text('reportsTitle'.tr()),
              backgroundColor: colors.surface,
              foregroundColor: colors.onSurface,
              elevation: 0,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([

                        if (!_hasYesterdayReport) ...[
                          _buildGenerateCard(colors),
                          const SizedBox(height: 16),
                        ],

                        if (_reports.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'pastReports'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        ..._reports.map((r) => _buildReportTile(r, colors)),

                        if (_reports.isEmpty && _hasYesterdayReport) ...[
                          const SizedBox(height: 60),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 48,
                                  color: colors.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'noReports'.tr(),
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'reportYesterdayTitle'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _yesterday,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_hasYesterdayEod) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colors.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'reportEodWarning'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _onGenerateReport,
              icon: _isGenerating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _hasYesterdayEod
                    ? 'generateReport'.tr()
                    : 'evaluateDayFirst'.tr(),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(DailyReport report, ColorScheme colors) {
    final date = DateTime.fromMillisecondsSinceEpoch(report.createdAt);
    final formattedDate = DateFormat('d MMM y', 'tr').format(
      DateTime.tryParse(report.date) ?? date,
    );
    final preview = report.content.length > 80
        ? '${report.content.substring(0, 80)}…'
        : report.content;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Theme(

          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.article_rounded,
                color: colors.primary,
                size: 18,
              ),
            ),
            title: Text(
              formattedDate,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              preview,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Divider(
                color: colors.outlineVariant.withValues(alpha: 0.3),
                height: 16,
              ),
              Text(
                report.content,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
