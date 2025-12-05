import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/category.dart' as inventory;
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';

enum InventoryColumn {
  item,
  category,
  quantity,
  unit,
  location,
  expiry,
  minQty,
  status,
  actions,
}

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
  InventoryColumn? _sortColumn;
  bool _sortAscending = true;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'en_GB');
  final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  static const List<InventoryColumn> _columnOrder = [
    InventoryColumn.item,
    InventoryColumn.category,
    InventoryColumn.quantity,
    InventoryColumn.unit,
    InventoryColumn.location,
    InventoryColumn.expiry,
    InventoryColumn.minQty,
    InventoryColumn.status,
    InventoryColumn.actions,
  ];
  static const Set<InventoryColumn> _nonToggleableColumns = {
    InventoryColumn.actions,
  };

  late Set<InventoryColumn> _visibleColumns;
  List<InventoryColumn> get _activeColumns => _columnOrder
      .where(
        (column) =>
            _visibleColumns.contains(column) ||
            _nonToggleableColumns.contains(column),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _rows = List<InventoryItem>.from(widget.items);
    _visibleColumns = _columnOrder
        .where((column) => !_nonToggleableColumns.contains(column))
        .toSet();
  }

  @override
  void didUpdateWidget(covariant InventoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _rows = List<InventoryItem>.from(widget.items);
      if (_sortColumn != null) {
        _applySort(_sortColumn!, _sortAscending);
      }
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _applySort(InventoryColumn column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _rows.sort((a, b) {
        final Comparable aValue = _sortValue(column, a);
        final Comparable bValue = _sortValue(column, b);
        final result = Comparable.compare(aValue, bValue);
        return ascending ? result : -result;
      });
    });
  }

  Comparable _sortValue(InventoryColumn column, InventoryItem item) {
    switch (column) {
      case InventoryColumn.item:
        return item.name.toLowerCase();
      case InventoryColumn.category:
        final category =
            widget.provider.getCategoryById(item.category)?.name ??
            item.category;
        return category.toLowerCase();
      case InventoryColumn.quantity:
        return item.quantity;
      case InventoryColumn.unit:
        return item.unit.toLowerCase();
      case InventoryColumn.location:
        return (item.location ?? '').toLowerCase();
      case InventoryColumn.expiry:
        return item.expirationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      case InventoryColumn.minQty:
        return item.lowStockThreshold;
      case InventoryColumn.status:
        return item.stockStatus.index;
      case InventoryColumn.actions:
        return 0;
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Inventory (${_rows.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openColumnPicker,
                      icon: const Icon(Icons.view_column),
                      label: const Text('Columns'),
                    ),
                  ],
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
                            child: Builder(
                              builder: (context) {
                                final columns = _activeColumns;
                                final columnWidths = <int, TableColumnWidth>{};
                                for (var i = 0; i < columns.length; i++) {
                                  columnWidths[i] = _columnWidth(columns[i]);
                                }

                                return Table(
                                  columnWidths: columnWidths,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    _buildHeaderRow(theme, columns),
                                    ..._rows.map(
                                      (item) =>
                                          _buildDataRow(item, theme, columns),
                                    ),
                                  ],
                                );
                              },
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

  void _openColumnPicker() {
    final toggleableColumns = _columnOrder
        .where((column) => !_nonToggleableColumns.contains(column))
        .toList();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final tempSelection = Set<InventoryColumn>.from(_visibleColumns);
        return StatefulBuilder(
          builder: (context, setModalState) {
            void handleToggle(InventoryColumn column, bool value) {
              setModalState(() {
                if (value) {
                  tempSelection.add(column);
                } else if (tempSelection.length > 1) {
                  tempSelection.remove(column);
                }
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose columns',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...toggleableColumns.map(
                    (column) => CheckboxListTile(
                      value: tempSelection.contains(column),
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) {
                        if (value == null) return;
                        if (!value && tempSelection.length == 1) {
                          return;
                        }
                        handleToggle(column, value);
                      },
                      title: Text(_columnLabel(column)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _visibleColumns = tempSelection;
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  TableColumnWidth _columnWidth(InventoryColumn column) {
    switch (column) {
      case InventoryColumn.item:
        return const FlexColumnWidth(3.2);
      case InventoryColumn.category:
        return const FlexColumnWidth(2.4);
      case InventoryColumn.quantity:
        return const FixedColumnWidth(88);
      case InventoryColumn.unit:
        return const FixedColumnWidth(76);
      case InventoryColumn.location:
        return const FlexColumnWidth(2.2);
      case InventoryColumn.expiry:
        return const FlexColumnWidth(2.2);
      case InventoryColumn.minQty:
        return const FixedColumnWidth(96);
      case InventoryColumn.status:
        return const FlexColumnWidth(2.2);
      case InventoryColumn.actions:
        return const FixedColumnWidth(160);
    }
  }

  String _columnLabel(InventoryColumn column) {
    switch (column) {
      case InventoryColumn.item:
        return 'Item';
      case InventoryColumn.category:
        return 'Category';
      case InventoryColumn.quantity:
        return 'Qty';
      case InventoryColumn.unit:
        return 'Unit';
      case InventoryColumn.location:
        return 'Location';
      case InventoryColumn.expiry:
        return 'Expiry';
      case InventoryColumn.minQty:
        return 'Min qty';
      case InventoryColumn.status:
        return 'Status';
      case InventoryColumn.actions:
        return 'Actions';
    }
  }

  TableRow _buildHeaderRow(ThemeData theme, List<InventoryColumn> columns) {
    Widget headerCell(InventoryColumn column) {
      final sortable = column != InventoryColumn.actions;
      final isSorted = _sortColumn == column;
      final icon = isSorted
          ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more;
      final label = _columnLabel(column);

      if (!sortable) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return InkWell(
        onTap: () => _applySort(column, isSorted ? !_sortAscending : true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: isSorted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      children: columns.map(headerCell).toList(),
    );
  }

  TableRow _buildDataRow(
    InventoryItem item,
    ThemeData theme,
    List<InventoryColumn> columns,
  ) {
    final category = widget.provider.getCategoryById(item.category);

    Widget cell(
      Widget child, {
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 4,
      ),
    }) {
      return Padding(
        padding: padding,
        child: Align(alignment: Alignment.center, child: child),
      );
    }

    Widget textCell(String value) {
      return cell(
        Text(
          value,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget actionsCell() {
      return PopupMenuButton<_ActionOption>(
        tooltip: 'Actions',
        position: PopupMenuPosition.over,
        onSelected: (value) async {
          switch (value) {
            case _ActionOption.edit:
              if (widget.onEdit != null) widget.onEdit!(item);
              break;
            case _ActionOption.details:
              if (widget.onDetails != null) widget.onDetails!(item);
              break;
            case _ActionOption.outOfStock:
              await widget.provider.updateItem(
                item,
                newQuantity: 0,
                action: UpdateAction.set,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} marked out of stock')),
              );
              break;
            case _ActionOption.remove:
              if (widget.onDelete != null) widget.onDelete!(item);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _ActionOption.edit,
            child: Text('Adjust quantity'),
          ),
          const PopupMenuItem(
            value: _ActionOption.details,
            child: Text('Details'),
          ),
          const PopupMenuItem(
            value: _ActionOption.outOfStock,
            child: Text('Mark out of stock'),
          ),
          PopupMenuItem(
            value: _ActionOption.remove,
            child: Text(
              'Remove',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.contentPadding,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: const Icon(Icons.more_vert, size: 22),
        ),
      );
    }

    Widget buildColumnCell(InventoryColumn column) {
      switch (column) {
        case InventoryColumn.item:
          return cell(
            Text(
              item.name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          );
        case InventoryColumn.category:
          return cell(
            category != null
                ? _CategoryChip(category: category)
                : Text(
                    item.category,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
          );
        case InventoryColumn.quantity:
          return textCell(_numberFormat.format(item.quantity));
        case InventoryColumn.unit:
          return textCell(item.unit);
        case InventoryColumn.location:
          return cell(
            item.location != null && item.location!.isNotEmpty
                ? _TagChip(label: item.location!)
                : Text('-', style: theme.textTheme.bodyMedium),
          );
        case InventoryColumn.expiry:
          final expiration = item.expirationDate;
          final label = expiration != null
              ? _dateFormat.format(expiration.toLocal())
              : '—';
          return textCell(label);
        case InventoryColumn.minQty:
          return textCell(_numberFormat.format(item.lowStockThreshold));
        case InventoryColumn.status:
          return cell(_StatusIndicator(item: item));
        case InventoryColumn.actions:
          return cell(actionsCell());
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      children: columns.map(buildColumnCell).toList(),
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

enum _ActionOption { edit, details, outOfStock, remove }

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
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
    final background = baseColor.withValues(alpha: 0.16);
    final border = baseColor.withValues(alpha: 0.32);

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
