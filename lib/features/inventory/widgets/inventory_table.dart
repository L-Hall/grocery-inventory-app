import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'en_GB');

  static const int _qtyColumn = 2;
  static const int _minQtyColumn = 5;

  @override
  void initState() {
    super.initState();
    _rows = List<InventoryItem>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant InventoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _rows = List<InventoryItem>.from(widget.items);
      if (_sortColumnIndex != null) {
        _applySort(_sortColumnIndex!, _sortAscending);
      }
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
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
      case _qtyColumn:
        return item.quantity;
      case 3:
        return item.unit.toLowerCase();
      case 4:
        return (item.location ?? '').toLowerCase();
      case _minQtyColumn:
        return item.lowStockThreshold;
      case 6:
        return item.updatedAt;
      default:
        return item.name.toLowerCase();
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
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth - 16,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: IntrinsicWidth(
                            stepWidth: 120,
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(3.2),
                                1: FlexColumnWidth(2.6),
                                2: FixedColumnWidth(88),
                                3: FixedColumnWidth(76),
                                4: FlexColumnWidth(2.4),
                                5: FixedColumnWidth(104),
                                6: FlexColumnWidth(2.2),
                                7: FixedColumnWidth(152),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                _buildHeaderRow(theme),
                                ..._rows.map(
                                  (item) => _buildDataRow(item, theme),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  TableRow _buildHeaderRow(ThemeData theme) {
    Widget headerCell({
      required String label,
      required int columnIndex,
      bool sortable = true,
      bool numeric = false,
    }) {
      final bool isSorted = _sortColumnIndex == columnIndex;
      final icon = isSorted
          ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more;

      final text = Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );

      if (!sortable) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
            child: text,
          ),
        );
      }

      return InkWell(
        onTap: () => _applySort(columnIndex, isSorted ? !_sortAscending : true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: numeric
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 16,
                  color: isSorted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget staticHeader(
      String label, {
      Alignment alignment = Alignment.centerLeft,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: alignment,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      children: [
        headerCell(label: 'Item', columnIndex: 0),
        headerCell(label: 'Category', columnIndex: 1),
        headerCell(label: 'Qty', columnIndex: _qtyColumn, numeric: true),
        headerCell(label: 'Unit', columnIndex: 3),
        headerCell(label: 'Location', columnIndex: 4),
        headerCell(label: 'Min qty', columnIndex: _minQtyColumn, numeric: true),
        staticHeader('Status'),
        staticHeader('Actions', alignment: Alignment.centerRight),
      ],
    );
  }

  TableRow _buildDataRow(InventoryItem item, ThemeData theme) {
    final category = widget.provider.getCategoryById(item.category);

    Widget cell(
      Widget child, {
      Alignment alignment = Alignment.centerLeft,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 4,
      ),
    }) {
      return Padding(
        padding: padding,
        child: Align(alignment: alignment, child: child),
      );
    }

    Widget numericCell(String value) {
      return cell(
        Text(
          value,
          style: theme.textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        alignment: Alignment.centerRight,
      );
    }

    Widget actionsCell() {
      final buttons = [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Adjust quantity',
          icon: const Icon(Icons.edit),
          onPressed: widget.onEdit != null ? () => widget.onEdit!(item) : null,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Details',
          icon: const Icon(Icons.info_outline),
          onPressed: widget.onDetails != null
              ? () => widget.onDetails!(item)
              : null,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          color: theme.colorScheme.error,
          onPressed: widget.onDelete != null
              ? () => widget.onDelete!(item)
              : null,
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 160) {
            return Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      if (widget.onEdit != null) widget.onEdit!(item);
                      break;
                    case 'details':
                      if (widget.onDetails != null) widget.onDetails!(item);
                      break;
                    case 'remove':
                      if (widget.onDelete != null) widget.onDelete!(item);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Adjust quantity')),
                  PopupMenuItem(value: 'details', child: Text('Details')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            );
          }

          return Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, children: buttons),
          );
        },
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      children: [
        cell(
          Text(
            item.name,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
        cell(
          category != null
              ? _CategoryChip(category: category)
              : Text(
                  item.category,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        numericCell(_numberFormat.format(item.quantity)),
        cell(Text(item.unit, overflow: TextOverflow.ellipsis)),
        cell(
          item.location != null && item.location!.isNotEmpty
              ? _TagChip(label: item.location!)
              : Text('-', style: theme.textTheme.bodyMedium),
        ),
        numericCell(_numberFormat.format(item.lowStockThreshold)),
        cell(_StatusIndicator(item: item)),
        cell(actionsCell(), alignment: Alignment.centerRight),
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

    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: color);

    return Tooltip(
      message: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            Text(label, style: textStyle, softWrap: true),
          ],
        ),
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
      constraints: const BoxConstraints(maxWidth: 160),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
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
      constraints: const BoxConstraints(maxWidth: 160),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          category.name,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: baseColor),
        ),
      ),
    );
  }
}
