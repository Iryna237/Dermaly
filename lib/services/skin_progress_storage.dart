import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'skin_analysis_storage.dart';

/// Historique du suivi mensuel (Skin Progress).
/// - Point de départ : la toute première Skin Analysis du patient, prise dans
///   `users/{uid}/analyses`. Les analyses refaites ensuite (bouton central,
///   « New Analysis ») ne la déplacent pas.
/// - Puis un scan par mois, à partir du mois qui suit cette analyse :
///   `users/{uid}/skinScans/{yyyy-MM}`. L'écran Skin Progress ne propose un
///   nouveau scan qu'une fois le mois terminé.
/// - La photo de chaque mois est conservée dans le dossier documents de l'app (`skin_progress/`).
class SkinProgressStorage {
  static const String _collection = 'skinScans';
  static const String _imageDirName = 'skin_progress';

  static CollectionReference<Map<String, dynamic>>? _scans() {
    return SkinAnalysisStorage.userDoc()?.collection(_collection);
  }

  /// Première analyse enregistrée dans l'historique des analyses
  static Query<Map<String, dynamic>>? _firstAnalysis() {
    return SkinAnalysisStorage.userDoc()
        ?.collection('analyses')
        .orderBy('timestamp')
        .limit(1);
  }

  /// Point de départ du suivi, ou null si le patient n'a jamais fait d'analyse
  static Future<SkinAnalysisResult?> _baselineFrom(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final timestamp = data['timestamp'];
      // Écriture encore en attente du serveur : l'analyse vient d'être faite
      final analyzedAt = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
      final baseline = SkinAnalysisStorage.decode(
        {...data, 'analyzedAt': analyzedAt.millisecondsSinceEpoch},
        null,
      );
      return baseline?.copyWith(imagePath: await _startingPhotoPath(analyzedAt));
    }

