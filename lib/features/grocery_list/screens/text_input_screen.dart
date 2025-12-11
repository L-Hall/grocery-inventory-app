import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:csv/csv.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/widgets/soft_tile_icon.dart'
    show SoftTileButton, SoftTileCard;
import '../../../core/widgets/sustain_background.dart';
import '../../../core/utils/file_downloader.dart';
import '../../analytics/models/agent_metrics.dart';
import '../../analytics/services/agent_metrics_service.dart';
import '../../uploads/models/upload_models.dart';
import '../providers/grocery_list_provider.dart';
import 'review_screen.dart';
import '../../inventory/services/csv_service.dart';
import '../../inventory/providers/inventory_provider.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

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
  String? _lastInventoryRefreshJobId;
  Timer? _refreshTimer;

  // Input mode state
  InputMode _inputMode = InputMode.text;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _imageBase64;
  bool _showTips = false;
  Stream<AgentMetrics?>? _agentMetricsStream;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _speechToText = stt.SpeechToText();
    _initSpeechEngine();
    if (getIt.isRegistered<AgentMetricsService>()) {
      _agentMetricsStream = getIt<AgentMetricsService>().watchGlobalMetrics();
    }

    // Initialize with any existing text from provider
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );
    _textController.text = groceryProvider.currentInputText;
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SustainBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInstructionsCard(theme),
                const SizedBox(height: 16),
                _buildInputModeSelector(theme),
                const SizedBox(height: 16),
                Expanded(child: _buildInputArea(theme)),
                const SizedBox(height: 16),
                _buildProcessSection(theme),
                const SizedBox(height: 16),
                _buildAgentMetricsCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme) {
    final softTint = _softTint(theme);
    return SoftTileCard(
      tint: softTint,
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
    final softTint = _softTint(theme);
    return SoftTileCard(
      tint: softTint,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildModeButton(InputMode.text, Icons.text_fields, 'Text', theme),
          _buildModeButton(InputMode.camera, Icons.camera_alt, 'Camera', theme),
          _buildModeButton(
            InputMode.gallery,
            Icons.photo_library,
            'Gallery',
            theme,
          ),
          _buildModeButton(InputMode.file, Icons.upload_file, 'File', theme),
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
    final softTint = _softTint(theme);

    return Expanded(
      child: isSelected
          ? SoftTileButton(
              icon: icon,
              label: label,
              height: 52,
              width: double.infinity,
              tint: softTint,
              onPressed: () => _selectInputMode(mode),
            )
          : OutlinedButton(
              onPressed: () => _selectInputMode(mode),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
        final softTint = _softTint(theme);
        return SoftTileCard(
          tint: softTint,
          child: Column(
            children: [
              // Input field
              SizedBox(
                height: 260,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText:
                        'Examples:\n• bought 2 litres of semi-skimmed milk and 3 loaves of bread\n• used 4 eggs baking cupcakes\n• have 5 apples left in the fruit bowl\n• finished the orange juice',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.2,
                      ),
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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(16),
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
                      SoftTileButton(
                        onPressed: _toggleListening,
                        height: 44,
                        width: 140,
                        icon: _isListening ? Icons.mic_off : Icons.mic_none,
                        label: _isListening ? 'Stop dictation' : 'Dictate',
                        tint: _softTint(theme),
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
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                message.isEmpty ? 'Listening idle' : message,
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
    if (_selectedFileBytes != null || (_selectedFileName ?? '').isNotEmpty) {
      return _buildImagePreview(theme);
    }

    final softTint = _softTint(theme);
    return SoftTileCard(
      tint: softTint,
      onTap: _handleImageSelection,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getPlaceholderIcon(),
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.3,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SoftTileButton(
            icon: _getActionIcon(),
            label: _getActionText(),
            width: 220,
            height: 48,
            tint: softTint,
            onPressed: _handleImageSelection,
          ),
          if (_inputMode == InputMode.file) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _downloadCsvTemplate,
              icon: const Icon(Icons.download),
              label: const Text('Download CSV template'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    final fileName = _selectedFileName ?? '';
    final isPreviewableImage = _isPreviewableImage(fileName);
    final softTint = _softTint(theme);
    return SoftTileCard(
      tint: softTint,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isPreviewableImage && _selectedFileBytes != null)
                    Image.memory(_selectedFileBytes!, fit: BoxFit.contain)
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.25),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getDocumentIcon(fileName),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isPreviewableImage
                    ? Icons.check_circle
                    : _getDocumentIcon(fileName),
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
        return 'PDF, image, CSV, or XLSX files supported';
      default:
        return '';
    }
  }

  Future<void> _downloadCsvTemplate() async {
    final headers = CsvService.defaultHeaders;
    final sampleRows = [
      [
        'semi-skimmed milk',
        '2',
        'litre',
        'dairy',
        'fridge',
        '1',
        '2025-12-31',
        'organic'
      ],
      [
        'brown rice',
        '1',
        'kg',
        'dry goods',
        'pantry',
        '0',
        '',
        'wholegrain'
      ],
    ];
    final csvContent =
        const ListToCsvConverter().convert([headers, ...sampleRows]);

    try {
      await saveTextFile(
        filename: 'grocery-template.csv',
        content: csvContent,
        mimeType: 'text/csv',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template CSV downloaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to download template: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _isPreviewableImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  IconData _getDocumentIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.csv')) return Icons.table_chart;
    if (lower.endsWith('.xlsx')) return Icons.grid_on;
    return Icons.description;
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

  void _scheduleAutoRefresh(GroceryListProvider provider) {
    // If there is no active ingestion job, cancel any pending refresh timer.
    if (provider.activeIngestionJob == null) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    // If we already scheduled a refresh for this job, skip.
    final currentJobId = provider.activeIngestionJob?.id;
    if (_refreshTimer != null && _lastInventoryRefreshJobId == currentJobId) {
      return;
    }

    // Schedule a single refresh to pull latest inventory in case tracking is
    // limited or delayed.
    _refreshTimer?.cancel();
    _lastInventoryRefreshJobId = currentJobId;
    _refreshTimer = Timer(const Duration(seconds: 12), () {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.loadInventory(refresh: true);
      inventoryProvider.loadStats();
    });
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
        _scheduleAutoRefresh(groceryProvider);
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
            if (groceryProvider.isUploading ||
                groceryProvider.activeUpload != null) ...[
              _buildUploadStatus(theme, groceryProvider),
              const SizedBox(height: 12),
            ],
            if (groceryProvider.activeIngestionJob != null) ...[
              _buildIngestionJobStatus(theme, groceryProvider),
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
              child: groceryProvider.isProcessing
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
                          groceryProvider.isUploading
                              ? 'Uploading...'
                              : 'Processing...',
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
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
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
              ...tips
                  .take(6)
                  .map(
                    (tip) => Padding(
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
                    ),
                  ),
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

  Color? _softTint(ThemeData theme) {
    // Let soft tiles use the shared lavender in dark mode; keep a light tint in light mode.
    if (theme.brightness == Brightness.dark) return null;
    return theme.colorScheme.primary.withValues(alpha: 0.12);
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
          const SnackBar(
            content: Text('Speech recognition unavailable on this device.'),
          ),
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
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
        ),
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
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );
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
      await _processPickedFile(bytes: bytes, fileName: fileName);
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
      await _processPickedFile(bytes: bytes, fileName: fileName);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'csv', 'xlsx'],
      withData: true,
    );

    if (result == null) return;

    final file = result.files.single;
    final resolvedFileName = _resolveFileName(
      // On web, accessing path throws; rely on provided name instead.
      path: kIsWeb ? null : file.path,
      name: file.name,
    );
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
      fileName: resolvedFileName,
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
    if (groceryProvider.isProcessing) return false;

    if (_inputMode == InputMode.text) {
      return _textController.text.trim().isNotEmpty;
    } else {
      return _selectedFileBytes != null || _imageBase64 != null;
    }
  }

  String _resolveFileName({String? path, String? name}) {
    if (name != null && name.isNotEmpty) return name;
    if (path == null || path.isEmpty) return 'receipt.png';
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return 'application/octet-stream';
  }

  String _inferUploadSourceType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.csv') || lower.endsWith('.xlsx')) {
      return 'text';
    }
    return 'image_receipt';
  }

  Future<void> _handleProcess() async {
    final groceryProvider = Provider.of<GroceryListProvider>(
      context,
      listen: false,
    );
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
        _interimTranscript = '';
      });
    }

    if (_inputMode == InputMode.text) {
      final text = _textController.text.trim();
      if (text.isEmpty) return;

      if (groceryProvider.supportsAsyncIngestion) {
        final started = await groceryProvider.submitIngestionJob(
          text: text,
          metadata: const {'source': 'text_input'},
        );
        if (started && mounted) {
          _textController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing your update in the background...'),
            ),
          );
        }
        return;
      }

      final success = await groceryProvider.parseGroceryText(text: text);
      if (success && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const ReviewScreen()));
      }
      return;
    }

    final bytes = _selectedFileBytes;
    if (bytes == null) return;

    if (groceryProvider.supportsUploadIngestion) {
      final fileName = _selectedFileName ?? 'receipt.png';
      final success = await groceryProvider.submitUploadForIngestion(
        bytes: bytes,
        filename: fileName,
        contentType: _inferContentType(fileName),
        sourceType: _inferUploadSourceType(fileName),
      );

      if (success && mounted) {
        _clearImage();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload queued for background processing...'),
          ),
        );
      }
      return;
    }

    if (_imageBase64 == null) return;

    final success = await groceryProvider.parseGroceryImage(
      imageBase64: _imageBase64!,
      imageType: 'receipt',
    );

    if (success && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const ReviewScreen()));
    }
  }

  Widget _buildIngestionJobStatus(
    ThemeData theme,
    GroceryListProvider provider,
  ) {
    final job = provider.activeIngestionJob!;
    final isProcessing = !job.isTerminal;
    final isSuccess = job.isComplete;
    final baseColor = isProcessing
        ? theme.colorScheme.surfaceContainerHighest
        : isSuccess
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = isProcessing
        ? theme.colorScheme.onSurfaceVariant
        : isSuccess
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;

    final title = isProcessing
        ? 'Applying your update...'
        : isSuccess
        ? 'Inventory updated automatically'
        : 'Background processing failed';

    String? message;
    if (isProcessing) {
      final snippet = job.text != null && job.text!.isNotEmpty
          ? '"${_truncate(job.text!, 80)}"'
          : null;
      message = snippet != null
          ? 'Hang tight while we process $snippet'
          : 'Hang tight while we process your update.';
      if (provider.ingestionTrackingLimited) {
        message =
            'Processing in the background. Updates may take a moment to appear.';
      }
    } else if (isSuccess) {
      message =
          job.resultSummary ??
          job.agentResponse ??
          'The AI agent applied your grocery updates.';
    } else {
      message = job.lastError ?? 'Please try again in a moment.';
    }

    final icon = isProcessing
        ? Icons.sync
        : isSuccess
        ? Icons.check_circle
        : Icons.error_outline;

    // Refresh inventory once per completed job so users see updates without
    // manual reloads.
    if (isSuccess &&
        job.id.isNotEmpty &&
        _lastInventoryRefreshJobId != job.id) {
      _lastInventoryRefreshJobId = job.id;
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.loadInventory(refresh: true);
      inventoryProvider.loadStats();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: onColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (job.isTerminal)
                TextButton(
                  onPressed: provider.dismissIngestionJobStatus,
                  style: TextButton.styleFrom(foregroundColor: onColor),
                  child: const Text('Dismiss'),
                ),
              if (provider.ingestionTrackingLimited && isProcessing)
                TextButton(
                  onPressed: () {
                    final inventoryProvider =
                        Provider.of<InventoryProvider>(context, listen: false);
                    inventoryProvider.loadInventory(refresh: true);
                    inventoryProvider.loadStats();
                  },
                  style: TextButton.styleFrom(foregroundColor: onColor),
                  child: const Text('Refresh now'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatus(ThemeData theme, GroceryListProvider provider) {
    final upload = provider.activeUpload;
    final isUploading = provider.isUploading;
    final status = upload?.status;

    if (!isUploading && upload == null) {
      return const SizedBox.shrink();
    }

    final bool isError = status == UploadStatus.failed;
    final bool isComplete = status == UploadStatus.completed;
    final baseColor = isUploading
        ? theme.colorScheme.surfaceContainerHighest
        : isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final onColor = isUploading
        ? theme.colorScheme.onSurfaceVariant
        : isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    String title;
    String message;
    IconData icon;

    if (isUploading) {
      final percent = (provider.uploadProgress * 100).clamp(0, 100).round();
      title = 'Uploading your file...';
      message = 'Sent $percent% of the receipt to the server.';
      icon = Icons.cloud_upload;
    } else if (status == UploadStatus.queued) {
      title = 'Queued for processing';
      message = 'Waiting for the AI parser to pick up your upload.';
      icon = Icons.schedule;
    } else if (status == UploadStatus.processing) {
      title = 'Processing upload...';
      message = upload?.processingStage != null
          ? 'Stage: ${upload!.processingStage}'
          : 'Preparing the ingestion job.';
      icon = Icons.sync;
    } else if (isError) {
      title = 'Upload failed';
      message = upload?.lastError ?? 'Please try again in a moment.';
      icon = Icons.error_outline;
    } else {
      title = 'Upload processed';
      final preview = upload?.textPreview;
      message = preview != null && preview.isNotEmpty
          ? 'Preview: ${_truncate(preview, 80)}'
          : 'Ingestion job starting shortly.';
      icon = Icons.check_circle;
    }

    final showDismiss =
        !isUploading &&
        (upload == null ||
            isError ||
            (isComplete && (provider.activeIngestionJob?.isTerminal ?? false)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: onColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showDismiss)
                TextButton(
                  onPressed: provider.dismissUploadStatus,
                  style: TextButton.styleFrom(foregroundColor: onColor),
                  child: const Text('Dismiss'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentMetricsCard(ThemeData theme) {
    final stream = _agentMetricsStream;
    if (stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<AgentMetrics?>(
      stream: stream,
      builder: (context, snapshot) {
        final metrics = snapshot.data;
        if (metrics == null) {
          return const SizedBox.shrink();
        }

        final successRate = (metrics.successRate * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);
        final fallbackRate = (metrics.fallbackRate * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);
        final latency = metrics.averageLatencyMs;
        final confidence = metrics.averageConfidence;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetricPill(
                      theme,
                      label: 'Runs',
                      value: metrics.totalCount.toString(),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      theme,
                      label: 'Success',
                      value: '$successRate%',
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      theme,
                      label: 'Fallback',
                      value: '$fallbackRate%',
                    ),
                  ],
                ),
                if (latency != null || confidence != null)
                  const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (latency != null)
                      Text(
                        'Avg latency: ${latency.toStringAsFixed(0)} ms',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (confidence != null)
                      Text(
                        'Avg confidence: ${confidence.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricPill(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars).trim()}...';
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
      final groceryProvider = Provider.of<GroceryListProvider>(
        context,
        listen: false,
      );
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

enum InputMode { text, camera, gallery, file }
