import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ComposePage extends StatefulWidget {
  final Future<void> Function(String, XFile?) onCreate;
  const ComposePage({super.key, required this.onCreate});
  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final picker = ImagePicker();
  final controller = TextEditingController();
  XFile? selectedImage;
  bool publishing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => selectedImage = image);
  }

  Future<void> _publish() async {
    final text = controller.text.trim();
    if (publishing || (text.isEmpty && selectedImage == null)) return;
    setState(() => publishing = true);
    try {
      await widget.onCreate(text, selectedImage);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('发一条'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: publishing ? null : _publish,
              child: Text(publishing ? '发布中…' : '发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: controller,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(hintText: '分享你的想法…'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(selectedImage == null ? '添加图片' : '更换图片'),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(selectedImage!.path),
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            '发布后会立即同步到发现页和我的页面。',
            style: TextStyle(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