    // Comptes antérieurs à l'historique des analyses : la dernière analyse sauvegardée
    return SkinAnalysisStorage.load();
  }

  /// Copie de la photo du point de départ, à part des photos d'analyse que
  /// chaque nouvelle analyse supprime. Une par compte : plusieurs patients
  /// peuvent utiliser le même téléphone. Null sur le web (pas de dossier).
  static Future<File?> _startingPhotoFile() async {
    final uid = SkinAnalysisStorage.userDoc()?.id;
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    if (uid == null || dir == null) return null;
    return File('${dir.path}/start_$uid.jpg');
  }

  /// Garde la photo de la première Skin Analysis comme photo du point de
  /// départ. À appeler après l'analyse, avant son ajout à l'historique des
  /// analyses : c'est la première si cet historique est encore vide.
  static Future<void> keepStartingPhoto(SkinAnalysisResult analysis) async {
    try {
      final file = await _startingPhotoFile();
      final analyses = SkinAnalysisStorage.userDoc()?.collection('analyses');
      if (file == null || analyses == null || analysis.imagePath.isEmpty) return;
      if (await file.exists()) return;

      final earlier = await analyses.limit(1).get();
      if (earlier.docs.isNotEmpty) return;

      await SkinAnalysisStorage.persistImage(
        analysis.imagePath,
        file.parent,
        file.uri.pathSegments.last,
      );
    } catch (e) {
      debugPrint('Impossible de garder la photo du point de départ: $e');
    }
  }

  /// Photo du point de départ analysé à [analyzedAt], ou chaîne vide.
  /// Pour les analyses faites avant la copie à part : si le patient n'a pas
  /// refait d'analyse depuis, sa photo est encore celle de la dernière
  /// analyse ; elle est alors copiée à part pour ne plus la perdre.
  static Future<String> _startingPhotoPath(DateTime analyzedAt) async {
    final file = await _startingPhotoFile();
    if (file != null && await file.exists()) return file.path;

    final last = await SkinAnalysisStorage.load();
    final lastAt = last?.analyzedAt;
    if (last == null || lastAt == null || last.imagePath.isEmpty) return '';
    // L'historique est écrit juste après la sauvegarde : quelques secondes d'écart
    if (lastAt.difference(analyzedAt).abs() > const Duration(minutes: 5)) return '';

    if (file == null) return last.imagePath;
    try {
      await SkinAnalysisStorage.persistImage(last.imagePath, file.parent, file.uri.pathSegments.last);
      return file.path;
    } catch (e) {
      debugPrint('Photo du point de départ introuvable: $e');
      return '';
    }
  }

  /// Suivi complet : le point de départ, puis les scans des mois qui le suivent.
  /// Sans analyse, il n'y a pas de suivi. Les scans faits le mois de l'analyse
  /// ou avant restent en base mais ne sont pas affichés.
  static List<SkinAnalysisResult> combine(
    SkinAnalysisResult? baseline,
    List<SkinAnalysisResult> scans,
  ) {
    final start = baseline?.analyzedAt;
    if (baseline == null || start == null) return const [];

    final startMonth = monthKey(start);
    return [
      baseline,
      for (final scan in scans)
        if (monthKey(scan.analyzedAt!).compareTo(startMonth) > 0) scan,
    ];
  }

  /// Clé du mois (date locale), utilisée comme identifiant du document
  static String monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static Future<List<SkinAnalysisResult>> _decodeAll(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    final scans = snapshot.docs
        .map((doc) => SkinAnalysisStorage.decode(doc.data(), dir))
        .whereType<SkinAnalysisResult>()
        .where((scan) => scan.analyzedAt != null)
        .toList()
      ..sort((a, b) => a.analyzedAt!.compareTo(b.analyzedAt!));

    // Un seul point par mois : le scan le plus récent représente son mois.
    // Regroupe aussi les anciens scans quotidiens, qui restent en base.
    final byMonth = <String, SkinAnalysisResult>{};
    for (final scan in scans) {
      byMonth[monthKey(scan.analyzedAt!)] = scan;
    }
    return byMonth.values.toList();
  }

  /// Suivi trié du plus ancien au plus récent, point de départ compris
  static Future<List<SkinAnalysisResult>> loadHistory() async {
    final scans = _scans();
    final first = _firstAnalysis();
    if (scans == null || first == null) return [];
    return combine(await _baselineFrom(await first.get()), await _decodeAll(await scans.get()));
  }

  /// Suivi en temps réel : émet d'abord le cache local puis se met à jour
  /// (réponse du serveur, première analyse, nouveau scan du mois)
  static Stream<List<SkinAnalysisResult>> watchHistory() {
    final scans = _scans();
    final first = _firstAnalysis();
    if (scans == null || first == null) return Stream.value(const []);

    late final StreamController<List<SkinAnalysisResult>> controller;
    StreamSubscription<SkinAnalysisResult?>? baselineSubscription;
    StreamSubscription<List<SkinAnalysisResult>>? scansSubscription;
    SkinAnalysisResult? baseline;
    var baselineLoaded = false;
    List<SkinAnalysisResult>? monthly;

    // N'émet qu'une fois les deux sources lues : sinon le suivi paraîtrait vide
    void emit() {
      final loadedScans = monthly;
      if (!baselineLoaded || loadedScans == null || controller.isClosed) return;
      controller.add(combine(baseline, loadedScans));
    }

    controller = StreamController<List<SkinAnalysisResult>>(
      onListen: () {
        baselineSubscription = first.snapshots().asyncMap(_baselineFrom).listen(
          (value) {
            baseline = value;
            baselineLoaded = true;
            emit();
          },
          onError: controller.addError,
        );
        scansSubscription = scans.snapshots().asyncMap(_decodeAll).listen(
          (value) {
            monthly = value;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await baselineSubscription?.cancel();
        await scansSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Enregistre le scan du mois. Le scan n'est proposé qu'à partir du mois qui
  /// suit la première analyse (voir [combine]).
  /// Retourne le scan avec le chemin de la photo persistée et la date du scan.
  static Future<SkinAnalysisResult> saveMonthScan(SkinAnalysisResult result) async {
    final analyzedAt = DateTime.now();
    final scans = _scans();
    if (scans == null) return result.copyWith(analyzedAt: analyzedAt);

    final month = monthKey(analyzedAt);
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    final imageFileName = 'scan_${month}_${analyzedAt.millisecondsSinceEpoch}.jpg';
    // Sur le web, pas de copie : on garde le chemin fourni par le sélecteur de photo
    var imagePath = result.imagePath;
    if (dir != null) {
      imagePath = '${dir.path}/$imageFileName';
      await SkinAnalysisStorage.persistImage(result.imagePath, dir, imageFileName);
    }

    final saved = result.copyWith(imagePath: imagePath, analyzedAt: analyzedAt);

    await SkinAnalysisStorage.writeWithTimeout(
      scans.doc(month).set(SkinAnalysisStorage.encode(saved, imageFileName: imageFileName)),
    );

    // Supprimer les photos des scans déjà faits ce mois-ci (remplacés, anciens scans
    // quotidiens compris) ; les photos des autres mois sont gardées
    if (dir == null) return saved;
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.startsWith('scan_$month') && name != imageFileName) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Impossible de supprimer l\'ancienne photo du mois: $e');
        }
      }
    }

    return saved;
  }
}
