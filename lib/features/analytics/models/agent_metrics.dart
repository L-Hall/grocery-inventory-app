class AgentMetrics {
  final int totalCount;
  final int successCount;
  final int fallbackCount;
  final double? averageLatencyMs;
  final double? averageConfidence;

  AgentMetrics({
    required this.totalCount,
    required this.successCount,
    required this.fallbackCount,
    this.averageLatencyMs,
    this.averageConfidence,
  });

  factory AgentMetrics.fromJson(Map<String, dynamic> json) {
    final total = _parseInt(json['totalCount']) ?? 0;
    final successes = _parseInt(json['successCount']) ?? 0;
    final fallbacks = _parseInt(json['fallbackCount']) ?? 0;
    final latencySamples = _parseInt(json['latencySamples']) ?? 0;
    final sumLatency = _parseDouble(json['sumLatencyMs']);
    final confidenceSamples = _parseInt(json['confidenceSamples']) ?? 0;
    final sumConfidence = _parseDouble(json['sumConfidence']);

    return AgentMetrics(
      totalCount: total,
      successCount: successes,
      fallbackCount: fallbacks,
      averageLatencyMs: latencySamples > 0 && sumLatency != null
          ? sumLatency / latencySamples
          : null,
      averageConfidence: confidenceSamples > 0 && sumConfidence != null
          ? sumConfidence / confidenceSamples
          : null,
    );
  }

  double get successRate => totalCount == 0 ? 0 : successCount / totalCount;

  double get fallbackRate => totalCount == 0 ? 0 : fallbackCount / totalCount;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
