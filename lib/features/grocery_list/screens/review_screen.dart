import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/grocery_list_provider.dart';
import '../models/parsed_item.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/models/category.dart';
import '../../inventory/providers/inventory_provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

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
                    Icons.warning,
                    color: Colors.orange.shade700,
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
              Expanded(
                child: _buildItemsList(context, parseResult.items),
              ),
              
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

  Widget _buildSummaryHeader(BuildContext context, GroceryListProvider groceryProvider) {
    final theme = Theme.of(context);
    final parseResult = groceryProvider.lastParseResult!;
    final stats = groceryProvider.parseStatistics;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assessment,
                color: theme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Parse Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const Spacer(),
              if (parseResult.usedFallback)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fallback Parser',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
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
                theme.primaryColor,
              ),
              if (stats['high_confidence']! > 0)
                _buildStatChip(
                  context,
                  '${stats['high_confidence']} high confidence',
                  Icons.check_circle,
                  Colors.green,
                ),
              if (stats['low_confidence']! > 0)
                _buildStatChip(
                  context,
                  '${stats['low_confidence']} low confidence',
                  Icons.warning,
                  Colors.orange,
                ),
              if (stats['edited']! > 0)
                _buildStatChip(
                  context,
                  '${stats['edited']} edited',
                  Icons.edit,
                  Colors.blue,
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

  Widget _buildStatChip(BuildContext context, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with confidence and action
            Row(
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
                        '${item.quantity} ${item.unit}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getActionColor(item.action).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getActionColor(item.action).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    item.action.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getActionColor(item.action),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                // More actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _handleItemAction(context, action, item, index),
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
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Confidence indicator
            Row(
              children: [
                _buildConfidenceIndicator(context, item),
                const SizedBox(width: 16),
                if (item.category != null)
                  Expanded(
                    child: Text(
                      'Category: ${item.category}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (item.isEdited)
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
              ],
            ),
            
            // Notes if any
            if (item.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${item.notes}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context, ParsedItem item) {
    final theme = Theme.of(context);
    final level = item.confidenceLevel;
    
    Color color;
    IconData icon;
    
    switch (level) {
      case ConfidenceLevel.high:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ConfidenceLevel.medium:
        color = Colors.orange;
        icon = Icons.help;
        break;
      case ConfidenceLevel.low:
        color = Colors.red;
        icon = Icons.warning;
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

  Widget _buildBottomActions(BuildContext context, GroceryListProvider groceryProvider) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
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
                onPressed: _isApplying ? null : () => _handleApply(context, groceryProvider),
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

  Color _getActionColor(UpdateAction action) {
    switch (action) {
      case UpdateAction.add:
        return Colors.green;
      case UpdateAction.subtract:
        return Colors.orange;
      case UpdateAction.set:
        return Colors.blue;
    }
  }

  void _handleItemAction(BuildContext context, String action, ParsedItem item, int index) {
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    
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
    final quantityController = TextEditingController(text: item.quantity.toString());
    final unitController = TextEditingController(text: item.unit);
    UpdateAction selectedAction = item.action;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text);
                if (quantity != null) {
                  final updatedItem = item.copyWith(
                    quantity: quantity,
                    unit: unitController.text,
                    action: selectedAction,
                    isEdited: true,
                  );
                  
                  final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
                  groceryProvider.updateParsedItem(index, updatedItem);
                  
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated ${item.name}')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarningsDialog(BuildContext context, List<String> warnings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Warnings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings.map((warning) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(warning)),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleCancel(BuildContext context) {
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    groceryProvider.clearParseResult();
    Navigator.of(context).pop();
  }

  void _handleApply(BuildContext context, GroceryListProvider groceryProvider) async {
    setState(() {
      _isApplying = true;
    });

    final success = await groceryProvider.applyParsedItems();

    setState(() {
      _isApplying = false;
    });

    if (success && mounted) {
      // Refresh inventory
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      await inventoryProvider.refresh();
      
      // Show success message and go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied ${groceryProvider.parsedItems.length} changes successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groceryProvider.error ?? 'Failed to apply changes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}