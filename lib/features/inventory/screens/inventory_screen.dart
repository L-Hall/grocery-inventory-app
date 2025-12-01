import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_item.dart';
import '../widgets/inventory_item_editor.dart';
import '../widgets/inventory_item_details.dart';
import '../widgets/inventory_table.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchController;
  _SortOption _sortOption = _SortOption.none;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      if (_searchController.text != inventoryProvider.searchQuery) {
        _searchController.text = inventoryProvider.searchQuery;
      }
      if (inventoryProvider.isEmpty) {
        inventoryProvider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
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

              final items = _sortedItems(inventoryProvider.items);

              if (_searchController.text != inventoryProvider.searchQuery) {
                _searchController.value = _searchController.value.copyWith(
                  text: inventoryProvider.searchQuery,
                  selection: TextSelection.collapsed(
                    offset: inventoryProvider.searchQuery.length,
                  ),
                  composing: TextRange.empty,
                );
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppTheme.contentPadding),
                        _buildSearchBar(context, inventoryProvider),
                        const SizedBox(height: AppTheme.sectionSpacing),
                        _buildLowStockCTA(context, inventoryProvider),
                        const SizedBox(height: AppTheme.contentPadding),
                        _buildFiltersRow(context, inventoryProvider),
                        const SizedBox(height: AppTheme.contentPadding),
                        _buildSortButton(context),
                        const SizedBox(height: AppTheme.sectionSpacing),
                        ],
                      ),
                    ),
                  ),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoResultsState(context),
                    )
                  else if (isMobile)
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppTheme.screenPadding,
                            index == 0 ? 0 : 8,
                            AppTheme.screenPadding,
                            8,
                          ),
                          child: _MobileInventoryCard(
                            item: item,
                            provider: inventoryProvider,
                            onEdit: () => _openItemEditor(context, item: item),
                            onDetails: () =>
                                _openItemDetails(context, item, inventoryProvider),
                            onDelete: () =>
                                _showDeleteConfirmation(context, item, inventoryProvider),
                          ),
                        );
                      },
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.screenPadding),
                        child: InventoryTable(
                          items: items,
                          provider: inventoryProvider,
                          onEdit: (item) =>
                              _openItemEditor(context, item: item),
                          onDetails: (item) => _openItemDetails(
                            context,
                            item,
                            inventoryProvider,
                          ),
                          onDelete: (item) => _showDeleteConfirmation(
                            context,
                            item,
                            inventoryProvider,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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

  Widget _buildSearchBar(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search items...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: inventoryProvider.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  inventoryProvider.setSearchQuery('');
                },
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
      ),
      onChanged: inventoryProvider.setSearchQuery,
    );
  }

  Widget _buildLowStockCTA(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final lowStockCount = inventoryProvider.lowStockItems.length;

    return FilledButton.icon(
      onPressed: () => inventoryProvider.setLowStockFilter(true),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.warning_amber_rounded),
      label: Text('Low stock items ($lowStockCount)'),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    final theme = Theme.of(context);
    String label;
    switch (_sortOption) {
      case _SortOption.location:
        label = 'Sort: Location';
        break;
      case _SortOption.category:
        label = 'Sort: Category';
        break;
      case _SortOption.quantity:
        label = 'Sort: Quantity';
        break;
      case _SortOption.none:
      default:
        label = 'Sort';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<_SortOption>(
        onSelected: (option) {
          setState(() => _sortOption = option);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _SortOption.none, child: Text('None')),
          PopupMenuItem(value: _SortOption.location, child: Text('Location')),
          PopupMenuItem(value: _SortOption.category, child: Text('Category')),
          PopupMenuItem(value: _SortOption.quantity, child: Text('Quantity')),
        ],
        child: OutlinedButton.icon(
          icon: const Icon(Icons.sort),
          label: Text(label),
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
          ),
        ),
      ),
    );
  }

  List<InventoryItem> _sortedItems(List<InventoryItem> items) {
    final sorted = List<InventoryItem>.from(items);
    int compareStrings(String? a, String? b) =>
        (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());

    switch (_sortOption) {
      case _SortOption.location:
        sorted.sort(
          (a, b) => compareStrings(a.location, b.location),
        );
        break;
      case _SortOption.category:
        sorted.sort(
          (a, b) => compareStrings(a.category, b.category),
        );
        break;
      case _SortOption.quantity:
        sorted.sort(
          (a, b) => a.quantity.compareTo(b.quantity),
        );
        break;
      case _SortOption.none:
        break;
    }
    return sorted;
  }

  Widget _buildFiltersRow(
    BuildContext context,
    InventoryProvider inventoryProvider,
  ) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppTheme.contentPadding,
      runSpacing: 8,
      children: [
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
            isActive: inventoryProvider.selectedCategoryFilter != null,
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
        if (inventoryProvider.availableLocations.isNotEmpty)
          _FilterChipButton(
            label:
                inventoryProvider.selectedLocationFilter ?? 'Location',
            icon: Icons.location_on,
            isActive: inventoryProvider.selectedLocationFilter != null,
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
        if (inventoryProvider.searchQuery.isNotEmpty ||
            inventoryProvider.selectedCategoryFilter != null ||
            inventoryProvider.selectedLocationFilter != null ||
            inventoryProvider.showLowStockOnly)
          ActionChip(
            avatar: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear'),
            onPressed: inventoryProvider.clearAllFilters,
            backgroundColor: theme.colorScheme.surfaceVariant,
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

  Future<void> _openItemEditor(BuildContext context, {InventoryItem? item}) {
    return showInventoryItemEditorSheet(context, item: item);
  }

  Future<void> _openItemDetails(
    BuildContext context,
    InventoryItem item,
    InventoryProvider provider,
  ) {
    return showInventoryItemDetailsSheet(
      context,
      item: item,
      provider: provider,
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

enum _SortOption { none, location, category, quantity }

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
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(20),
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
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

class _MobileInventoryCard extends StatelessWidget {
  const _MobileInventoryCard({
    required this.item,
    required this.provider,
    required this.onEdit,
    required this.onDetails,
    required this.onDelete,
  });

  final InventoryItem item;
  final InventoryProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item.stockStatus;
    IconData statusIcon;
    Color statusColor;
    String statusLabel;

    if (item.isExpired) {
      statusIcon = Icons.error;
      statusColor = theme.colorScheme.error;
      statusLabel = 'Expired';
    } else if (status == StockStatus.out) {
      statusIcon = Icons.cancel_presentation;
      statusColor = theme.colorScheme.error;
      statusLabel = 'Out';
    } else if (status == StockStatus.low) {
      statusIcon = Icons.warning;
      statusColor = theme.colorScheme.tertiary;
      statusLabel = 'Low';
    } else if (item.isExpiringSoon) {
      statusIcon = Icons.schedule;
      statusColor = theme.colorScheme.tertiary;
      statusLabel = 'Soon';
    } else {
      statusIcon = Icons.check_circle;
      statusColor = AppTheme.stockGood;
      statusLabel = 'OK';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity} ${item.unit} • Min ${item.lowStockThreshold}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (item.location != null && item.location!.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: AppTheme.contentPadding / 2),
                          child: Text(
                            item.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.contentPadding),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 18, color: statusColor),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                            break;
                          case 'details':
                            onDetails();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Adjust')),
                        PopupMenuItem(value: 'details', child: Text('Details')),
                        PopupMenuItem(value: 'delete', child: Text('Remove')),
                      ],
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Adjust'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDetails,
                  child: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
