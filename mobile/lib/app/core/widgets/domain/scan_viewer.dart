import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/attachment.dart';
import '../../constants/app_sizes.dart';
import '../../extensions/context_ext.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';

/// An attachment together with where its bytes are on this device. Resolved
/// once by the controller, because the folder lookup is async and a widget
/// building a thumbnail cannot wait on it.
typedef ScanFile = ({Attachment attachment, File file});

/// The scans filed against a record, and the way to add one.
///
/// Empty, it is an invitation rather than a blank: the moment just after a
/// bill is recorded is when the paper is still on the counter.
class ScanStrip extends StatelessWidget {
  const ScanStrip({
    super.key,
    required this.scans,
    required this.onAdd,
    required this.onOpen,
    this.isAdding = false,
    this.emptyTitle = 'Attach the paper bill',
    this.emptyMessage =
        'Photograph it so the bill is on record even if the paper is lost.',
  });

  final List<ScanFile> scans;
  final VoidCallback onAdd;
  final void Function(ScanFile scan) onOpen;
  final bool isAdding;
  final String emptyTitle;
  final String emptyMessage;

  static const double _thumbWidth = 88;
  static const double _thumbHeight = 112;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (scans.isEmpty) {
      return AppCard(
        onTap: isAdding ? null : onAdd,
        child: Row(
          children: [
            IconPlate(
              icon: Icons.document_scanner_outlined,
              color: palette.brand,
            ),
            AppSizes.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyTitle,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    emptyMessage,
                    style: AppTextStyles.caption.copyWith(
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapSm,
            _busyOr(
              palette.brand,
              Icon(Icons.add_a_photo_outlined, color: palette.brand),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: _thumbHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: scans.length + 1,
        separatorBuilder: (_, _) => AppSizes.gapSm,
        itemBuilder: (context, index) {
          if (index == scans.length) {
            return _Tile(
              onTap: isAdding ? null : onAdd,
              child: Center(
                child: _busyOr(
                  palette.inkMuted,
                  Icon(Icons.add_a_photo_outlined, color: palette.inkMuted),
                ),
              ),
            );
          }

          final scan = scans[index];
          return _Tile(
            onTap: () => onOpen(scan),
            child: _Thumbnail(scan: scan),
          );
        },
      ),
    );
  }

  Widget _busyOr(Color color, Widget idle) => isAdding
      ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        )
      : idle;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.sunken,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: ScanStrip._thumbWidth,
          height: ScanStrip._thumbHeight,
          child: child,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.scan});

  final ScanFile scan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (!scan.attachment.isImage) {
      return Center(
        child: Icon(Icons.picture_as_pdf_outlined, color: palette.inkMuted),
      );
    }

    return Image.file(
      scan.file,
      fit: BoxFit.cover,
      // Decoded at thumbnail size, not the photo's full resolution.
      cacheWidth: (ScanStrip._thumbWidth * 3).round(),
      errorBuilder: (_, _, _) => Center(
        child: Icon(Icons.broken_image_outlined, color: palette.inkSubtle),
      ),
    );
  }
}

/// One scan, full screen, zoomable - a bill number or a figure in the corner
/// has to be readable, which a fitted photo on a phone rarely is.
class ScanViewer extends StatelessWidget {
  const ScanViewer({
    super.key,
    required this.scan,
    required this.title,
    this.onDelete,
  });

  final ScanFile scan;
  final String title;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final attachment = scan.attachment;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(
              _status(attachment),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (onDelete != null)
            IconButton(
              tooltip: 'Remove scan',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
        ],
      ),
      body: attachment.isImage
          ? InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.file(
                  scan.file,
                  errorBuilder: (_, _, _) => const _Unavailable(
                    'This scan is no longer on this phone.',
                  ),
                ),
              ),
            )
          : const _Unavailable('This file type cannot be previewed here.'),
    );
  }

  static String _status(Attachment attachment) {
    if (attachment.isUploaded) return 'Backed up to the server';
    if (attachment.uploadError != null) {
      return 'Not backed up: ${attachment.uploadError}';
    }
    return 'Saved on this phone · backs up when the bill syncs';
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}
