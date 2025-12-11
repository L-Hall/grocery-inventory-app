import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/soft_tile_icon.dart' show SoftTileCard;
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
  final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  double _itemColumnFlex = 4.5;
  Future<void> _promptNumberEdit(
    BuildContext context,
    InventoryItem item, {
    required bool isQuantity,
  }) async {
    final controller = TextEditingController(
      text: isQuantity
          ? item.quantity.toString()
          : item.lowStockThreshold.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isQuantity ? 'Edit quantity' : 'Edit min qty'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: true,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter value',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed != null) {
                  Navigator.of(context).pop(parsed);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    if (isQuantity) {
      await widget.provider.updateItem(
        item,
        newQuantity: result,
        action: UpdateAction.set,
      );
    } else {
      await widget.provider.updateItem(
        item,
        newLowStockThreshold: result,
      );
    }

    if (mounted) {
      widget.provider.refresh();
    }
  }

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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SoftTileCard(
                      tint: _softTileTint(theme),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Inventory (${_rows.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openColumnPicker,
                            icon: const Icon(Icons.view_column_outlined, size: 18),
                            label: const Text('Columns'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                                    ..._rows.asMap().entries.map(
                                      (entry) => _buildDataRow(
                                        entry.value,
                                        theme,
                                        columns,
                                        entry.key,
                                      ),
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

  Color? _softTileTint(ThemeData theme) {
    if (theme.brightness == Brightness.dark) return null;
    return theme.colorScheme.primary.withValues(alpha: 0.12);
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

            return SafeArea(
              child: SingleChildScrollView(
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
        return FlexColumnWidth(_itemColumnFlex);
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

      final trailing = column == InventoryColumn.item
          ? IconButton(
              tooltip: 'Toggle item column width',
              icon: const Icon(Icons.unfold_more),
              onPressed: () {
                setState(() {
                  _itemColumnFlex = _itemColumnFlex >= 6 ? 4.0 : 6.0;
                });
              },
            )
          : null;

      return InkWell(
        onTap: () => _applySort(column, isSorted ? !_sortAscending : true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (trailing != null) trailing,
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 4),
                Icon(
                  icon,
                  size: 16,
                  color: isSorted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                ),
              ],
            ),
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
    int rowIndex,
  ) {
    final category = widget.provider.getCategoryById(item.category);
    final rowColor = rowIndex.isEven
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);

    Widget cell(
      Widget child, {
      EdgeInsetsGeometry padding =
          const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      VoidCallback? onDoubleTap,
    }) {
      final content = Padding(
        padding: padding,
        child: Align(alignment: Alignment.center, child: child),
      );
      if (onDoubleTap == null) return content;
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: content,
      );
    }

    Widget textCell(String value) {
      return cell(
        Text(
          value,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
            onDoubleTap: () => widget.onEdit?.call(item),
          );
        case InventoryColumn.quantity:
          return cell(
            _ValuePill(
              label: item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(1),
              color: theme.colorScheme.primary,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            onDoubleTap: () => _promptNumberEdit(
              context,
              item,
              isQuantity: true,
            ),
          );
        case InventoryColumn.unit:
          return textCell(item.unit);
        case InventoryColumn.location:
          return cell(
            item.location != null && item.location!.isNotEmpty
                ? _TagChip(label: item.location!)
                : Text('-', style: theme.textTheme.bodyMedium),
            onDoubleTap: () => widget.onEdit?.call(item),
          );
        case InventoryColumn.expiry:
          final expiration = item.expirationDate;
          final label = expiration != null
              ? _dateFormat.format(expiration.toLocal())
              : '—';
          return cell(
            Text(
              label,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            onDoubleTap: () => widget.onEdit?.call(item),
          );
        case InventoryColumn.minQty:
          return cell(
            _ValuePill(
              label: item.lowStockThreshold % 1 == 0
                  ? item.lowStockThreshold.toInt().toString()
                  : item.lowStockThreshold.toStringAsFixed(1),
              color: theme.colorScheme.primary,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            onDoubleTap: () => _promptNumberEdit(
              context,
              item,
              isQuantity: false,
            ),
          );
        case InventoryColumn.status:
          return cell(_StatusIndicator(item: item));
        case InventoryColumn.actions:
          return cell(actionsCell());
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
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

    final scheme = Theme.of(context).colorScheme;
    if (item.isExpired) {
      icon = Icons.error;
      color = scheme.error;
      label = 'Expired';
    } else if (item.stockStatus == StockStatus.out) {
      icon = Icons.cancel_presentation;
      color = scheme.error;
      label = 'Out';
    } else if (item.stockStatus == StockStatus.low) {
      icon = Icons.warning;
      color = Colors.amber[800] ?? scheme.secondary;
      label = 'Low';
    } else if (item.isExpiringSoon) {
      icon = Icons.schedule;
      color = Colors.amber[800] ?? scheme.secondary;
      label = 'Soon';
    } else {
      icon = Icons.check_circle;
      color = Colors.green[700] ?? scheme.secondary;
      label = 'In';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
    final base = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            base.withValues(alpha: 0.16),
            base.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: base.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 160),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
                color: base,
                fontWeight: FontWeight.w700,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: 0.20),
            baseColor.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: baseColor.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 180),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          category.name,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: baseColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
