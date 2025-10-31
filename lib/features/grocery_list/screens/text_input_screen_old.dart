import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/grocery_list_provider.dart';
import 'review_screen.dart';
import '../../settings/screens/settings_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showTips = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    
    // Initialize with any existing text from provider
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    _textController.text = groceryProvider.currentInputText;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Natural Language Input',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showTips = !_showTips;
                              });
                            },
                            child: Text(_showTips ? 'Hide Tips' : 'Show Tips'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Type or paste your grocery text below. Use natural language like "bought 2 gallons milk" or "used 3 eggs for cooking".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_showTips) ...[
                        const SizedBox(height: 12),
                        _buildTipsSection(context),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Text input area
              Expanded(
                child: Consumer<GroceryListProvider>(
                  builder: (context, groceryProvider, _) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Input field
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: theme.textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: 'Examples:\n• bought 2 gallons milk and 3 loaves bread\n• used 4 eggs for cooking\n• have 5 apples left in fridge\n• finished the orange juice',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  height: 1.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              onChanged: (text) {
                                // Save text to provider to preserve state
                                groceryProvider.setCurrentInputText(text);
                              },
                            ),
                          ),
                          
                          // Action bar
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Character count
                                Text(
                                  '${_textController.text.length} characters',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Clear button
                                if (_textController.text.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () {
                                      _textController.clear();
                                      groceryProvider.setCurrentInputText('');
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    label: const Text('Clear'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                
                                const SizedBox(width: 8),
                                
                                // Paste button
                                TextButton.icon(
                                  onPressed: _handlePaste,
                                  icon: const Icon(Icons.content_paste, size: 18),
                                  label: const Text('Paste'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Process button and status
              Consumer<GroceryListProvider>(
                builder: (context, groceryProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error message
                      if (groceryProvider.hasError) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  groceryProvider.error!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: theme.colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                onPressed: groceryProvider.clearError,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Process button
                      ElevatedButton(
                        onPressed: _canProcess(groceryProvider) ? _handleProcess : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: groceryProvider.isParsing
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Processing...',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.psychology, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Process with AI',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<GroceryListProvider>(
      builder: (context, groceryProvider, _) {
        final tips = groceryProvider.getParsingTips();
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tips for better results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              ...tips.take(6).map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  bool _canProcess(GroceryListProvider groceryProvider) {
    return _textController.text.trim().isNotEmpty && 
           !groceryProvider.isParsing;
  }

  void _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      final currentText = _textController.text;
      final pastedText = data!.text!;
      
      // Insert at cursor or append if no selection
      final selection = _textController.selection;
      if (selection.isValid) {
        final newText = currentText.replaceRange(
          selection.start,
          selection.end,
          pastedText,
        );
        _textController.text = newText;
        _textController.selection = TextSelection.collapsed(
          offset: selection.start + pastedText.length,
        );
      } else {
        _textController.text = currentText + pastedText;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
      
      // Update provider
      final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
      groceryProvider.setCurrentInputText(_textController.text);
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text pasted successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleProcess() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    
    final success = await groceryProvider.parseGroceryText(
      text: text,
    );

    if (success && mounted) {
      // Navigate to review screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ReviewScreen(),
        ),
      );
    } else if (mounted) {
      // Show error message if parsing failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groceryProvider.error ?? 'Failed to process text',
          ),
          backgroundColor: Colors.red,
          action: groceryProvider.error?.contains('API key') == true
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    // Navigate to settings to set API key
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }
}
