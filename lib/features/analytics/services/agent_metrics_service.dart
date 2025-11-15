import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agent_metrics.dart';

class AgentMetricsService {
  final FirebaseFirestore _firestore;

  AgentMetricsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<AgentMetrics?> watchGlobalMetrics() {
    return _firestore.doc('agent_metrics/global').snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return AgentMetrics.fromJson(data);
    });
  }
}
