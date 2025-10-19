import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../models/inventory_item.dart';
import '../models/category.dart';
import '../widgets/inventory_item_editor.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize inventory data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      if (inventoryProvider.isEmpty) {
        inventoryProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final inventoryProvider = Provider.of<InventoryProvider>(
            context,
            listen: false,
          );
          await inventoryProvider.refresh();
        },
        child: Consumer<InventoryProvider>(
          builder: (context, inventoryProvider, _) {
            if (inventoryProvider.isLoading && inventoryProvider.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (inventoryProvider.hasError && inventoryProvider.isEmpty) {
              return _buildErrorState(context, inventoryProvider);
            }

            if (inventoryProvider.isEmpty) {
              return _buildEmptyState(context);
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterHeaderDelegate(
                    minExtentHeight: 140,
                    maxExtentHeight: 164,
                    child: _buildSearchAndFilters(context, inventoryProvider),
                  ),
                ),
                if (inventoryProvider.stats != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: _buildStatsSection(context, inventoryProvider),
                    ),
                  ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = items[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == items.length - 1 ? 0 : 8,
                          ),
                          child: _buildItemCard(
                            context,
                            item,
                            inventoryProvider,
                          ),
                        );
                      }, childCount: items.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Inventory',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              inventoryProvider.error ?? 'Unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => inventoryProvider.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Items Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding some items using natural language in the "Add Items" tab',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openItemEditor(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: inventoryProvider.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => inventoryProvider.setSearchQuery(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              onChanged: inventoryProvider.setSearchQuery,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: inventoryProvider.showLowStockOnly,
                  onSelected: inventoryProvider.setLowStockFilter,
                  avatar: inventoryProvider.showLowStockOnly
                      ? const Icon(Icons.warning, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                if (inventoryProvider.categories.isNotEmpty)
                  _FilterChipButton(
                    label: inventoryProvider.selectedCategoryFilter != null
                        ? inventoryProvider
                                  .getCategoryById(
                                    inventoryProvider.selectedCategoryFilter!,
                                  )
                                  ?.name ??
                              'Category'
                        : 'Category',
                    icon: Icons.category,
                    onSelected: (value) {
                      inventoryProvider.setCategoryFilter(
                        value.isEmpty ? null : value,
                      );
                    },
                    items: [
                      const PopupMenuItem(
                        value: '',
                        child: Text('All Categories'),
                      ),
                      ...inventoryProvider.categories.map(
                        (category) => PopupMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: category.colorValue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (inventoryProvider.categories.isNotEmpty)
                  const SizedBox(width: 8),
                if (inventoryProvider.availableLocations.isNotEmpty)
                  _FilterChipButton(
                    label:
                        inventoryProvider.selectedLocationFilter ?? 'Location',
                    icon: Icons.location_on,
                    onSelected: (value) {
                      inventoryProvider.setLocationFilter(
                        value.isEmpty ? null : value,
                      );
                    },
                    items: [
                      const PopupMenuItem(
                        value: '',
                        child: Text('All Locations'),
                      ),
                      ...inventoryProvider.availableLocations.map(
                        (loc) => PopupMenuItem(value: loc, child: Text(loc)),
                      ),
                    ],
                  ),
                if (inventoryProvider.availableLocations.isNotEmpty)
                  const SizedBox(width: 8),
                if (inventoryProvider.searchQuery.isNotEmpty ||
                    inventoryProvider.selectedCategoryFilter != null ||
                    inventoryProvider.selectedLocationFilter != null ||
                    inventoryProvider.showLowStockOnly)
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                    onPressed: inventoryProvider.clearAllFilters,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);
    final stats = inventoryProvider.stats!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              'Total',
              stats.totalItems.toString(),
              Icons.inventory,
              theme.primaryColor,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              context,
              'Low Stock',
              stats.lowStockItems.toString(),
              Icons.warning,
              Colors.orange,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              context,
              'Out of Stock',
              stats.outOfStockItems.toString(),
              Icons.error,
              Colors.red,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              context,
              'Good Stock',
              stats.goodStockItems.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Items Found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    InventoryItem item,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);
    final category = inventoryProvider.getCategoryById(item.category);

    return Card(
      elevation: 1,
      child: ListTile(
        onTap: () => _openItemEditor(context, item: item),
        contentPadding: const EdgeInsets.all(16),
        leading: _buildStockStatusIndicator(item.stockStatus),
        title: Text(
          item.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.quantity} ${item.unit}'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (category != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.colorValue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(category.name, style: theme.textTheme.labelSmall),
                ],
                if (item.location != null) ...[
                  if (category != null) const Text(' • '),
                  Icon(
                    Icons.location_on,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(item.location!, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
            if (item.isExpired || item.isExpiringSoon) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    item.isExpired ? Icons.error : Icons.warning,
                    size: 14,
                    color: item.isExpired ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isExpired
                        ? 'Expired ${item.daysUntilExpiration!.abs()} days ago'
                        : 'Expires in ${item.daysUntilExpiration} days',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.isExpired ? Colors.red : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) =>
              _handleItemAction(context, action, item, inventoryProvider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Quantity'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove Item', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatusIndicator(StockStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case StockStatus.good:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case StockStatus.low:
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case StockStatus.out:
        color = Colors.red;
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _handleItemAction(
    BuildContext context,
    String action,
    InventoryItem item,
    InventoryProvider inventoryProvider,
  ) {
    switch (action) {
      case 'edit':
        _openItemEditor(context, item: item);
        break;
      case 'details':
        _showItemDetailsDialog(context, item);
        break;
      case 'delete':
        _showDeleteConfirmation(context, item, inventoryProvider);
        break;
    }
  }

  Future<void> _openItemEditor(BuildContext context, {InventoryItem? item}) {
    return showInventoryItemEditorSheet(context, item: item);
  }

  void _showItemDetailsDialog(BuildContext context, InventoryItem item) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Quantity', '${item.quantity} ${item.unit}'),
            _buildDetailRow('Stock Status', item.stockStatus.displayName),
            _buildDetailRow('Category', item.category),
            if (item.location != null)
              _buildDetailRow('Location', item.location!),
            _buildDetailRow(
              'Low Stock Threshold',
              '${item.lowStockThreshold} ${item.unit}',
            ),
            if (item.expirationDate != null)
              _buildDetailRow(
                'Expiration',
                item.expirationDate!.toLocal().toString().split(' ')[0],
              ),
            if (item.notes != null) _buildDetailRow('Notes', item.notes!),
            _buildDetailRow(
              'Created',
              item.createdAt.toLocal().toString().split(' ')[0],
            ),
            _buildDetailRow(
              'Updated',
              item.updatedAt.toLocal().toString().split(' ')[0],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    InventoryItem item,
    InventoryProvider inventoryProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text(
          'Are you sure you want to remove "${item.name}" from your inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await inventoryProvider.removeItem(item.name);

              if (context.mounted) {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Removed ${item.name}'
                          : 'Failed to remove ${item.name}',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.onSelected,
    required this.items,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final void Function(String value) onSelected;
  final List<PopupMenuEntry<String>> items;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
          color: isActive ? theme.colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FilterHeaderDelegate({
    required this.child,
    required this.minExtentHeight,
    required this.maxExtentHeight,
  });

  final Widget child;
  final double minExtentHeight;
  final double maxExtentHeight;

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return child != oldDelegate.child ||
        minExtentHeight != oldDelegate.minExtentHeight ||
        maxExtentHeight != oldDelegate.maxExtentHeight;
  }
}
