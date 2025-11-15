import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ingestion_job.dart';

class IngestionJobService {
  final FirebaseFirestore? _firestore;

  const IngestionJobService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  bool get isAvailable => _firestore != null;

  Stream<IngestionJob> watchJob(String jobPath) {
    if (!isAvailable) {
      return Stream.error(
        StateError('Ingestion job tracking is not available in this mode.'),
      );
    }

    return _firestore!
        .doc(jobPath)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw StateError('Ingestion job not found.');
          }
          return IngestionJob.fromSnapshot(snapshot);
        });
  }
}
