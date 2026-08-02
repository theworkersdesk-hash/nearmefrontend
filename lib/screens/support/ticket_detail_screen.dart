import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/support_ticket_model.dart';
import '../../providers/providers.dart';
import '../../services/api_exception.dart';
import '../../utils/ui_feedback.dart';
import 'support_common.dart';

/// Full thread for a single support request: messages, reply box (with image
/// attachments), and close / reopen actions.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();

  SupportThread? _thread;
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _uploading = false;
  final List<String> _pending = []; // uploaded attachment URLs for the next reply

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread =
          await ref.read(supportServiceProvider).detail(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _loading = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _attach() async {
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
      if (url != null) _pending.add(url);
    });
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    setState(() => _sending = true);
    final msg = await runWithFeedback(
      context,
      () => ref.read(supportServiceProvider).reply(
            ticketId: widget.ticketId,
            body: text.isEmpty ? '(no message)' : text,
            attachments: _pending,
          ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (msg != null) {
      _reply.clear();
      _pending.clear();
      await _load(); // refresh thread + status (a reply can reopen the ticket)
    }
  }

  Future<void> _changeStatus(SupportStatus status, String successMessage) async {
    final ok = await runWithFeedback(
      context,
      () => ref
          .read(supportServiceProvider)
          .setStatus(ticketId: widget.ticketId, status: status),
      successMessage: successMessage,
    );
    if (ok != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _thread?.ticket;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ticket?.subject ?? 'Request',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (ticket != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'close') {
                  _changeStatus(SupportStatus.closed, 'Request closed');
                } else if (v == 'reopen') {
                  _changeStatus(SupportStatus.open, 'Request reopened');
                }
              },
              itemBuilder: (_) => [
                if (!ticket.status.isClosed)
                  const PopupMenuItem(value: 'close', child: Text('Close request')),
                if (ticket.status.isClosed)
                  const PopupMenuItem(
                      value: 'reopen', child: Text('Reopen request')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorRetry(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (ticket != null) _StatusBanner(ticket: ticket),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          for (final m in _thread!.messages)
                            _MessageBubble(message: m),
                        ],
                      ),
                    ),
                    _ReplyBar(
                      controller: _reply,
                      pending: _pending,
                      uploading: _uploading,
                      sending: _sending,
                      isClosed: ticket?.status.isClosed ?? false,
                      onAttach: _attach,
                      onSend: _send,
                      onRemovePending: (u) => setState(() => _pending.remove(u)),
                    ),
                  ],
                ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.ticket});
  final SupportTicket ticket;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(ticket.category.label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedText)),
          const Spacer(),
          StatusChip(status: ticket.status),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = mine ? AppColors.primary : AppColors.surface;
    final fg = mine ? AppColors.onPrimary : AppColors.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (message.isFromSupport)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text('Support',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.body.isNotEmpty && message.body != '(no message)')
                  Text(message.body, style: TextStyle(color: fg)),
                if (message.attachments.isNotEmpty) ...[
                  if (message.body.isNotEmpty && message.body != '(no message)')
                    const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in message.attachments)
                        GestureDetector(
                          onTap: () => _openImage(context, a),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: a,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 150,
                                  height: 150,
                                  color: AppColors.tertiary),
                              errorWidget: (_, __, ___) => Container(
                                  width: 150,
                                  height: 150,
                                  color: AppColors.tertiary,
                                  child: const Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(timeAgo(message.createdAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.pending,
    required this.uploading,
    required this.sending,
    required this.isClosed,
    required this.onAttach,
    required this.onSend,
    required this.onRemovePending,
  });
  final TextEditingController controller;
  final List<String> pending;
  final bool uploading;
  final bool sending;
  final bool isClosed;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final void Function(String url) onRemovePending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isClosed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('This request is closed — replying will reopen it.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedText)),
              ),
            if (pending.isNotEmpty || uploading)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final u in pending)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                  imageUrl: u,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => onRemovePending(u),
                                child: Container(
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (uploading)
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                              color: AppColors.tertiary,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Center(
                              child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: uploading ? null : onAttach,
                  icon: const Icon(Icons.attach_file,
                      color: AppColors.primary),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a reply…',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppShapes.pill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.disabled),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
