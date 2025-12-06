import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../subscription/models/subscription_details.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final ApiService _apiService;
  late final StorageService _storageService;
  SubscriptionDetails? _subscriptionDetails;
  String? _subscriptionError;
  bool _isLoadingSubscription = true;
  bool _isPerformingAction = false;

  @override
  void initState() {
    super.initState();
    _apiService = getIt<ApiService>();
    _storageService = getIt<StorageService>();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _isLoadingSubscription = true;
      _subscriptionError = null;
    });

    try {
      final response = await _apiService.getSubscriptionDetails();
      setState(() {
        _subscriptionDetails = SubscriptionDetails.fromJson(response);
      });
    } catch (e) {
      setState(() {
        _subscriptionError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account management')),
      body: RefreshIndicator(
        onRefresh: _loadSubscription,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSyncSection(theme),
            const SizedBox(height: 16),
            _buildSubscriptionSection(theme),
            const SizedBox(height: 16),
            _buildDangerZone(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final uid =
        user?.uid ??
        _storageService.getString(StorageService.keyUserId) ??
        'Unknown';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cross-device sync',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your grocery data is associated with the Firebase UID below. '
              'Use it when contacting support or pairing additional devices.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Firebase UID',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uid,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy UID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: uid));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Firebase UID copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Subscription',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_subscriptionDetails != null)
                  _buildStatusChip(
                    theme,
                    _subscriptionDetails!.formattedStatus,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingSubscription)
              const Center(child: CircularProgressIndicator())
            else if (_subscriptionError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load subscription details',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadSubscription,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (_subscriptionDetails == null)
              Text(
                'No subscription found. You are using the free tier with limited updates per month.',
                style: theme.textTheme.bodyMedium,
              )
            else
              _buildSubscriptionDetails(theme, _subscriptionDetails!),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isPerformingAction
                      ? null
                      : _handleManageSubscription,
                  icon: const Icon(Icons.launch),
                  label: const Text('Manage subscription'),
                ),
                ElevatedButton(
                  onPressed: _isPerformingAction ? null : _showPlanSheet,
                  child: const Text('Change plan'),
                ),
                if (_subscriptionDetails != null &&
                    !_subscriptionDetails!.isFreeTier &&
                    _subscriptionDetails!.canCancel)
                  TextButton(
                    onPressed: _isPerformingAction
                        ? null
                        : _confirmCancelSubscription,
                    child: const Text('Cancel subscription'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails(
    ThemeData theme,
    SubscriptionDetails details,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details.planName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (details.renewsOn != null) ...[
          const SizedBox(height: 8),
          Text(
            'Renews on ${_formatDate(details.renewsOn!)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (details.usageLimit != null && details.usageUsed != null) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value:
                (details.usageUsed!.clamp(0, details.usageLimit!).toDouble()) /
                details.usageLimit!.toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 4),
          Text(
            '${details.usageUsed}/${details.usageLimit} updates this cycle',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Danger zone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Deleting your account removes your grocery history, inventory, and preferences. This cannot be undone.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: _confirmDeleteAccount,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleManageSubscription() async {
    final portalUrl = _subscriptionDetails?.managementPortalUrl;
    if (portalUrl != null) {
      final uri = Uri.tryParse(portalUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    await _fetchAndLaunchPortal();
  }

  Future<void> _fetchAndLaunchPortal() async {
    setState(() => _isPerformingAction = true);
    try {
      final response = await _apiService.createSubscriptionPortalSession();
      final url = response['url'] as String?;
      if (url == null) {
        _showSnackBar('No portal URL returned');
        return;
      }

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('Unable to open portal link');
      }
    } catch (e) {
      _showSnackBar('Failed to open portal: $e');
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _confirmCancelSubscription() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel subscription'),
        content: const Text(
          'You will keep premium access until the current billing period ends. '
          'Are you sure you want to cancel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep plan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _isPerformingAction = true);
    try {
      await _apiService.cancelSubscription();
      await _loadSubscription();
      _showSnackBar('Subscription canceled');
    } catch (e) {
      _showSnackBar('Failed to cancel subscription: $e');
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final authProvider = context.read<AuthProvider>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This will permanently delete your account and all grocery data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isPerformingAction = true);

    try {
      await authProvider.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Account deleted');
      }
    } catch (e) {
      _showSnackBar('Failed to delete account: $e');
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  void _showPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PlanSelectionSheet(onSelectPlan: _changePlan),
    );
  }

  Future<void> _changePlan(String planId) async {
    Navigator.of(context).pop();
    setState(() => _isPerformingAction = true);

    try {
      await _apiService.updateSubscriptionPlan(planId);
      await _loadSubscription();
      _showSnackBar('Plan updated');
    } catch (e) {
      _showSnackBar('Failed to update plan: $e');
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}

class _PlanSelectionSheet extends StatelessWidget {
  const _PlanSelectionSheet({required this.onSelectPlan});

  final ValueChanged<String> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plans = const [
      _PlanOption(
        id: 'free',
        title: 'Free',
        price: '\$0',
        description: '50 AI-powered updates per month, core inventory tools.',
        features: [
          'Smart text parsing',
          'Manual inventory edits',
          'Low stock dashboards',
        ],
      ),
      _PlanOption(
        id: 'pro',
        title: 'Pro',
        price: '\$9 / month',
        description: 'Unlimited updates, alerts, and faster processing.',
        highlighted: true,
        features: [
          'Unlimited updates & sync',
          'Priority AI pipelines',
          'Proactive reminders',
          'Early access to new features',
        ],
      ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a plan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade when you need continuous syncing or more AI updates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return _PlanCard(option: plan, onSelectPlan: onSelectPlan);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOption {
  const _PlanOption({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    this.highlighted = false,
    this.features = const [],
  });

  final String id;
  final String title;
  final String price;
  final String description;
  final bool highlighted;
  final List<String> features;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.option, required this.onSelectPlan});

  final _PlanOption option;
  final ValueChanged<String> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: option.highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: option.highlighted ? 2 : 1,
        ),
        color: option.highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                option.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (option.highlighted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.primary,
                  ),
                  child: Text(
                    'Most popular',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                option.price,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            option.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (option.features.isNotEmpty) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: option.features
                  .map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onSelectPlan(option.id),
              child: Text('Choose ${option.title}'),
            ),
          ),
        ],
      ),
    );
  }
}
