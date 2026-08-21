import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/church.dart';
import '../../app/app_scope.dart';
import '../common/church_tile.dart';

/// Everything the app has ever notified about, newest first.
///
/// Read from the `encounters` table the native path writes — the same table
/// that backs the notification cooldown, so this doubles as a debugging view
/// when someone reports "it didn't tell me about X".
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<(Church, DateTime)>? _rows;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final List<Map<String, Object?>> raw =
        await AppScope.of(context).native.recentEncounters();
    if (!mounted) return;
    setState(() {
      _rows = raw
          .map((Map<String, Object?> r) => (
                Church.fromRow(r),
                DateTime.fromMillisecondsSinceEpoch(
                  (r['notified_at']! as num).toInt(),
                ),
              ))
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<(Church, DateTime)>? rows = _rows;
    if (rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Încă nu ați trecut pe lângă nicio biserică\nde când folosiți Troița.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(indent: 76),
        itemBuilder: (BuildContext context, int i) {
          final (Church church, DateTime at) = rows[i];
          return ChurchTile(
            church: church,
            trailing: Text(
              Fmt.date(at),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    );
  }
}
