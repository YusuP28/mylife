import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/drawing_stroke.dart';
import '../models/note.dart';
import '../models/template.dart';
import '../providers/notes_provider.dart';
import '../services/feature_flags.dart';
import 'drawing_canvas.dart';

/// Full-screen drawing/note editor screen with rich text and drawing support.
class DrawingNoteScreen extends StatefulWidget {
  const DrawingNoteScreen({
    super.key,
    this.note,
    this.template,
  });

  final Note? note;
  final Template? template;

  @override
  State<DrawingNoteScreen> createState() => _DrawingNoteScreenState();
}

class _DrawingNoteScreenState extends State<DrawingNoteScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _templateUriController;
  late final QuillController _quillController;
  final GlobalKey _drawingCanvasKey = GlobalKey();

  bool _saving = false;
  bool _showDrawing = true;
  bool _showToolbar = true;
  Color _currentColor = Colors.black;
  double _currentWidth = 2.0;
  bool _isEraserMode = false;
  List<DrawingStroke> _strokes = [];
  String? _fontFamily;
  String? _backgroundId;
  String? _templateId;

  // Feature flags
  final FontManager _fontManager = FontManager();
  final BackgroundManager _backgroundManager = BackgroundManager();
  bool _fontManagerInitialized = false;
  bool _backgroundManagerInitialized = false;

  // Fonts
  List<String> _availableFonts = [];

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    final template = widget.template;

    _titleController = TextEditingController(text: note?.title ?? template?.name ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _quillController = QuillController(
      document: Document.fromJson(_parseQuillDelta(note?.body ?? '')),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _strokes = List.from(note?.strokes ?? []);
    _fontFamily = note?.fontFamily;
    _backgroundId = note?.backgroundId;
    _templateId = note?.templateId ?? template?.id?.toString();

    _initFeatureFlags();

    if (template != null) {
      _loadTemplateContent(template);
    }
  }

  Future<void> _initFeatureFlags() async {
    await _fontManager.init();
    await _backgroundManager.init();
    setState(() {
      _fontManagerInitialized = true;
      _backgroundManagerInitialized = true;
      _fontFamily ??= _fontManager.currentFontFamily;
      _backgroundId ??= _backgroundManager.currentBackgroundId;
      _availableFonts = FontManager.availableFonts;
    });
  }

  void _loadTemplateContent(Template template) {
    _templateId = template.id?.toString();
    // Parse template contentJson
    try {
      final content = json.decode(template.contentJson);
      if (content['body'] != null) {
        _bodyController.text = content['body'] as String? ?? '';
      }
      if (content['strokes'] != null) {
        final strokesData = content['strokes'] as List?;
        if (strokesData != null) {
          _strokes = strokesData.map((s) => DrawingStroke.fromMap(s as Map<String, dynamic>)).toList();
        }
      }
      if (content['fontFamily'] != null) {
        _fontFamily = content['fontFamily'] as String?;
      }
      if (content['backgroundId'] != null) {
        _backgroundId = content['backgroundId'] as String?;
      }
      if (content['title'] != null) {
        _titleController.text = content['title'] as String? ?? '';
      }
      if (content['quillDelta'] != null) {
        final delta = content['quillDelta'] as List?;
        if (delta != null) {
          _quillController.document = Document.fromJson(delta);
        }
      }
    } catch (_) {
      // Ignore parse errors
    }
    _templateId = template.id?.toString();
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  // Parse plain text to Quill Delta format
  List<Map<String, dynamic>> _parseQuillDelta(String text) {
    if (text.isEmpty) return [];
    return [
      {'insert': text}
    ];
  }

  // Serialize Quill document to JSON string
  String _serializeQuillDocument() {
    return json.encode(_quillController.document.toDelta().toJson());
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong')),
      );
      return;
    }

    // Save body from Quill editor
    _bodyController.text = _serializeQuillDocument();

    setState(() => _saving = true);
    try {
      final provider = context.read<NotesProvider>();
      final now = DateTime.now();

      if (widget.note == null) {
        // Create new note
        await context.read<NotesProvider>().addNote(
          title: _titleController.text.trim(),
          body: _bodyController.text,
          strokes: _strokes,
          templateId: _templateId,
          fontFamily: _fontFamily,
          backgroundId: _backgroundId,
        );
      } else {
        // Update existing note
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text.trim(),
          body: _bodyController.text,
          updatedAt: DateTime.now(),
          strokes: _strokes,
          templateId: _templateId,
          fontFamily: _fontFamily,
          backgroundId: _backgroundId,
        );
        await context.read<NotesProvider>().updateNote(
          widget.note!.copyWith(
            title: _titleController.text.trim(),
            body: _bodyController.text,
            updatedAt: DateTime.now(),
            strokes: _strokes,
            templateId: _templateId,
            fontFamily: _fontFamily,
            backgroundId: _backgroundId,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onColorChanged(Color color) {
    setState(() {
      _currentColor = color;
      _isEraserMode = false;
    });
  }

  void _onWidthChanged(double width) {
    setState(() => _currentWidth = width);
  }

  void _onEraserToggled() {
    setState(() {
      _isEraserMode = !_isEraserMode;
    });
  }

  void _onUndo() {
    final canvas = _drawingCanvasKey.currentState as dynamic;
    canvas?.undo();
  }

  void _onRedo() {
    final canvas = _drawingCanvasKey.currentState as dynamic;
    canvas?.redo();
  }

  void _onClear() {
    final canvas = _drawingCanvasKey.currentState as dynamic;
    canvas?.clear();
  }

  Future<void> _pickFont() async {
    if (!_fontManagerInitialized) return;
    
    final fontFamily = await showDialog<String>(
      context: context,
      builder: (context) => _FontPickerDialog(
        availableFonts: _availableFonts,
        currentFont: _fontFamily,
        onFontSelected: (font) async {
          await _fontManager.setFontFamily(font);
          setState(() => _fontFamily = font);
        },
      ),
    );
    
    if (fontFamily != null) {
      setState(() => _fontFamily = fontFamily);
    }
  }

  Future<void> _pickBackground() async {
    final backgroundId = await showDialog<String>(
      context: context,
      builder: (context) => _BackgroundPickerDialog(
        currentBackgroundId: _backgroundId,
        backgroundManager: _backgroundManager,
        onBackgroundSelected: (id) async {
          await _backgroundManager.setBackgroundId(id);
          setState(() => _backgroundId = id);
        },
      ),
    );
    
    if (backgroundId != null) {
      setState(() => _backgroundId = backgroundId);
    }
  }

  Future<void> _pickTemplate() async {
    final template = await Navigator.push<Template>(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateScreen(),
      ),
    );
    
    if (template != null && mounted) {
      _loadTemplateContent(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = context.read<VaultLockProvider>().isUnlocked == false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          IconButton(
            onPressed: (_saving || locked) ? null : _save,
            tooltip: 'Simpan',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showToolbar)
              _buildToolbar(),
            Expanded(
              child: Row(
                children: [
                  // Main editor area
                  Expanded(
                    flex: 3,
                    child: _buildEditorArea(),
                  ),
                  // Sidebar for tools/templates
                  if (_showDrawing)
                    SizedBox(
                      width: 280,
                      child: _buildSidebar(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Title field
          Expanded(
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul *',
                border: InputBorder.none,
                hintText: 'Masukkan judul...',
              ),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 16),
          // Drawing toggle
          IconButton(
            icon: Icon(
              _showDrawing ? Icons.edit : Icons.text_fields,
              color: _showDrawing ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _showDrawing = !_showDrawing),
            tooltip: _showDrawing ? 'Sembunyikan Gambar' : 'Tampilkan Gambar',
          ),
          IconButton(
            icon: Icon(
              _showToolbar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onPressed: () => setState(() => _showToolbar = !_showToolbar),
            tooltip: _showToolbar ? 'Sembunyikan Toolbar' : 'Tampilkan Toolbar',
          ),
        ],
      );
  }

  Widget _buildEditorArea() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Rich text editor area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rich text editor
                  Expanded(
                    child: _buildRichTextEditor(),
                  ),
                ],
              ),
            ),
          ),
          if (_showDrawing) ...[
            const Divider(height: 1),
            // Drawing canvas area
            Expanded(
              flex: 2,
              child: _buildDrawingArea(),
            ),
          ],
        ],
      );
    }

    Widget _buildRichTextEditor() {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Quill toolbar
            QuillSimpleToolbar(
              controller: _quillController,
              config: QuillSimpleToolbarConfig(
                showFontFamily: true,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showInlineCode: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showClearFormatButton: true,
                showAlignmentButtons: true,
                showHeaderStyleButton: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: true,
                showCodeBlock: true,
                showQuote: true,
                showIndent: true,
                showLink: true,
                showImageButton: true,
                showVideoButton: false,
                showUndo: true,
                showRedo: true,
                showDirection: true,
                showSearchButton: true,
                showClearFormatButton: true,
                multiRowsDisplay: false,
                showClipboardCut: true,
                showClipboardCopy: true,
                showClipboardPaste: true,
                showSubscript: true,
                showSuperscript: true,
                showInlineCode: true,
                showHeaderStyle: true,
                showListCheck: true,
                showBackgroundColorButton: true,
                showStrikeThrough: true,
                showListNumbers: true,
                showListBullets: true,
                showHeaderStyle: true,
                showAlignmentButtons: true,
                showDirection: true,
                showScriptButton: true,
                showCheckList: true,
                showCodeBlock: true,
                showQuote: true,
                showIndent: true,
                showLink: true,
                showImageButton: true,
                showVideoButton: false,
                showUndo: true,
                showRedo: true,
                showDirection: true,
                showSearchButton: true,
                showClearFormatButton: true,
                multiRowsDisplay: false,
                showClipboardCut: true,
                showClipboardCopy: true,
                showClipboardPaste: true,
                showSubscript: true,
                showSuperscript: true,
                showInlineCode: true,
                showHeaderStyle: true,
                showListCheck: true,
                showCodeBlock: true,
                showQuote: true,
                showIndent: true,
                showLink: true,
                showImageButton: true,
                showVideoButton: false,
                showUndo: true,
                showRedo: true,
                showDirection: true,
                showSearchButton: true,
                showClearFormatButton: true,
              ),
            ),
            // Quill Editor
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: QuillEditor.basic(
                  controller: _quillController,
                  config: QuillEditorConfig(
                    placeholder: 'Mulai mengetik...',
                    autoFocus: false,
                    expands: true,
                    padding: EdgeInsets.zero,
                    scrollable: true,
                    autoFocus: false,
                    readOnly: false,
                    placeholder: 'Mulai mengetik...',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildDrawingArea() {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          children: [
            // Drawing toolbar
            _buildDrawingToolbar(),
            // Drawing canvas
            Expanded(
              child: DrawingCanvas(
                key: _drawingCanvasKey,
                initialStrokes: _strokes,
                onStrokesChanged: (strokes) {
                  setState(() => _strokes = strokes);
                },
                defaultColor: _currentColor,
                defaultWidth: _currentWidth,
                showGrid: false,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDrawingToolbar() {
      final theme = Theme.of(context);
      final canvas = _drawingCanvasKey.currentState as dynamic;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Undo/Redo
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: canvas?.undo,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: canvas?.redo,
              tooltip: 'Redo',
            ),
            const SizedBox(width: 16),

            // Clear
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: canvas?.clear,
              tooltip: 'Clear canvas',
            ),
            const SizedBox(width: 16),

            // Eraser toggle
            IconButton(
              icon: Icon(
                Icons.format_color_reset,
                color: canvas?.isEraserMode == true ? theme.colorScheme.primary : null,
              ),
              onPressed: () {
                setState(() {
                  canvas?.isEraserMode = !(canvas?.isEraserMode ?? false);
                });
              },
              tooltip: 'Eraser',
            ),
            const SizedBox(width: 16),

            // Color picker
            DropdownButton<Color>(
              value: (canvas?.isEraserMode ?? false) ? Colors.transparent : _currentColor,
              underline: const SizedBox(),
              items: [
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.brown,
                Colors.grey,
              ].map((color) {
                return DropdownMenuItem<Color>(
                  value: color,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (color) {
                if (color != null) {
                  canvas?.currentColor = color;
                  setState(() {
                    _currentColor = color;
                    _isEraserMode = false;
                  });
                }
              },
            ),
            const SizedBox(width: 16),

            // Width slider
            SizedBox(
              width: 100,
              child: Slider(
                value: _currentWidth,
                min: 0.5,
                max: 20.0,
                divisions: 39,
                label: _currentWidth.toStringAsFixed(1),
                onChanged: (value) => setState(() => _currentWidth = value),
              ),
            ),
            const SizedBox(width: 16),

            // Clear button
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: canvas?.clear,
              tooltip: 'Clear canvas',
            ),
          ],
        );
      },
    }

    Widget _buildSidebar() {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          children: [
            // Template selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Templates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  // Template list would go here
                  ElevatedButton.icon(
                    onPressed: _pickTemplate,
                    icon: const Icon(Icons.add),
                    label: const Text('Load Template'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Font/Background settings
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Style',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.font_download),
                    title: const Text('Font'),
                    subtitle: Text(_fontFamily ?? 'Default'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickFont,
                  ),
                  ListTile(
                    leading: const Icon(Icons.wallpaper),
                    title: const Text('Background'),
                    subtitle: Text(_backgroundId ?? 'Default'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickBackground,
                  ),
                  ListTile(
                    leading: const Icon(Icons.template),
                    title: const Text('Template'),
                    subtitle: Text(_templateId != null ? 'Loaded' : 'None'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickTemplate,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Font Picker Dialog
class _FontPickerDialog extends StatefulWidget {
  const _FontPickerDialog({
    required this.availableFonts,
    required this.currentFont,
    required this.onFontSelected,
  });

  final List<String> availableFonts;
  final String? currentFont;
  final Function(String) onFontSelected;

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredFonts = widget.availableFonts
        .where((font) => font.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Pilih Font'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cari font...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filteredFonts.length,
                itemBuilder: (context, index) {
                  final font = filteredFonts[index];
                  final isSelected = font == widget.currentFont;
                  return ListTile(
                    title: Text(
                      font,
                      style: GoogleFonts.getFont(
                        font == 'Default (System)' ? 'Roboto' : font,
                        fontSize: 16,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => widget.onFontSelected(font),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

/// Background Picker Dialog
class _BackgroundPickerDialog extends StatefulWidget {
  const _BackgroundPickerDialog({
    required this.currentBackgroundId,
    required this.backgroundManager,
    required this.onBackgroundSelected,
  });

  final String? currentBackgroundId;
  final BackgroundManager backgroundManager;
  final Function(String) onBackgroundSelected;

  @override
  State<_BackgroundPickerDialog> createState() => _BackgroundPickerDialogState();
}

class _BackgroundPickerDialogState extends State<_BackgroundPickerDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Background'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            // Built-in backgrounds
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: BackgroundManager.builtInBackgrounds.length,
                itemBuilder: (context, index) {
                  final bg = BackgroundManager.builtInBackgrounds[index];
                  final isSelected = bg.id == widget.currentBackgroundId;
                  return InkWell(
                    onTap: () => widget.onBackgroundSelected(bg.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getPatternIcon(bg.pattern),
                            size: 48,
                            color: Colors.black54,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bg.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Custom background option
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Gambar Custom'),
              subtitle: Text(
                widget.currentBackgroundId != null &&
                        !BackgroundManager.builtInBackgrounds
                            .any((b) => b.id == widget.currentBackgroundId)
                    ? 'Gambar custom aktif'
                    : 'Pilih gambar dari galeri',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (image != null && mounted) {
                  final bytes = await image.readAsBytes();
                  final base64Image = base64Encode(bytes);
                  await _backgroundManager.setCustomBackgroundImage(base64Image);
                  await _backgroundManager.setBackgroundId('custom_image');
                  setState(() {
                    _backgroundId = 'custom_image';
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      );
    }

    IconData _getPatternIcon(BackgroundPattern pattern) {
      switch (pattern) {
        case BackgroundPattern.grid:
          return Icons.grid_on;
        case BackgroundPattern.dots:
          return Icons.circle;
        case BackgroundPattern.lines:
          return Icons.linear_scale;
        case BackgroundPattern.crosshatch:
          return Icons.grid_3x3;
        case BackgroundPattern.none:
        default:
          return Icons.format_color_fill;
      }
    }
  }
}

/// Template Loading Dialog
class _TemplatePickerDialog extends StatefulWidget {
  const _TemplatePickerDialog();

  @override
  State<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends State<_TemplatePickerDialog> {
  String _selectedCategory = TemplateCategory.all;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Template'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            // Category filter
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: TemplateCategory.allCategories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TemplateCategory.getIcon(category),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(TemplateCategory.getDisplayName(category)),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Search
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cari template...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            // Template list
            Expanded(
              child: Consumer<NotesProvider>(
                builder: (context, provider, child) {
                  final templates = provider.templates
                      .where((t) {
                        final matchesCategory = _selectedCategory == TemplateCategory.all ||
                            t.category == _selectedCategory;
                        final matchesSearch = _searchQuery.isEmpty ||
                            t.name.toLowerCase().contains(_searchQuery.toLowerCase());
                        return matchesCategory && matchesSearch;
                      })
                      .toList();

                  if (templates.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada template',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        leading: Icon(
                          TemplateCategory.getIcon(template.category),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(template.name),
                        subtitle: Text(
                          template.isCustom ? 'Custom' : 'Built-in',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => Navigator.pop(context, template),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      );
    }
  }
}