import 'package:flutter/material.dart';

import '../services/scan_repository.dart';
import '../theme.dart';
import '../widgets/scan_tile.dart';
import 'result_screen.dart';

/// Everything the user has kept, newest first.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My plants')),
      body: ListenableBuilder(
        listenable: ScanRepository.instance,
        builder: (context, _) {
          final records = ScanRepository.instance.records;
          if (records.isEmpty) return const _EmptyLog();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = records[index];

              return Dismissible(
                key: ValueKey(record.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 22),
                  decoration: BoxDecoration(
                    color: Botanic.rust.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.delete_outline, color: Botanic.rust),
                ),
                onDismissed: (_) {
                  ScanRepository.instance.delete(record.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${record.displayName} removed'),
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: Botanic.chlorophyll,
                        onPressed: () =>
                            ScanRepository.instance.restore(record),
                      ),
                    ),
                  );
                },
                child: ScanTile(
                  record: record,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultScreen.fromRecord(record),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_outlined, size: 44, color: Botanic.hairline),
            const SizedBox(height: 18),
            Text('Nothing kept yet', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Scans you add from the Identify tab will collect here with '
              'their care notes.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Botanic.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
