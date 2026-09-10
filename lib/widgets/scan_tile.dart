import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/scan_record.dart';
import '../services/scan_repository.dart';
import '../theme.dart';

/// A quiet panel used to group content on the surface background.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Botanic.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Botanic.hairline),
      ),
      child: child,
    );
  }
}

class ScanTile extends StatelessWidget {
  const ScanTile({required this.record, required this.onTap, super.key});

  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final photo = ScanRepository.instance.imageFileFor(record);

    return Material(
      color: Botanic.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Botanic.hairline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo.existsSync()
                    ? Image.file(
                        photo,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 62,
                        height: 62,
                        color: Botanic.hairline,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 20,
                          color: Botanic.inkSoft,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.identification.scientificName.isEmpty
                          ? DateFormat.yMMMd().format(record.scannedAt)
                          : record.identification.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: Botanic.inkSoft,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Botanic.inkSoft,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
