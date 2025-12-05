import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../models/category.dart' as cat;

Future<void> showInventoryItemEditorSheet(
  BuildContext context, {
  InventoryItem? item,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _InventoryItemEditorSheet(item: item),
  );
}

class _InventoryItemEditorSheet extends StatefulWidget {
  const _InventoryItemEditorSheet({this.item});

  final InventoryItem? item;

  @override
  State<_InventoryItemEditorSheet> createState() =>
      _InventoryItemEditorSheetState();
}

class _InventoryItemEditorSheetState extends State<_InventoryItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _notesController;

  String _unit = 'item';
  String _category = 'other';
  bool _isSaving = false;

  static const List<String> _units = <String>[
    'item',
    'pcs',
    'pack',
    'bag',
    'bottle',
    'jar',
    'tin',
    'litre',
    'pint',
    'ml',
    'kg',
    'g',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.item;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _quantityController = TextEditingController(
      text: existing?.quantity.toString() ?? '',
    );
    _unit = existing?.unit ?? _units.first;
    _category = existing?.category ?? 'other';
    _locationController = TextEditingController(text: existing?.location ?? '');
    _lowStockController = TextEditingController(
      text: existing?.lowStockThreshold.toString() ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _lowStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final categories = inventoryProvider.categories.isNotEmpty
        ? inventoryProvider.categories
        : cat.DefaultCategories.defaultCategories;

    if (!categories.any((element) => element.id == _category)) {
      _category = categories.first.id;
    }

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: bottomPadding + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    widget.item == null ? 'Add Inventory Item' : 'Edit Item',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                enabled: widget.item == null,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final quantity = double.tryParse(value ?? '');
                        if (quantity == null || quantity < 0) {
                          return 'Enter 0 or a positive quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _units.contains(_unit) ? _unit : _units.first,
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _unit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
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
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              if (inventoryProvider.locations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: inventoryProvider.locations
                        .take(8)
                        .map(
                          (option) => ActionChip(
                            label: Text(option.name),
                            onPressed: () {
                              _locationController.text = option.name;
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _lowStockController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Low Stock Threshold',
                  prefixIcon: Icon(Icons.warning_amber_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    widget.item == null ? 'Add Item' : 'Save Changes',
                  ),
                  onPressed: _isSaving ? null : () => _submit(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final lowStockText = _lowStockController.text.trim();
    final lowStockThreshold = double.tryParse(
      lowStockText.isEmpty ? '0' : lowStockText,
    );
    final location = _locationController.text.trim().isEmpty
        ? null
        : _locationController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() {
      _isSaving = true;
    });

    final success = await inventoryProvider.saveItem(
      existingItem: widget.item,
      name: name,
      quantity: quantity,
      unit: _unit,
      category: _category,
      location: location,
      lowStockThreshold: lowStockThreshold == 0 ? null : lowStockThreshold,
      notes: notes,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.item == null
                ? 'Item added to inventory'
                : 'Item updated successfully',
          ),
        ),
      );
    } else {
      final error = inventoryProvider.error ?? 'Failed to save item';
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
