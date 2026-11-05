import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/attachment.dart';
import '../../constants/app_sizes.dart';
import '../../controllers/scan_capture.dart';
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
    if (scans.isEmpty) {
      return _AddScanCard(
        title: emptyTitle,
        message: emptyMessage,
        isAdding: isAdding,
        onAdd: onAdd,
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
            return _AddScanTile(isAdding: isAdding, onAdd: onAdd);
          }

          final scan = scans[index];
          return _Tile(
            onTap: () => onOpen(scan),
            child: ScanThumbnail(scan: scan),
          );
        },
      ),
    );
  }
}

/// [ScanStrip] for a form: the same look, over photos waiting for the record to
/// be saved. Nothing is filed yet, so a photo comes off with one tap rather than
/// through the viewer and a confirmation.
class ScanDraftStrip extends StatelessWidget {
  const ScanDraftStrip({
    super.key,
    required this.draft,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final ScanDraft draft;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final photos = draft.photos;
      final isAdding = draft.isAdding.value;

      if (photos.isEmpty) {
        return _AddScanCard(
          title: emptyTitle,
          message: emptyMessage,
          isAdding: isAdding,
          onAdd: draft.add,
        );
      }

      return SizedBox(
        height: ScanStrip._thumbHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length + 1,
          separatorBuilder: (_, _) => AppSizes.gapSm,
          itemBuilder: (context, index) {
            if (index == photos.length) {
              return _AddScanTile(isAdding: isAdding, onAdd: draft.add);
            }

            return _DraftPhoto(
              path: photos[index].path,
              onRemove: () => draft.removeAt(index),
            );
          },
        ),
      );
    });
  }
}

class _DraftPhoto extends StatelessWidget {
  const _DraftPhoto({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PhotoFile(file: File(path)),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Remove this photo',
              onPressed: onRemove,
              icon: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The invitation shown while a record has no scans.
class _AddScanCard extends StatelessWidget {
  const _AddScanCard({
    required this.title,
    required this.message,
    required this.isAdding,
    required this.onAdd,
  });

  final String title;
  final String message;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(color: palette.ink),
                ),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          AppSizes.gapSm,
          _AddScanIcon(isAdding: isAdding, color: palette.brand),
        ],
      ),
    );
  }
}

/// The last tile on a strip that already has photos.
class _AddScanTile extends StatelessWidget {
  const _AddScanTile({required this.isAdding, required this.onAdd});

  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: isAdding ? null : onAdd,
      child: Center(
        child: _AddScanIcon(
          isAdding: isAdding,
          color: context.palette.inkMuted,
        ),
      ),
    );
  }
}

class _AddScanIcon extends StatelessWidget {
  const _AddScanIcon({required this.isAdding, required this.color});

  final bool isAdding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return isAdding
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        : Icon(Icons.add_a_photo_outlined, color: color);
  }
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

/// A scan's photo, or a PDF icon for a file that has no picture to show.
class ScanThumbnail extends StatelessWidget {
  const ScanThumbnail({super.key, required this.scan});

  final ScanFile scan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (!scan.attachment.isImage) {
      return Center(
        child: Icon(Icons.picture_as_pdf_outlined, color: palette.inkMuted),
      );
    }

    return _PhotoFile(file: scan.file);
  }
}

class _PhotoFile extends StatelessWidget {
  const _PhotoFile({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      // Decoded at thumbnail size, not the photo's full resolution.
      cacheWidth: (ScanStrip._thumbWidth * 3).round(),
      errorBuilder: (_, _, _) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: context.palette.inkSubtle,
        ),
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
