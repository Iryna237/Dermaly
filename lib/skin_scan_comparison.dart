import 'dart:io';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'services/gemini_service.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String formatScanDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';

String formatShortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

String formatScanTime(DateTime date) {
  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final amPm = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${date.minute.toString().padLeft(2, '0')} $amPm';
}

/// Nombre de concerns améliorés / régressés entre [reference] et [scan]
({int improved, int worsened}) countConcernChanges(
  SkinAnalysisResult scan,
  SkinAnalysisResult reference,
) {
  var improved = 0;
  var worsened = 0;
  scan.concerns.forEach((key, value) {
    final before = reference.concerns[key];
    if (before == null || before == value) return;
    if (value < before) {
      improved++;
    } else {
      worsened++;
    }
  });
  return (improved: improved, worsened: worsened);
}

/// Photo locale d'un scan, avec un placeholder si elle n'existe plus sur l'appareil
class ScanPhoto extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final double radius;

  const ScanPhoto({
    super.key,
    required this.imagePath,
    required this.width,
    required this.height,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.softPurple,
      child: const Icon(Icons.person, color: AppColors.primaryPurple),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imagePath.isEmpty
          ? placeholder
          : Image.file(
              File(imagePath),
              width: width,
              height: height,
              fit: BoxFit.cover,
              // Décoder en taille réduite : l'historique peut contenir beaucoup de photos
              cacheWidth: (width * 3).round(),
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}

/// Variation d'une valeur entre deux scans.
/// [higherIsBetter] : vrai pour le score et l'hydratation, faux pour les concerns (sévérité).
class ProgressDelta extends StatelessWidget {
  static const Color improvedColor = Color(0xFF2E9E5B);
  static const Color worsenedColor = Color(0xFFD9534F);

  final int? delta;
  final bool higherIsBetter;
  final double fontSize;

  const ProgressDelta({
    super.key,
    required this.delta,
    this.higherIsBetter = true,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final value = delta;
    if (value == null || value == 0) {
      return Text(
        value == null ? '—' : '=',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.greyText),
      );
    }

    final improved = higherIsBetter ? value > 0 : value < 0;
    final color = improved ? improvedColor : worsenedColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: fontSize + 2,
          color: color,
        ),
        Text(
          '${value.abs()}',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

/// Carte blanche avec icône et titre, utilisée par les pages Skin Progress
class ProgressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget child;

  const ProgressCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

/// Tableau des concerns : valeur actuelle, variation depuis le scan précédent et depuis le premier scan.
/// Une baisse de sévérité = amélioration (vert), une hausse = régression (rouge).
class ConcernComparisonTable extends StatelessWidget {
  final SkinAnalysisResult scan;
  final SkinAnalysisResult? previous;
  final SkinAnalysisResult? first;

  const ConcernComparisonTable({
    super.key,
    required this.scan,
    this.previous,
    this.first,
  });

  int? _delta(MapEntry<String, int> entry, SkinAnalysisResult? reference) {
    final before = reference?.concerns[entry.key];
    return before == null ? null : entry.value - before;
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.greyText);

    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: SizedBox()),
            SizedBox(width: 48, child: Text('Now', textAlign: TextAlign.end, style: headerStyle)),
            SizedBox(width: 64, child: Text('vs prev.', textAlign: TextAlign.end, style: headerStyle)),
            SizedBox(width: 72, child: Text('since start', textAlign: TextAlign.end, style: headerStyle)),
          ],
        ),
        const SizedBox(height: 10),
        for (final entry in scan.concerns.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.key, style: const TextStyle(fontSize: 14, color: AppColors.black)),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${entry.value}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ProgressDelta(delta: _delta(entry, previous), higherIsBetter: false),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ProgressDelta(delta: _delta(entry, first), higherIsBetter: false),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Résultat d'un scan quotidien comparé au scan précédent et au premier scan
class SkinScanComparisonPage extends StatelessWidget {
  final SkinAnalysisResult scan;
  final SkinAnalysisResult? previous;
  final SkinAnalysisResult? first;

  /// Vrai juste après un scan (sinon : consultation d'un jour de l'historique)
  final bool justScanned;

  const SkinScanComparisonPage({
    super.key,
    required this.scan,
    this.previous,
    this.first,
    this.justScanned = false,
  });

  @override
  Widget build(BuildContext context) {
    final analyzedAt = scan.analyzedAt ?? DateTime.now();
    final previousScan = previous;
    final firstScan = first;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          justScanned ? 'Daily Scan Result' : 'Scan Details',
          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              justScanned ? 'Your skin today ✨' : 'Your skin on ${formatShortDate(analyzedAt)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.black),
            ),
            const SizedBox(height: 5),
            Text(
              'Scanned on ${formatScanDate(analyzedAt)} • ${formatScanTime(analyzedAt)}',
              style: const TextStyle(fontSize: 14, color: AppColors.greyText),
            ),
            const SizedBox(height: 25),
            _buildScoreRow(),
            const SizedBox(height: 20),
            if (previousScan == null)
              _buildInfoBanner(
                Icons.flag_rounded,
                'This is your first progress scan and your starting point. '
                'Scan again tomorrow to see how your skin evolves.',
              )
            else
              _buildChangesSummary(previousScan),
            if (firstScan != null) ...[
              const SizedBox(height: 15),
              _buildPhotoComparison(firstScan),
            ],
            const SizedBox(height: 15),
            ProgressCard(
              icon: Icons.spa,
              iconColor: AppColors.brandPink,
              title: 'Skin Concerns',
              subtitle: 'Lower is better · green = improved, red = worse',
              child: ConcernComparisonTable(scan: scan, previous: previousScan, first: firstScan),
            ),
            const SizedBox(height: 15),
            ProgressCard(
              icon: Icons.water_drop,
              iconColor: Colors.blue,
              title: 'Hydration Level',
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: scan.hydrationLevel / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.softPurple,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text('${scan.hydrationLevel}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  ProgressDelta(
                    delta: previousScan == null ? null : scan.hydrationLevel - previousScan.hydrationLevel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  'Back to Skin Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScanPhoto(imagePath: scan.imagePath, width: 140, height: 180, radius: 20),
        const SizedBox(width: 15),
        Expanded(
          child: SizedBox(
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: scan.overallScore / 100,
                        strokeWidth: 10,
                        backgroundColor: AppColors.softPurple,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Skin Score',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkPurple),
                        ),
                        Text(
                          '${scan.overallScore}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.black),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildScoreDelta('vs previous', previous),
                const SizedBox(height: 4),
                _buildScoreDelta('since start', first),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDelta(String label, SkinAnalysisResult? reference) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label  ', style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        ProgressDelta(delta: reference == null ? null : scan.overallScore - reference.overallScore),
      ],
    );
  }

  Widget _buildChangesSummary(SkinAnalysisResult previousScan) {
    final changes = countConcernChanges(scan, previousScan);
    final scoreDelta = scan.overallScore - previousScan.overallScore;
    final trend = scoreDelta > 0
        ? 'Your skin score went up by $scoreDelta points'
        : scoreDelta < 0
            ? 'Your skin score went down by ${-scoreDelta} points'
            : 'Your skin score is stable';
    final since = previousScan.analyzedAt == null ? '' : ' (${formatShortDate(previousScan.analyzedAt!)})';

    return _buildInfoBanner(
      Icons.insights_rounded,
      '$trend since your previous scan$since. '
      '${changes.improved} concern(s) improved, ${changes.worsened} got worse.',
    );
  }

  Widget _buildInfoBanner(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.darkPurple, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoComparison(SkinAnalysisResult firstScan) {
    return ProgressCard(
      icon: Icons.compare_rounded,
      iconColor: AppColors.terracotta,
      title: 'First scan vs this scan',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildPhotoColumn(firstScan, 'First scan')),
          const SizedBox(width: 12),
          Expanded(child: _buildPhotoColumn(scan, justScanned ? 'Today' : 'This scan')),
        ],
      ),
    );
  }

  Widget _buildPhotoColumn(SkinAnalysisResult item, String label) {
    final date = item.analyzedAt == null ? '' : '${formatShortDate(item.analyzedAt!)} • ';
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ScanPhoto(
            imagePath: item.imagePath,
            width: constraints.maxWidth,
            height: constraints.maxWidth * 1.25,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
          Text('$date${item.overallScore}%', style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        ],
      ),
    );
  }
}
