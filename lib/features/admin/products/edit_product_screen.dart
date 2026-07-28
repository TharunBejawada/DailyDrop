// lib/features/admin/products/edit_product_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import 'admin_product_service.dart';
import 'scan/image_upload_service.dart';
import 'scan/product_scanner_service.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final List<Category> categories;
  final Product? existing; // null = creating a new product

  const EditProductScreen({super.key, required this.categories, this.existing});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;
  String? _categoryId;
  String _productType = 'grocery';
  bool _saving = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toString() : '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _categoryId =
        p?.categoryId ?? (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _productType = p?.productType ?? 'grocery';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _scanProduct() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    setState(() => _scanning = true);
    try {
      // Run OCR/image-labeling and the photo upload in parallel — both need
      // the picked image but don't depend on each other's result.
      final scanFuture = ProductScannerService().scan(picked.path);
      final bytes = await picked.readAsBytes();
      final uploadFuture =
          ref.read(imageUploadServiceProvider).uploadProductImage(bytes, picked.name);

      final results = await Future.wait([scanFuture, uploadFuture]);
      final scanResult = results[0] as ScanResult;
      final imageUrl = results[1] as String;

      setState(() {
        _imageUrlController.text = imageUrl;
        if (scanResult.suggestedName != null) {
          _nameController.text = scanResult.suggestedName!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scanResult.suggestedName != null
                  ? 'Suggested name from ${scanResult.source} — review before saving'
                  : "Photo saved, but couldn't recognize a name automatically — please type it in",
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);

    final service = ref.read(adminProductServiceProvider);
    try {
      if (widget.existing == null) {
        await service.createProduct(
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          categoryId: _categoryId!,
          productType: _productType,
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
        );
      } else {
        await service.updateProduct(
          productId: widget.existing!.id,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          categoryId: _categoryId!,
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isNew = widget.existing == null;
    final categoriesForType =
        widget.categories.where((c) => c.productType == _productType).toList();
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Add product' : 'Edit product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, AppSpacing.xxl),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ImagePreview(url: _imageUrlController.text),
                  // ML Kit is Android/iOS only — hide the scan button on web
                  // rather than showing a button that would just fail there.
                  if (!kIsWeb) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _scanning ? null : _scanProduct,
                      icon: _scanning
                          ? const SizedBox(
                              height: AppIconSize.sm,
                              width: AppIconSize.sm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined,
                              size: AppIconSize.md),
                      label: Text(_scanning
                          ? 'Scanning…'
                          : 'Scan product with camera'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Reads the label or recognises fresh produce, then fills in '
                      'the name and photo for you.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: semantic.mutedText),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (isNew) ...[
                    Text('Product type', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'grocery',
                          icon: Icon(Icons.shopping_basket_outlined,
                              size: AppIconSize.md),
                          label: Text('Grocery'),
                        ),
                        ButtonSegment(
                          value: 'fruit_veg',
                          icon: Icon(Icons.eco_outlined, size: AppIconSize.md),
                          label: Text('Fruits & Veg'),
                        ),
                      ],
                      selected: {_productType},
                      onSelectionChanged: (s) => setState(() {
                        _productType = s.first;
                        final firstOfType = widget.categories
                            .where((c) => c.productType == _productType)
                            .toList();
                        _categoryId =
                            firstOfType.isNotEmpty ? firstOfType.first.id : null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined, size: AppIconSize.md),
                    ),
                    items: categoriesForType
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Pick a category' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      helperText: 'Scan will suggest this — edit freely',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      helperText: 'e.g. kg, piece, pack of 5',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '₹ ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) return 'Enter a valid number';
                      if (parsed <= 0) return 'Price must be more than zero';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      helperText: 'Filled in automatically by the scan, or paste one',
                      prefixIcon: Icon(Icons.link, size: AppIconSize.md),
                    ),
                    onChanged: (_) => setState(() {}), // refresh the preview
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _saving
                  ? SizedBox(
                      height: AppIconSize.md,
                      width: AppIconSize.md,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text(isNew ? 'Add product' : 'Save changes'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 16:9 image preview that doubles as the empty-state prompt, so the layout
/// height never changes when a photo arrives.
class _ImagePreview extends StatelessWidget {
  final String url;
  const _ImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: AppIconSize.xl, color: semantic.mutedText),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No photo yet',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: semantic.mutedText),
                    ),
                  ],
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: AppIconSize.xl, color: semantic.mutedText),
                  ),
                ),
              ),
      ),
    );
  }
}
