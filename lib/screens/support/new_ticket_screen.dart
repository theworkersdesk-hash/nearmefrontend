import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/support_ticket_model.dart';
import '../../providers/providers.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/vibe_button.dart';
import '../../widgets/common/vibe_text_field.dart';

/// Create a new support request. Pops with `true` when a ticket was created.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  SupportCategory _category = SupportCategory.account;
  final List<String> _attachments = []; // uploaded R2 URLs
  bool _uploading = false;
  bool _submitting = false;

  static const _maxAttachments = 3;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= _maxAttachments) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final path = await ref.read(imageServiceProvider).pickRaw(source: source);
    if (path == null || !mounted) return;

    setState(() => _uploading = true);
    final url = await runWithFeedback(
      context,
      () => ref.read(supportServiceProvider).uploadAttachment(path),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _attachments.add(url);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ticket = await runWithFeedback(
      context,
      () => ref.read(supportServiceProvider).create(
            category: _category,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            attachments: _attachments,
          ),
      successMessage: 'Request submitted',
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ticket != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Request')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Category',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              DropdownButtonFormField<SupportCategory>(
                initialValue: _category,
                isExpanded: true,
                items: SupportCategory.values
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),
              VibeTextField(
                label: 'Subject',
                controller: _subject,
                hint: 'Short summary',
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Please enter a subject (3+ chars)'
                    : null,
              ),
              const SizedBox(height: 16),
              VibeTextField(
                label: 'Describe your issue',
                controller: _body,
                hint: 'Tell us what happened…',
                maxLines: 6,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Please add a few more details (10+ chars)'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Attachments (optional)',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _AttachmentRow(
                urls: _attachments,
                uploading: _uploading,
                canAdd: _attachments.length < _maxAttachments,
                onAdd: _pickAttachment,
                onRemove: (u) => setState(() => _attachments.remove(u)),
              ),
              const SizedBox(height: 28),
              VibeButton(
                label: 'Submit Request',
                trailingIcon: Icons.send,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.urls,
    required this.uploading,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> urls;
  final bool uploading;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(String url) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final u in urls)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: u,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      width: 72, height: 72, color: AppColors.tertiary),
                  errorWidget: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.tertiary,
                      child: const Icon(Icons.broken_image, size: 20)),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: () => onRemove(u),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (uploading)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.tertiary,
                borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (canAdd)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}
