class SubscriptionDetails {
  const SubscriptionDetails({
    required this.planName,
    required this.status,
    this.renewsOn,
    this.usageLimit,
    this.usageUsed,
    this.managementPortalUrl,
    this.canCancel = true,
  });

  final String planName;
  final String status;
  final DateTime? renewsOn;
  final int? usageLimit;
  final int? usageUsed;
  final String? managementPortalUrl;
  final bool canCancel;

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'];
    DateTime? parsedRenewsOn;
    final renewsValue = json['renewsOn'] ?? json['renewsAt'] ?? json['currentPeriodEnd'];
    if (renewsValue is String) {
      parsedRenewsOn = DateTime.tryParse(renewsValue);
    } else if (renewsValue is int) {
      parsedRenewsOn = DateTime.fromMillisecondsSinceEpoch(renewsValue * 1000);
    }

    return SubscriptionDetails(
      planName: json['planName'] as String? ??
          json['plan'] as String? ??
          (json['planId'] as String? ?? 'Free'),
      status: (json['status'] as String? ?? 'inactive').toLowerCase(),
      renewsOn: parsedRenewsOn,
      usageLimit: usage is Map<String, dynamic> ? usage['limit'] as int? : json['usageLimit'] as int?,
      usageUsed: usage is Map<String, dynamic> ? usage['used'] as int? : json['usageUsed'] as int?,
      managementPortalUrl: json['portalUrl'] as String? ?? json['manageUrl'] as String?,
      canCancel: json['canCancel'] as bool? ?? true,
    );
  }

  String get formattedStatus {
    switch (status) {
      case 'trialing':
        return 'Trial';
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Past due';
      case 'canceled':
        return 'Canceled';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  bool get isFreeTier => status == 'inactive' || planName.toLowerCase() == 'free';
}
