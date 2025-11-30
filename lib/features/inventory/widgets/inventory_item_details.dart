import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import 'inventory_item_editor.dart';

Future<void> showInventoryItemDetailsSheet(
  BuildContext context, {
  required InventoryItem item,
  required InventoryProvider provider,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) =>
        _InventoryItemDetailsSheet(item: item, provider: provider),
  );
}

class _InventoryItemDetailsSheet extends StatefulWidget {
  const _InventoryItemDetailsSheet({
    required this.item,
    required this.provider,
  });

  final InventoryItem item;
  final InventoryProvider provider;

  @override
  State<_InventoryItemDetailsSheet> createState() =>
      _InventoryItemDetailsSheetState();
}

class _InventoryItemDetailsSheetState
    extends State<_InventoryItemDetailsSheet> {
  bool _isProcessing = false;
  late InventoryItem _currentItem;

  InventoryItem get item => _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    widget.provider.addListener(_handleProviderUpdate);
  }

  @override
  void didUpdateWidget(covariant _InventoryItemDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_handleProviderUpdate);
      widget.provider.addListener(_handleProviderUpdate);
    }
    if (oldWidget.item != widget.item) {
      _currentItem = widget.item;
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_handleProviderUpdate);
    super.dispose();
  }

  void _handleProviderUpdate() {
    final updatedItem = widget.provider.allItems.firstWhere(
      (element) => element.id == _currentItem.id,
      orElse: () => _currentItem,
    );
    if (!identical(updatedItem, _currentItem) && mounted) {
      setState(() {
        _currentItem = updatedItem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.screenPadding,
          right: AppTheme.screenPadding,
          top: 24,
          bottom: bottomInset + AppTheme.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sectionSpacing),
            _buildInfoGrid(context),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.sectionSpacing),
              Text(
                'Notes',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.contentPadding / 2),
              Text(
                item.notes!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppTheme.sectionSpacing),
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.contentPadding),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: AppTheme.contentPadding,
                runSpacing: AppTheme.contentPadding,
                children: [
                  _QuickActionButton(
                    icon: Icons.remove,
                    label: 'Use 1',
                    onPressed: () => _applyQuantityChange(-1),
                  ),
                  _QuickActionButton(
                    icon: Icons.add,
                    label: 'Add 1',
                    onPressed: () => _applyQuantityChange(1),
                  ),
                  _QuickActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'Set quantity',
                    onPressed: _showSetQuantityDialog,
                  ),
                  _QuickActionButton(
                    icon: Icons.edit_note,
                    label: 'Edit item',
                    onPressed: () => _openEditor(context),
                  ),
                  _QuickActionButton(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    destructive: true,
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sectionSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final theme = Theme.of(context);
    final stats = <_InfoTileData>[
      _InfoTileData(
        label: 'Quantity',
        value: '${item.quantity} ${item.unit}',
        icon: Icons.stacked_bar_chart,
      ),
      _InfoTileData(
        label: 'Stock Status',
        value: item.stockStatus.displayName,
        icon: _statusIcon(item.stockStatus),
      ),
      _InfoTileData(
        label: 'Category',
        value: item.category,
        icon: Icons.category_outlined,
      ),
      _InfoTileData(
        label: 'Location',
        value: item.location ?? 'Not specified',
        icon: Icons.location_on_outlined,
      ),
      _InfoTileData(
        label: 'Low Stock',
        value: '${item.lowStockThreshold} ${item.unit}',
        icon: Icons.warning_amber_outlined,
      ),
      _InfoTileData(
        label: 'Created',
        value: item.createdAt.toLocal().toString().split(' ').first,
        icon: Icons.calendar_today_outlined,
      ),
      _InfoTileData(
        label: 'Updated',
        value: item.updatedAt.toLocal().toString().split(' ').first,
        icon: Icons.update,
      ),
      _InfoTileData(
        label: item.expirationDate == null
            ? 'Expiry date'
            : item.isExpired
            ? 'Expired'
            : 'Expires',
        value: item.expirationDate != null
            ? item.expirationDate!.toLocal().toString().split(' ').first
            : 'Not set',
        icon: item.expirationDate == null
            ? Icons.schedule
            : item.isExpired
            ? Icons.error
            : Icons.schedule,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        mainAxisSpacing: AppTheme.contentPadding,
        crossAxisSpacing: AppTheme.contentPadding,
      ),
      itemBuilder: (context, index) {
        final data = stats[index];
        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.contentPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(data.icon, size: 20),
                const SizedBox(width: AppTheme.contentPadding / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _statusIcon(StockStatus status) {
    switch (status) {
      case StockStatus.good:
        return Icons.check_circle_outline;
      case StockStatus.low:
        return Icons.warning_amber_outlined;
      case StockStatus.out:
        return Icons.error_outline;
    }
  }

  Future<void> _applyQuantityChange(double delta) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    final newQuantity = (item.quantity + delta)
        .clamp(0, double.infinity)
        .toDouble();
    final success = await widget.provider.updateItem(
      item,
      newQuantity: newQuantity,
      action: UpdateAction.set,
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Updated ${item.name}' : 'Failed to update ${item.name}',
        ),
      ),
    );

    if (success && mounted) {
      setState(() {
        _currentItem = _currentItem.copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  Future<void> _showSetQuantityDialog() async {
    final controller = TextEditingController(text: item.quantity.toString());
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Set ${item.name} quantity'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);
    final success = await widget.provider.updateItem(
      item,
      newQuantity: result,
      action: UpdateAction.set,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Quantity updated' : 'Failed to update ${item.name}',
        ),
      ),
    );

    if (success && mounted) {
      setState(() {
        _currentItem = _currentItem.copyWith(
          quantity: result,
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  Future<void> _openEditor(BuildContext context) async {
    await showInventoryItemEditorSheet(context, item: item);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove item'),
        content: Text('Remove "${item.name}" from your inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final success = await widget.provider.removeItem(item.name);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    navigator.pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Removed ${item.name}' : 'Failed to remove ${item.name}',
        ),
      ),
    );
  }
}

class _InfoTileData {
  _InfoTileData({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      icon: Icon(
        icon,
        color: destructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      label: Text(label),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: destructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurface,
        backgroundColor: destructive
            ? Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.2)
            : Theme.of(context)
                .colorScheme
                .surfaceVariant
                .withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: AppTheme.contentPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return _ActionChipButton(
      icon: icon,
      label: label,
      destructive: destructive,
      onPressed: onPressed,
    );
  }
}
