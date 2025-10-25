import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/grocery_list_provider.dart';
import '../models/parsed_item.dart';
import '../../inventory/models/inventory_item.dart' show UpdateAction;
import '../../inventory/providers/inventory_provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Changes'),
        centerTitle: true,
        actions: [
          // Validation info button
          Consumer<GroceryListProvider>(
            builder: (context, groceryProvider, _) {
              final warnings = groceryProvider.validateParsedItems();
              if (warnings.isNotEmpty) {
                return IconButton(
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.tertiary,
                  ),
                  onPressed: () => _showWarningsDialog(context, warnings),
                  tooltip: 'View warnings',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<GroceryListProvider>(
        builder: (context, groceryProvider, _) {
          final parseResult = groceryProvider.lastParseResult;

          if (parseResult == null || parseResult.items.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Summary header
              _buildSummaryHeader(context, groceryProvider),

              // Items list
              Expanded(child: _buildItemsList(context, parseResult.items)),

              // Bottom actions
              _buildBottomActions(context, groceryProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No items to review',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go back and add some grocery text to parse',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    GroceryListProvider groceryProvider,
  ) {
    final theme = Theme.of(context);
    final parseResult = groceryProvider.lastParseResult!;
    final stats = groceryProvider.parseStatistics;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assessment,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Parse Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (parseResult.usedFallback)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fallback Parser',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Statistics
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildStatChip(
                context,
                '${stats['total']} items',
                Icons.list,
                theme.colorScheme.primary,
              ),
              if (stats['high_confidence']! > 0)
                _buildStatChip(
                  context,
                  '${stats['high_confidence']} high confidence',
                  Icons.check_circle,
                  theme.colorScheme.primary,
                ),
              if (stats['low_confidence']! > 0)
                _buildStatChip(
                  context,
                  '${stats['low_confidence']} low confidence',
                  Icons.warning_amber_rounded,
                  theme.colorScheme.tertiary,
                ),
              if (stats['edited']! > 0)
                _buildStatChip(
                  context,
                  '${stats['edited']} edited',
                  Icons.edit,
                  theme.colorScheme.secondary,
                ),
            ],
          ),

          // Changes summary
          if (groceryProvider.hasUnappliedChanges) ...[
            const SizedBox(height: 8),
            Text(
              groceryProvider.getChangesSummary(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, List<ParsedItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildItemCard(context, items[index], index);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, ParsedItem item, int index) {
    final theme = Theme.of(context);
    final formattedExpiry = item.expiryDate != null
        ? _formatExpiryDate(item.expiryDate!)
        : null;
    final quantityText = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final infoChips = <Widget>[
      if (item.category != null && item.category!.trim().isNotEmpty)
        _buildInfoChip(theme, Icons.category_outlined, item.category!.trim()),
      if (item.location != null && item.location!.trim().isNotEmpty)
        _buildInfoChip(
          theme,
          Icons.location_on_outlined,
          item.location!.trim(),
        ),
      if (formattedExpiry != null)
        _buildInfoChip(theme, Icons.event, 'Expiry: $formattedExpiry'),
      if (item.isEdited) _buildInfoChip(theme, Icons.edit, 'Edited'),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with confidence and action
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name and quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$quantityText ${item.unit}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildActionBadge(theme, item.action),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) =>
                      _handleItemAction(context, action, item, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Remove',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildConfidenceIndicator(context, item),

            if (infoChips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: infoChips),
            ],

            if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.notes!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBadge(ThemeData theme, UpdateAction action) {
    final color = _getActionColor(theme, action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        action.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, IconData icon, String label) {
    final foreground = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpiryDate(DateTime date) {
    return DateFormat.yMMMMd('en_GB').format(date);
  }

  Widget _buildConfidenceIndicator(BuildContext context, ParsedItem item) {
    final theme = Theme.of(context);
    final level = item.confidenceLevel;
    Color color;
    IconData icon;

    switch (level) {
      case ConfidenceLevel.high:
        color = theme.colorScheme.primary;
        icon = Icons.check_circle;
        break;
      case ConfidenceLevel.medium:
        color = theme.colorScheme.secondary;
        icon = Icons.help_outline;
        break;
      case ConfidenceLevel.low:
        color = theme.colorScheme.error;
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          level.displayName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    GroceryListProvider groceryProvider,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: _isApplying ? null : () => _handleCancel(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),

            const SizedBox(width: 16),

            // Apply button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isApplying
                    ? null
                    : () => _handleApply(context, groceryProvider),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isApplying
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Applying...'),
                        ],
                      )
                    : const Text('Apply Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(ThemeData theme, UpdateAction action) {
    switch (action) {
      case UpdateAction.add:
        return theme.colorScheme.primary;
      case UpdateAction.subtract:
        return theme.colorScheme.secondary;
      case UpdateAction.set:
        return theme.colorScheme.tertiary;
    }
    return theme.colorScheme.primary;
  }

  void _handleItemAction(
    BuildContext context,
    String action,
    ParsedItem item,
    int index,
  ) {
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );

    switch (action) {
      case 'edit':
        _showEditDialog(context, item, index);
        break;
      case 'remove':
        groceryProvider.removeParsedItem(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${item.name}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                groceryProvider.addParsedItem(item);
              },
            ),
          ),
        );
        break;
    }
  }

  void _showEditDialog(BuildContext context, ParsedItem item, int index) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );

    final formattedQuantity = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();

    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: formattedQuantity);
    final unitController = TextEditingController(text: item.unit);
    final categoryController = TextEditingController(text: item.category ?? '');
    final locationController = TextEditingController(text: item.location ?? '');
    final notesController = TextEditingController(text: item.notes ?? '');
    final expiryController = TextEditingController(
      text: item.expiryDate != null ? _formatExpiryDate(item.expiryDate!) : '',
    );

    UpdateAction selectedAction = item.action;
    DateTime? selectedExpiry = item.expiryDate;
    bool expiryCleared = false;

    final controllers = [
      nameController,
      quantityController,
      unitController,
      categoryController,
      locationController,
      notesController,
      expiryController,
    ];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Edit ${item.name}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter an item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) {
                        return 'Enter a quantity';
                      }
                      final parsed = double.tryParse(raw);
                      if (parsed == null) {
                        return 'Enter a valid number';
                      }
                      if (parsed <= 0) {
                        return 'Quantity must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a unit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UpdateAction>(
                    value: selectedAction,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      border: OutlineInputBorder(),
                    ),
                    items: UpdateAction.values.map((action) {
                      return DropdownMenuItem(
                        value: action,
                        child: Text(action.displayName),
                      );
                    }).toList(),
                    onChanged: (action) {
                      if (action != null) {
                        setState(() {
                          selectedAction = action;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: categoryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: expiryController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Expiry date (optional)',
                      border: const OutlineInputBorder(),
                      suffixIcon: selectedExpiry != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  selectedExpiry = null;
                                  expiryCleared = true;
                                  expiryController.clear();
                                });
                              },
                              tooltip: 'Clear expiry date',
                            )
                          : const Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      FocusScope.of(dialogContext).unfocus();
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedExpiry ?? now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 1095)),
                        helpText: 'Select expiry date',
                      );
                      if (picked != null) {
                        setState(() {
                          selectedExpiry = picked;
                          expiryCleared = false;
                          expiryController.text = _formatExpiryDate(picked);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                final quantity = double.parse(quantityController.text.trim());
                final name = nameController.text.trim();
                final unit = unitController.text.trim();
                final category = categoryController.text.trim().isEmpty
                    ? null
                    : categoryController.text.trim();
                final location = locationController.text.trim().isEmpty
                    ? null
                    : locationController.text.trim();
                final notes = notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim();

                final updatedItem = item.copyWith(
                  name: name,
                  quantity: quantity,
                  unit: unit,
                  action: selectedAction,
                  category: category,
                  location: location,
                  notes: notes,
                  expiryDate: selectedExpiry,
                  keepExistingExpiry: !expiryCleared,
                  isEdited: true,
                );

                groceryProvider.updateParsedItem(index, updatedItem);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Updated ${updatedItem.name}')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  void _showWarningsDialog(BuildContext context, List<String> warnings) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Review Warnings', style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings
              .map(
                (warning) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(warning, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleCancel(BuildContext context) {
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );
    groceryProvider.clearParseResult();
    Navigator.of(context).pop();
  }

  void _handleApply(
    BuildContext context,
    GroceryListProvider groceryProvider,
  ) async {
    final pendingCount = groceryProvider.parsedItems.length;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isApplying = true;
    });

    final success = await groceryProvider.applyParsedItems();

    if (!mounted) {
      return;
    }

    setState(() {
      _isApplying = false;
    });

    if (success) {
      await inventoryProvider.refresh();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Applied $pendingCount change${pendingCount == 1 ? '' : 's'} successfully',
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
      );

      navigator.pop();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(groceryProvider.error ?? 'Failed to apply changes'),
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }
}
