import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  late final stt.SpeechToText _speechToText;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _interimTranscript = '';
  
  // Input mode state
  InputMode _inputMode = InputMode.text;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _imageBase64;
  bool _showTips = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _speechToText = stt.SpeechToText();
    _initSpeechEngine();
    
    // Initialize with any existing text from provider
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    _textController.text = groceryProvider.currentInputText;
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
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
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _inputMode == InputMode.text
                      ? 'Natural language input'
                      : 'Receipt scanner',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
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
        return 'Type, paste, or dictate your grocery updates. Use natural language such as “bought 2 litres of semi-skimmed milk” or “used 3 eggs baking cupcakes”.';
      case InputMode.camera:
        return 'Take a photo of your grocery receipt or shopping list. The AI will read and extract items directly from the image.';
      case InputMode.gallery:
        return 'Select a saved photo of your receipt or list. The AI will analyse the image and extract grocery items.';
      case InputMode.file:
        return 'Upload an image or PDF of your receipt or list. We will scan it and suggest updates.';
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
                      hintText:
                          'Examples:\n• bought 2 litres of semi-skimmed milk and 3 loaves of bread\n• used 4 eggs baking cupcakes\n• have 5 apples left in the fruit bowl\n• finished the orange juice',
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
                    Text(
                      '${_textController.text.length} characters',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_textController.text.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _textController.clear();
                              groceryProvider.setCurrentInputText('');
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _handlePaste,
                          icon: const Icon(Icons.content_paste, size: 18),
                          label: const Text('Paste'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _toggleListening,
                          icon: Icon(
                            _isListening ? Icons.mic_off : Icons.mic_none,
                            size: 18,
                          ),
                          label: Text(_isListening ? 'Stop dictation' : 'Dictate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isListening || _interimTranscript.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDictationBanner(theme),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDictationBanner(ThemeData theme) {
    final message = _interimTranscript.isNotEmpty
        ? _interimTranscript
        : (_isListening
            ? 'Listening… speak naturally and we will transcribe in UK English.'
            : '');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: (_isListening || _interimTranscript.isNotEmpty) ? 1 : 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message.isEmpty
                    ? 'Listening idle'
                    : message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (_isListening)
              TextButton(
                onPressed: _toggleListening,
                child: const Text('Stop'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageInput(ThemeData theme) {
    if (_selectedFileBytes != null || (_selectedFileName != null && _selectedFileName!.toLowerCase().endsWith('.pdf'))) {
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
    final isPdf = (_selectedFileName ?? '').toLowerCase().endsWith('.pdf');
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!isPdf && _selectedFileBytes != null)
                    Image.memory(
                      _selectedFileBytes!,
                      fit: BoxFit.contain,
                    )
                  else
                    Container(
                      color:
                          theme.colorScheme.surfaceVariant.withOpacity(0.25),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFileName ?? 'Receipt.pdf',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFileName ?? 'Image selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
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
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tips for better results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
                      style: TextStyle(color: theme.colorScheme.primary),
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
      } else if (_isListening) {
        _speechToText.stop();
        _isListening = false;
        _interimTranscript = '';
      }
    });
  }

  Future<void> _initSpeechEngine() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'notListening' && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _interimTranscript = '';
          });
        }
      },
    );
    if (mounted) {
      setState(() => _isSpeechAvailable = available);
    }
  }

  Future<void> _toggleListening() async {
    if (!_isSpeechAvailable) {
      await _initSpeechEngine();
      if (!_isSpeechAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition unavailable on this device.')),
        );
        return;
      }
    }

    if (!_isListening) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showPermissionDeniedDialog('Microphone');
        return;
      }
      await _speechToText.listen(
        localeId: 'en_GB',
        onResult: _onSpeechResult,
        listenMode: stt.ListenMode.dictation,
      );
      setState(() {
        _isListening = true;
        _interimTranscript = '';
      });
    } else {
      await _speechToText.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _interimTranscript = result.recognizedWords;
    });
    if (result.finalResult) {
      _appendRecognisedText(result.recognizedWords);
      setState(() {
        _interimTranscript = '';
        _isListening = false;
      });
    }
  }

  void _appendRecognisedText(String recognised) {
    if (recognised.trim().isEmpty) return;
    final current = _textController.text.trimRight();
    final newText = current.isEmpty ? recognised : '$current\n$recognised';
    _textController.text = newText;
    _textController.selection =
        TextSelection.collapsed(offset: _textController.text.length);
    final groceryProvider =
        Provider.of<GroceryListProvider>(context, listen: false);
    groceryProvider.setCurrentInputText(_textController.text);
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
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showPermissionDeniedDialog('Camera');
        return;
      }
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final fileName = _resolveFileName(path: image.path, name: image.name);
      await _processPickedFile(
        bytes: bytes,
        fileName: fileName,
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final fileName = _resolveFileName(path: image.path, name: image.name);
      await _processPickedFile(
        bytes: bytes,
        fileName: fileName,
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;
    Uint8List? bytes = file.bytes;

    if (bytes == null) {
      if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
        final xFile = XFile(file.path!);
        bytes = await xFile.readAsBytes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to read selected file. Please try again.'),
            ),
          );
        }
        return;
      }
    }

    await _processPickedFile(
      bytes: bytes,
      fileName: _resolveFileName(path: file.path, name: file.name),
    );
  }

  Future<void> _processPickedFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final base64String = base64Encode(bytes);

    setState(() {
      _selectedFileBytes = bytes;
      _selectedFileName = fileName;
      _imageBase64 = base64String;
    });
  }

  void _clearImage() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _imageBase64 = null;
    });
  }

  bool _canProcess(GroceryListProvider groceryProvider) {
    if (groceryProvider.isParsing) return false;

    if (_inputMode == InputMode.text) {
      return _textController.text.trim().isNotEmpty;
    } else {
      return _imageBase64 != null;
    }
  }

  String _resolveFileName({String? path, String? name}) {
    if (name != null && name.isNotEmpty) return name;
    if (path == null || path.isEmpty) return 'receipt.png';
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  Future<void> _handleProcess() async {
    final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
        _interimTranscript = '';
      });
    }
    
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
