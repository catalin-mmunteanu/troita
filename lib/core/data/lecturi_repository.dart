import 'package:flutter/services.dart';

import '../models/lecturi.dart';

/// The Liturgy readings and the New Testament text, both bundled assets,
/// each loaded once on first use.
class LecturiRepository {
  LecturiRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<Lecturi>? _lecturi;
  Future<BibliaNT>? _biblia;

  static const String lecturiAsset = 'assets/data/lecturi.json';
  static const String bibliaAsset = 'assets/data/biblia_nt.json';

  Future<Lecturi> lecturi() =>
      _lecturi ??= _bundle.loadString(lecturiAsset).then(Lecturi.parse);

  Future<BibliaNT> biblia() =>
      _biblia ??= _bundle.loadString(bibliaAsset).then(BibliaNT.parse);
}
