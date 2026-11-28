import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/template.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';
import '../drawing/drawing_screen.dart';

/// Screen for managing and browsing templates.
class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  String _selectedCategory = TemplateCategory.all;
  String _searchQuery = '';
  bool _showCustomOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateTemplateDialog,
            tooltip: 'Create Template',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          _buildCategoryFilter(),
          // Search bar
          _buildSearchBar(),
          // Template list
          Expanded(
            child: _buildTemplateList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              avatar: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search templates...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTemplateList() {
    return Consumer<NotesProvider>(
      builder: (context, provider, child) {
        final templates = provider.templates
            .where((t) {
              final matchesCategory = _selectedCategory == TemplateCategory.all ||
                  t.category == _selectedCategory;
              final matchesSearch = _searchQuery.isEmpty ||
                  t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  t.contentJson.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesCustom = !_showCustomOnly || t.isCustom;
              return matchesCategory && matchesSearch && matchesCustom;
            })
            .toList();

        if (templates.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return _buildTemplateCard(template);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
            'No templates found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != TemplateCategory.all
                ? 'Try adjusting your filters'
                : 'Create your first template!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isEmpty && _selectedCategory == TemplateCategory.all)
            FilledButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Template template) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _useTemplate(template),
        onLongPress: () => _showTemplateOptions(template),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: template.thumbnail.isNotEmpty
                    ? Image.memory(
                        template.thumbnail.codeUnits
                            .map((e) => e.toUnsigned(8))
                            .toList(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultThumbnail(),
                      )
                    : _buildDefaultThumbnail(),
                child: Stack(
                  children: [
                    if (template.isCustom)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Custom',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    if (!template.isCustom)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Built-in',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          TemplateCategory.getIcon(template.category),
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            TemplateCategory.getDisplayName(template.category),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (template.isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Custom',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPreviewText(template.contentJson),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          template.isCustom ? 'Custom' : 'Built-in',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(template.updatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Icon(
      Icons.description_outlined,
      size: 48,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  String _getPreviewText(String contentJson) {
    try {
      // Try to extract text from JSON
      if (contentJson.startsWith('{')) {
        // Simple extraction - in real app use proper JSON parsing
        final bodyMatch = RegExp(r'"body"\s*:\s*"([^"]*)"').firstMatch(contentJson);
        if (bodyMatch != null) return bodyMatch.group(1) ?? '';
      }
      return contentJson.length > 100
          ? '${contentJson.substring(0, 100)}...'
          : contentJson;
    } catch (_) {
      return 'Template content';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _useTemplate(Template template) {
    Navigator.of(context).pop(template);
    // Navigate to drawing editor with template
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrawingNoteScreen(template: template),
      ),
    );
  }

  void _showTemplateOptions(Template template) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Use Template'),
              onTap: () {
                Navigator.pop(context);
                _useTemplate(template);
              },
            ),
            if (template.isCustom) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Template'),
                onTap: () {
                  Navigator.pop(context);
                  _editTemplate(template);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(template);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicateTemplate(template);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export to PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportTemplateToPdf(template);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportTemplateToPdf(Template template) async {
    try {
      final pdfBytes = await ExportService.exportTemplateToPdf(template);
      final fileName = '${template.name.replaceAll(RegExp(r'[^\w]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await ExportService.saveAndSharePdf(pdfBytes, fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template exported to PDF: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: $e')),
        );
      }
    }
  }

  void _editTemplate(Template template) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _EditTemplateDialog(
        template: template,
        onSaved: (updatedTemplate) {
          context.read<NotesProvider>().updateTemplate(updatedTemplate);
        },
      ),
    );
  }

  void _confirmDelete(Template template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotesProvider>().deleteTemplate(template.id!);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateTemplate(Template template) {
    final duplicate = template.copyWith(
      name: '${template.name} (Copy)',
      isCustom: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    context.read<NotesProvider>().addTemplate(duplicate);
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    String selectedCategory = TemplateCategory.meeting;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'My Meeting Template',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: TemplateCategory.allCategories
                  .where((c) => c != TemplateCategory.all)
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(TemplateCategory.getIcon(cat), size: 18),
                            const SizedBox(width: 8),
                            Text(TemplateCategory.getDisplayName(cat)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              final template = Template(
                name: nameController.text.trim(),
                category: selectedCategory,
                isCustom: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              context.read<NotesProvider>().addTemplate(template);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing an existing template.
class _EditTemplateDialog extends StatefulWidget {
  const _EditTemplateDialog({
    required this.template,
    required this.onSaved,
  });

  final Template template;
  final Function(Template) onSaved;

  @override
  State<_EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<_EditTemplateDialog> {
  final _nameController = TextEditingController();
  late String _selectedCategory;
  String? _thumbnailBase64;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.template.name;
    _selectedCategory = widget.template.category;
    _thumbnailBase64 = widget.template.thumbnail.isNotEmpty ? widget.template.thumbnail : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Template'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'Template name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: TemplateCategory.allCategories
                  .where((c) => c != TemplateCategory.all)
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(TemplateCategory.getIcon(cat), size: 18),
                            const SizedBox(width: 8),
                            Text(TemplateCategory.getDisplayName(cat)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            // Thumbnail
            if (_thumbnailBase64 != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thumbnail', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _thumbnailBase64!.startsWith('data:')
                            ? Image.memory(
                                base64Decode(_thumbnailBase64!.split(',').last),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 100,
                              )
                            : Image.memory(
                                base64Decode(_thumbnailBase64!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 100,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _thumbnailBase64 = null);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove Thumbnail'),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Change Thumbnail'),
              subtitle: Text(
                _thumbnailBase64 != null ? 'Replace thumbnail' : 'Add thumbnail',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickThumbnail,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            final updated = widget.template.copyWith(
              name: _nameController.text.trim(),
              category: _selectedCategory,
              thumbnail: _thumbnailBase64 ?? '',
              updatedAt: DateTime.now(),
            );
            widget.onSaved(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickThumbnail() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 300,
      imageQuality: 80,
    );
    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      setState(() {
        _thumbnailBase64 = base64Encode(bytes);
      });
    }
  }
}