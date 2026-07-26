import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:furtail_app/features/fundraising/data/models/fundraising_models.dart';
import 'package:furtail_app/services/api_client.dart';

class FundraisingDocumentPreviewScreen extends ConsumerStatefulWidget {
  const FundraisingDocumentPreviewScreen({super.key, required this.document});

  final FundraisingAccountDocument document;

  @override
  ConsumerState<FundraisingDocumentPreviewScreen> createState() =>
      _FundraisingDocumentPreviewScreenState();
}

class _FundraisingDocumentPreviewScreenState
    extends ConsumerState<FundraisingDocumentPreviewScreen> {
  Future<void>? _loadTask;
  Uint8List? _bytes;
  PdfControllerPinch? _pdfController;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  bool get _isPdf {
    final mediaType = (widget.document.mediaType ?? '').toUpperCase();
    final file = widget.document.safeFileName.toLowerCase();
    return mediaType.contains('PDF') || file.endsWith('.pdf');
  }

  bool get _isImage {
    final mediaType = (widget.document.mediaType ?? '').toUpperCase();
    final file = widget.document.safeFileName.toLowerCase();
    return mediaType.contains('IMAGE') ||
        file.endsWith('.png') ||
        file.endsWith('.jpg') ||
        file.endsWith('.jpeg') ||
        file.endsWith('.webp');
  }

  Future<void> _startLoad() async {
    if (_loadTask != null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _loadTask = _loadDocument();
    await _loadTask;
    _loadTask = null;
  }

  Future<void> _loadDocument() async {
    final url = (widget.document.mediaUrl ?? '').trim();
    if (url.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'This document is unavailable.';
      });
      return;
    }

    try {
      final client = ref.read(apiClientProvider);
      final binary = await client.getBinary(url, auth: true);
      final bytes = binary.bytes;

      if (bytes.isEmpty) {
        throw const FormatException('empty file');
      }

      if (_looksLikePdf(bytes, binary.contentType, widget.document)) {
        final doc = await PdfDocument.openData(bytes);
        _pdfController?.dispose();
        _pdfController = PdfControllerPinch(document: Future.value(doc));
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _loading = false;
          _errorMessage = null;
        });
        return;
      }

      if (_looksLikeImage(bytes, binary.contentType, widget.document)) {
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _loading = false;
          _errorMessage = null;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'This file type is not previewed in-app.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to preview this document right now.';
      });
    }
  }

  bool _looksLikePdf(
    Uint8List bytes,
    String? contentType,
    FundraisingAccountDocument document,
  ) {
    final type = (contentType ?? document.mediaType ?? '').toLowerCase();
    if (type.contains('pdf')) return true;
    if (bytes.length >= 4) {
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }
    return false;
  }

  bool _looksLikeImage(
    Uint8List bytes,
    String? contentType,
    FundraisingAccountDocument document,
  ) {
    final type = (contentType ?? document.mediaType ?? '').toLowerCase();
    if (type.startsWith('image/')) return true;
    if (bytes.length < 4) return false;
    final png =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final webp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return png || jpeg || webp;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.document.title;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            onPressed: () async {
              final uri = Uri.tryParse(widget.document.mediaUrl ?? '');
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            : _errorMessage != null
            ? _PreviewError(message: _errorMessage!, onRetry: _startLoad)
            : _isPdf
            ? _PdfPreview(controller: _pdfController!)
            : _isImage
            ? _ImagePreview(bytes: _bytes!, title: title)
            : _bytes == null
            ? _PreviewError(
                message: 'This document is unavailable.',
                onRetry: _startLoad,
              )
            : _PreviewError(
                message: 'This file type is not previewed in-app.',
                onRetry: _startLoad,
              ),
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.controller});

  final PdfControllerPinch controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PdfViewPinch(
            controller: controller,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorBuilder: (_, _) => _PreviewError(
                message: 'This PDF could not be displayed. Please try opening it externally.',
                onRetry: () async {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Image.memory(bytes, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async => onRetry(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
