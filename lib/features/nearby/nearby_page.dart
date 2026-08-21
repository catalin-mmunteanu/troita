import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/church.dart';
import '../../core/native/troita_native.dart';
import '../../app/app_scope.dart';
import '../common/church_tile.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  List<Church>? _churches;
  List<Church> _feasts = const <Church>[];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final AppState state = AppScope.of(context);
    try {
      final Position? here = await state.native.currentLocation();
      final List<Church> feasts = await state.repository.upcomingFeasts(days: 7);
      final List<Church> nearby = here == null
          ? const <Church>[]
          : await state.repository.nearby(
              lat: here.lat,
              lon: here.lon,
              radiusM: 25000,
              limit: 60,
            );

      if (!mounted) return;
      setState(() {
        _churches = nearby;
        _feasts = feasts;
        _loading = false;
        _error = here == null
            ? 'Nu am putut determina poziția. Verificați dacă locația este pornită.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Church>? churches = _churches;

    if (churches == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(_error!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (_feasts.isNotEmpty) ...<Widget>[
            const _SectionHeader('Hramuri în această săptămână'),
            ..._feasts.map((Church c) => ChurchTile(church: c)),
            const SizedBox(height: 12),
          ],
          const _SectionHeader('Cele mai apropiate'),
          if (churches == null || churches.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text('Nicio biserică în raza de 25 km.'),
            )
          else
            ...churches.map((Church c) => ChurchTile(church: c)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B6259),
        ),
      ),
    );
  }
}
