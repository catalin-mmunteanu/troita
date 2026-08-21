import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/church.dart';
import '../../core/models/feast_calendar.dart';
import '../church_detail/church_detail_page.dart';

class ChurchTile extends StatelessWidget {
  const ChurchTile({required this.church, this.trailing, super.key});

  final Church church;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool feastToday = FeastCalendar.isToday(church.feastDay);
    final String? relative = Fmt.feastRelative(church.feastDay);

    return ListTile(
      leading: _KindBadge(kind: church.kind, highlight: feastToday),
      title: Text(church.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Text(
            <String>[
              Fmt.kind(church.kind),
              if (church.patron != null) church.patron!,
              if (church.yearBuilt != null) 'din ${church.yearBuilt}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (relative != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                relative,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: feastToday ? TroitaTheme.red : TroitaTheme.gold,
                ),
              ),
            ),
        ],
      ),
      trailing: trailing ??
          (church.distanceM == null
              ? null
              : Text(
                  Fmt.distance(church.distanceM),
                  style: Theme.of(context).textTheme.bodySmall,
                )),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChurchDetailPage(churchId: church.id, initial: church),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.highlight});

  final String kind;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color colour = highlight ? TroitaTheme.red : TroitaTheme.gold;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        switch (kind) {
          'monastery' || 'cathedral' => Icons.account_balance,
          'wayside_cross' => Icons.add,
          _ => Icons.church,
        },
        size: 20,
        color: colour,
      ),
    );
  }
}
