import 'package:bilimusic/feature/favorites/domain/import/favorites_import_candidate.dart';
import 'package:bilimusic/feature/favorites/domain/import/favorites_import_track.dart';
import 'package:bilimusic/feature/favorites/domain/import/favorites_import_status.dart';

class FavoritesImportResult {
  const FavoritesImportResult({
    required this.track,
    required this.status,
    this.candidate,
    this.message,
    required this.finishedAt,
  });

  final FavoritesImportTrack track;
  final FavoritesImportStatus status;
  final FavoritesImportCandidate? candidate;
  final String? message;
  final DateTime finishedAt;

  bool get isMatched => candidate != null && status == FavoritesImportStatus.completed;
}
