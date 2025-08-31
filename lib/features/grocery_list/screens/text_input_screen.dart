import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/grocery_list_provider.dart';
import 'review_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({Key? key}) : super(key: key);

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Input mode state
  InputMode _inputMode = InputMode.text;
  File? _selectedImage;
  String? _imageBase64;
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
              _buildInstructionsCard(theme),
              
              const SizedBox(height: 16),
              
              // Input mode selector
              _buildInputModeSelector(theme),
              
              const SizedBox(height: 16),
              
              // Input area (changes based on mode)
              Expanded(
                child: _buildInputArea(theme),
              ),
              
              const SizedBox(height: 16),
              
              // Process button and status
              _buildProcessSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme) {
    return Card(
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
                  _inputMode == InputMode.text 
                      ? 'Natural Language Input'
                      : 'Receipt Scanner',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const Spacer(),
                if (_inputMode == InputMode.text)
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
              _getInstructionText(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_showTips && _inputMode == InputMode.text) ...[
              const SizedBox(height: 12),
              _buildTipsSection(context),
            ],
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    switch (_inputMode) {
      case InputMode.text:
        return 'Type or paste your grocery text below. Use natural language like "bought 2 gallons milk" or "used 3 eggs for cooking".';
      case InputMode.camera:
        return 'Take a photo of your grocery receipt or shopping list. The AI will read and extract items directly from the image.';
      case InputMode.gallery:
        return 'Select a photo of your receipt or list from your gallery. The AI will analyze the image and extract grocery items.';
      case InputMode.file:
        return 'Upload a file containing your grocery list or receipt. Supports images and PDF files.';
    }
  }

  Widget _buildInputModeSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildModeButton(
            InputMode.text,
            Icons.text_fields,
            'Text',
            theme,
          ),
          _buildModeButton(
            InputMode.camera,
            Icons.camera_alt,
            'Camera',
            theme,
          ),
          _buildModeButton(
            InputMode.gallery,
            Icons.photo_library,
            'Gallery',
            theme,
          ),
          _buildModeButton(
            InputMode.file,
            Icons.upload_file,
            'File',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    InputMode mode,
    IconData icon,
    String label,
    ThemeData theme,
  ) {
    final isSelected = _inputMode == mode;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectInputMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected 
                    ? theme.colorScheme.onPrimary 
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected 
                      ? theme.colorScheme.onPrimary 
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    switch (_inputMode) {
      case InputMode.text:
        return _buildTextInput(theme);
      case InputMode.camera:
      case InputMode.gallery:
      case InputMode.file:
        return _buildImageInput(theme);
    }
  }

  Widget _buildTextInput(ThemeData theme) {
    return Consumer<GroceryListProvider>(
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
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
    );
  }

  Widget _buildImageInput(ThemeData theme) {
    if (_selectedImage != null) {
      return _buildImagePreview(theme);
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
      ),
      child: InkWell(
        onTap: _handleImageSelection,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getPlaceholderIcon(),
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _getPlaceholderText(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getPlaceholderSubtext(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleImageSelection,
              icon: Icon(_getActionIcon()),
              label: Text(_getActionText()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
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
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _clearImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Image selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _handleImageSelection,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlaceholderIcon() {
    switch (_inputMode) {
      case InputMode.camera:
        return Icons.camera_alt_outlined;
      case InputMode.gallery:
        return Icons.photo_library_outlined;
      case InputMode.file:
        return Icons.upload_file_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  String _getPlaceholderText() {
    switch (_inputMode) {
      case InputMode.camera:
        return 'Take a Photo';
      case InputMode.gallery:
        return 'Select from Gallery';
      case InputMode.file:
        return 'Upload a File';
      default:
        return 'Add Image';
    }
  }

  String _getPlaceholderSubtext() {
    switch (_inputMode) {
      case InputMode.camera:
        return 'Capture your receipt or grocery list';
      case InputMode.gallery:
        return 'Choose an existing photo';
      case InputMode.file:
        return 'PDF or image files supported';
      default:
        return '';
    }
  }

  IconData _getActionIcon() {
    switch (_inputMode) {
      case InputMode.camera:
        return Icons.camera_alt;
      case InputMode.gallery:
        return Icons.photo;
      case InputMode.file:
        return Icons.folder_open;
      default:
        return Icons.add;
    }
  }

  String _getActionText() {
    switch (_inputMode) {
      case InputMode.camera:
        return 'Open Camera';
      case InputMode.gallery:
        return 'Browse Gallery';
      case InputMode.file:
        return 'Choose File';
      default:
        return 'Select';
    }
  }

  Widget _buildProcessSection(ThemeData theme) {
    return Consumer<GroceryListProvider>(
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
            color: theme.primaryColor.withOpacity(0.05),
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
              )).toList(),
            ],
          ),
        );
      },
    );
  }

  void _selectInputMode(InputMode mode) {
    setState(() {
      _inputMode = mode;
      // Clear image if switching to text mode
      if (mode == InputMode.text) {
        _clearImage();
      }
    });
  }

  Future<void> _handleImageSelection() async {
    switch (_inputMode) {
      case InputMode.camera:
        await _pickImageFromCamera();
        break;
      case InputMode.gallery:
        await _pickImageFromGallery();
        break;
      case InputMode.file:
        await _pickFile();
        break;
      default:
        break;
    }
  }

  Future<void> _pickImageFromCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _processImage(File(image.path));
      }
    } else {
      _showPermissionDeniedDialog('Camera');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    
    if (image != null) {
      await _processImage(File(image.path));
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      await _processImage(File(result.files.single.path!));
    }
  }

  Future<void> _processImage(File image) async {
    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);
    
    setState(() {
      _selectedImage = image;
      _imageBase64 = base64String;
    });
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
    });
  }

  bool _canProcess(GroceryListProvider groceryProvider) {
    if (groceryProvider.isParsing) return false;
    
    if (_inputMode == InputMode.text) {
      return _textController.text.trim().isNotEmpty;
    } else {
      return _selectedImage != null && _imageBase64 != null;
    }
  }

  Future<void> _handleProcess() async {
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    
    bool success;
    if (_inputMode == InputMode.text) {
      final text = _textController.text.trim();
      if (text.isEmpty) return;
      
      success = await groceryProvider.parseGroceryText(text: text);
    } else {
      if (_imageBase64 == null) return;
      
      success = await groceryProvider.parseGroceryImage(
        imageBase64: _imageBase64!,
        imageType: 'receipt',
      );
    }

    if (success && mounted) {
      // Navigate to review screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ReviewScreen(),
        ),
      );
    }
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

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text(
          'Please grant $permission permission in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

enum InputMode {
  text,
  camera,
  gallery,
  file,
}