import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/soft_tile_icon.dart'
    show SoftTileIcon, SoftTileButton, SoftTileActionIcon;
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

            final items = inventoryProvider.items;

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
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterHeaderDelegate(
                    minExtentHeight: 260,
                    maxExtentHeight: 300,
                    child: _buildSearchAndFilters(context, inventoryProvider),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsState(context),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.screenPadding,
                        vertical: 12,
                      ),
                      child: InventoryTable(
                        items: items,
                        provider: inventoryProvider,
                        onEdit: (item) => _openItemEditor(context, item: item),
                        onDetails: (item) =>
                            _openItemDetails(context, item, inventoryProvider),
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
            SoftTileIcon(icon: Icons.inventory_outlined),
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
    final lowStockCount = inventoryProvider.lowStockItems.length;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Inventory',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              elevation: 1,
              shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              child: TextField(
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
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: inventoryProvider.setSearchQuery,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SoftTileButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low stock ($lowStockCount)',
                  height: 52,
                  width: 170,
                  tint: theme.colorScheme.error,
                  onPressed: () {
                    inventoryProvider.setLowStockFilter(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Showing low stock items'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                SoftTileButton(
                  icon: Icons.category_outlined,
                  label: inventoryProvider.selectedCategoryFilter != null
                      ? inventoryProvider
                              .getCategoryById(
                                inventoryProvider.selectedCategoryFilter!,
                              )
                              ?.name ??
                          'Category'
                      : 'Category',
                  height: 52,
                  width: 130,
                  onPressed: () async {
                    final selection = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(0, 120, 0, 0),
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
                    );
                    if (selection != null) {
                      inventoryProvider.setCategoryFilter(
                        selection.isEmpty ? null : selection,
                      );
                    }
                  },
                ),
                const SizedBox(width: 12),
                SoftTileButton(
                  icon: Icons.place_outlined,
                  label:
                      inventoryProvider.selectedLocationFilter ?? 'Location',
                  height: 52,
                  width: 130,
                  onPressed: () async {
                    final selection = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(0, 120, 0, 0),
                      items: [
                        const PopupMenuItem(
                          value: '',
                          child: Text('All Locations'),
                        ),
                        ...inventoryProvider.availableLocations.map(
                          (loc) => PopupMenuItem(value: loc, child: Text(loc)),
                        ),
                      ],
                    );
                    if (selection != null) {
                      inventoryProvider.setLocationFilter(
                        selection.isEmpty ? null : selection,
                      );
                    }
                  },
                ),
              ],
            ),
            if (inventoryProvider.searchQuery.isNotEmpty ||
                inventoryProvider.selectedCategoryFilter != null ||
                inventoryProvider.selectedLocationFilter != null ||
                inventoryProvider.showLowStockOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear filters'),
                    onPressed: inventoryProvider.clearAllFilters,
                  ),
                ),
              ),
          ],
        ),
      ),
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
            SoftTileIcon(icon: Icons.search_off),
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
    final availableScrollRange = (maxExtentHeight - minExtentHeight).clamp(
      0,
      double.infinity,
    );
    final t = availableScrollRange == 0
        ? 0.0
        : (shrinkOffset / availableScrollRange).clamp(0.0, 1.0);
    final currentHeight =
        maxExtentHeight - (maxExtentHeight - minExtentHeight) * t;

    return SizedBox(height: currentHeight, child: child);
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return child != oldDelegate.child ||
        minExtentHeight != oldDelegate.minExtentHeight ||
        maxExtentHeight != oldDelegate.maxExtentHeight;
  }
}
