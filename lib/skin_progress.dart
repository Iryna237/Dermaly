import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'make_skin_analysis.dart';
import 'services/gemini_service.dart';
import 'services/skin_progress_storage.dart';
import 'skin_analysis_progress.dart';
import 'skin_scan_comparison.dart';

/// Skin Progress : suivi quotidien de la peau.
/// Chaque jour, un scan est comparé au scan précédent et au premier scan
/// pour savoir si les produits utilisés sont efficaces.
class SkinProgressPage extends StatefulWidget {
  const SkinProgressPage({super.key});

  @override
  State<SkinProgressPage> createState() => _SkinProgressPageState();
}

class _SkinProgressPageState extends State<SkinProgressPage> {
  // Flux créé une seule fois : la page se met à jour toute seule après un nouveau scan
  late final Stream<List<SkinAnalysisResult>> _history = SkinProgressStorage.watchHistory();

  void _startDailyScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MakeSkinAnalysisPage(purpose: ScanPurpose.dailyProgress),
      ),
    );
  }

  void _openScan(List<SkinAnalysisResult> history, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkinScanComparisonPage(
          scan: history[index],
          previous: index > 0 ? history[index - 1] : null,
          first: index > 0 ? history.first : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPurple,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        // Bouton retour seulement si la page a été ouverte depuis l'accueil (pas depuis l'onglet Progress).
        // ModalRoute.canPop regarde la route de cette page, pas les pages ouvertes par-dessus (caméra, résultat)
        leading: ModalRoute.of(context)?.canPop == true
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Skin Progress',
          style: TextStyle(color: AppColors.darkPurple, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<SkinAnalysisResult>>(
        stream: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage(
              Icons.cloud_off_rounded,
              'Unable to load your progress',
              snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
          }

          final history = snapshot.data!;
          return history.isEmpty ? _buildEmptyState() : _buildProgress(history);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildMessage(
      Icons.show_chart_rounded,
      'Track your skin every day',
      'Take a quick face scan each day. Dermaly compares it with your previous scans '
      'so you can see which skin concerns improve or get worse, and whether your products are working.',
      action: _buildPrimaryButton("Start today's scan", Icons.camera_alt_rounded),
    );
  }

  Widget _buildMessage(IconData icon, String title, String details, {Widget? action}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: AppColors.terracotta),
            ),
            const SizedBox(height: 30),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
            const SizedBox(height: 15),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.greyText, height: 1.5),
            ),
            if (action != null) ...[
              const SizedBox(height: 40),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(List<SkinAnalysisResult> history) {
    final latest = history.last;
    final previous = history.length > 1 ? history[history.length - 2] : null;
    final first = history.length > 1 ? history.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        _buildTodayCard(latest),
        const SizedBox(height: 15),
        _buildScoreCard(history, previous, first),
        const SizedBox(height: 15),
        ProgressCard(
          icon: Icons.spa,
          iconColor: AppColors.brandPink,
          title: 'Skin Concerns',
          subtitle: previous == null
              ? 'Scan again tomorrow to compare your concerns'
              : 'Latest scan · lower is better · green = improved, red = worse',
          child: ConcernComparisonTable(scan: latest, previous: previous, first: first),
        ),
        const SizedBox(height: 15),
        _buildHistoryCard(history),
      ],
    );
  }

  Widget _buildTodayCard(SkinAnalysisResult latest) {
    final lastScanAt = latest.analyzedAt!;
    final scannedToday = SkinProgressStorage.dayKey(lastScanAt) == SkinProgressStorage.dayKey(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scannedToday ? Icons.check_circle_rounded : Icons.today_rounded,
                color: scannedToday ? ProgressDelta.improvedColor : AppColors.terracotta,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scannedToday ? "Today's scan is done" : "You haven't scanned today",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scannedToday
                          ? 'Scanned at ${formatScanTime(lastScanAt)} · a new scan today will replace it'
                          : 'Last scan: ${formatScanDate(lastScanAt)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.greyText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          scannedToday
              ? SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _startDailyScan,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Rescan today', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                )
              : _buildPrimaryButton('Scan today', Icons.camera_alt_rounded),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _startDailyScan,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    List<SkinAnalysisResult> history,
    SkinAnalysisResult? previous,
    SkinAnalysisResult? first,
  ) {
    final latest = history.last;
    // La courbe affiche les 30 derniers scans
    final recent = history.length > 30 ? history.sublist(history.length - 30) : history;

    return ProgressCard(
      icon: Icons.show_chart_rounded,
      iconColor: AppColors.primaryPurple,
      title: 'Skin Score Evolution',
      subtitle: '${history.length} ${history.length == 1 ? 'day' : 'days'} tracked',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${latest.overallScore}',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.terracotta),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  ' / 100',
                  style: TextStyle(fontSize: 18, color: AppColors.greyText, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildLabeledDelta(
                      'vs previous',
                      previous == null ? null : latest.overallScore - previous.overallScore,
                    ),
                    const SizedBox(height: 6),
                    _buildLabeledDelta(
                      'since start',
                      first == null ? null : latest.overallScore - first.overallScore,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recent.length > 1) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: ScoreChartPainter([for (final scan in recent) scan.overallScore]),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: ScoreChartPainter.leftPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatShortDate(recent.first.analyzedAt!), style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
                  Text(formatShortDate(recent.last.analyzedAt!), style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledDelta(String label, int? delta) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        const SizedBox(width: 6),
        ProgressDelta(delta: delta),
      ],
    );
  }

  Widget _buildHistoryCard(List<SkinAnalysisResult> history) {
    return ProgressCard(
      icon: Icons.history_rounded,
      iconColor: AppColors.terracotta,
      title: 'Scan History',
      subtitle: 'Tap a day to see its details',
      child: Column(
        children: [
          // Du plus récent au plus ancien
          for (var i = history.length - 1; i >= 0; i--) _buildHistoryRow(history, i),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(List<SkinAnalysisResult> history, int index) {
    final scan = history[index];
    final previous = index > 0 ? history[index - 1] : null;

    return InkWell(
      onTap: () => _openScan(history, index),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ScanPhoto(imagePath: scan.imagePath, width: 48, height: 48, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatScanDate(scan.analyzedAt!),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    index == 0 ? 'Starting point' : formatScanTime(scan.analyzedAt!),
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText),
                  ),
                ],
              ),
            ),
            Text(
              '${scan.overallScore}%',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.black),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: ProgressDelta(
                delta: previous == null ? null : scan.overallScore - previous.overallScore,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}

/// Courbe du skin score au fil des scans.
/// L'échelle verticale s'adapte aux valeurs pour que les petites variations restent visibles.
class ScoreChartPainter extends CustomPainter {
  static const double leftPadding = 28;
  static const double _verticalPadding = 10;

  final List<int> scores;

  const ScoreChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final minScore = scores.reduce(math.min);
    final maxScore = scores.reduce(math.max);
    var low = (((minScore - 10) / 10).floor() * 10).clamp(0, 100);
    var high = (((maxScore + 10) / 10).ceil() * 10).clamp(0, 100);
    if (high - low < 20) {
      if (high <= 80) {
        high = low + 20;
      } else {
        low = high - 20;
      }
    }

    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - _verticalPadding * 2;
    double yFor(num value) => _verticalPadding + chartHeight * (1 - (value - low) / (high - low));

    // Lignes de repère et graduations
    final gridPaint = Paint()
      ..color = AppColors.lightPurple
      ..strokeWidth = 1;
    for (final value in [low, (low + high) ~/ 2, high]) {
      final y = yFor(value);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(text: '$value', style: const TextStyle(fontSize: 10, color: AppColors.greyText)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    final points = [
      for (var i = 0; i < scores.length; i++)
        Offset(
          leftPadding + (scores.length == 1 ? chartWidth / 2 : chartWidth * i / (scores.length - 1)),
          yFor(scores[i]),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    // Dégradé sous la courbe
    final bottom = size.height - _verticalPadding;
    final area = Path.from(line)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryPurple.withAlpha(70), AppColors.primaryPurple.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primaryPurple
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Points de chaque scan, le dernier mis en avant
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final radius = isLast ? 6.0 : 4.0;
      canvas.drawCircle(points[i], radius, Paint()..color = AppColors.white);
      canvas.drawCircle(
        points[i],
        radius,
        Paint()
          ..color = (isLast ? AppColors.terracotta : AppColors.primaryPurple)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(ScoreChartPainter oldDelegate) => !listEquals(oldDelegate.scores, scores);
}
