import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/category.dart' as inventory;
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';

class InventoryTable extends StatefulWidget {
  const InventoryTable({
    super.key,
    required this.items,
    required this.provider,
    this.onEdit,
    this.onDetails,
    this.onDelete,
  });

  final List<InventoryItem> items;
  final InventoryProvider provider;
  final ValueChanged<InventoryItem>? onEdit;
  final ValueChanged<InventoryItem>? onDetails;
  final ValueChanged<InventoryItem>? onDelete;

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {
  late List<InventoryItem> _rows;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rows = List<InventoryItem>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant InventoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.items, oldWidget.items)) {
      _rows = List<InventoryItem>.from(widget.items);
      if (_sortColumnIndex != null) {
        _applySort(_sortColumnIndex!, _sortAscending);
      }
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  void _applySort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _rows.sort((a, b) {
        final Comparable aValue = _sortValue(columnIndex, a);
        final Comparable bValue = _sortValue(columnIndex, b);
        final result = Comparable.compare(aValue, bValue);
        return ascending ? result : -result;
      });
    });
  }

  Comparable _sortValue(int columnIndex, InventoryItem item) {
    switch (columnIndex) {
      case 0:
        return item.name.toLowerCase();
      case 1:
        final category =
            widget.provider.getCategoryById(item.category)?.name ??
            item.category;
        return category.toLowerCase();
      case 2:
        return item.quantity;
      case 3:
        return item.unit.toLowerCase();
      case 4:
        return (item.location ?? '').toLowerCase();
      case 5:
        return item.lowStockThreshold;
      default:
        return item.updatedAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  'Inventory (${_rows.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalController,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - 16,
                    ),
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      columns: [
                        DataColumn(
                          label: const Text('Item'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: const Text('Category'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        DataColumn(
                          numeric: true,
                          label: const Text('Quantity'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: const Text('Unit'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: const Text('Location'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        DataColumn(
                          numeric: true,
                          label: const Text('Minimum'),
                          onSort: (columnIndex, ascending) =>
                              _applySort(columnIndex, ascending),
                        ),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: _rows.map(_buildRow).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DataRow _buildRow(InventoryItem item) {
    final theme = Theme.of(context);
    final category = widget.provider.getCategoryById(item.category);

    return DataRow(
      cells: [
        DataCell(
          Text(item.name),
          onTap: widget.onDetails != null
              ? () => widget.onDetails!(item)
              : null,
        ),
        DataCell(
          category != null
              ? _CategoryChip(category: category)
              : Text(item.category),
        ),
        DataCell(
          Text(
            item.quantity.toStringAsFixed(
              item.quantity.truncateToDouble() == item.quantity ? 0 : 2,
            ),
          ),
        ),
        DataCell(Text(item.unit)),
        DataCell(
          item.location != null && item.location!.isNotEmpty
              ? _TagChip(label: item.location!)
              : const Text('-'),
        ),
        DataCell(
          Text(
            item.lowStockThreshold.toStringAsFixed(
              item.lowStockThreshold.truncateToDouble() ==
                      item.lowStockThreshold
                  ? 0
                  : 2,
            ),
          ),
        ),
        DataCell(_StatusIndicator(item: item)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Adjust quantity',
                icon: const Icon(Icons.edit),
                onPressed: widget.onEdit != null
                    ? () => widget.onEdit!(item)
                    : null,
              ),
              IconButton(
                tooltip: 'Details',
                icon: const Icon(Icons.info_outline),
                onPressed: widget.onDetails != null
                    ? () => widget.onDetails!(item)
                    : null,
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                onPressed: widget.onDelete != null
                    ? () => widget.onDelete!(item)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String label;

    if (item.isExpired) {
      icon = Icons.error;
      color = Colors.red;
      label = 'Expired';
    } else if (item.stockStatus == StockStatus.out) {
      icon = Icons.cancel_presentation;
      color = Colors.red;
      label = 'Out of stock';
    } else if (item.stockStatus == StockStatus.low) {
      icon = Icons.warning;
      color = Colors.orange;
      label = 'Low stock';
    } else if (item.isExpiringSoon) {
      icon = Icons.schedule;
      color = Colors.orange;
      label = 'Expiring soon';
    } else {
      icon = Icons.check_circle;
      color = Colors.green;
      label = 'In stock';
    }

    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final inventory.Category category;

  @override
  Widget build(BuildContext context) {
    final baseColor = category.colorValue;
    final background = baseColor.withOpacity(0.16);
    final border = baseColor.withOpacity(0.32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        category.name,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: baseColor),
      ),
    );
  }
}
