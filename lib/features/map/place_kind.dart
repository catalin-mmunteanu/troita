import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The kinds of place the map draws, and how each one looks.
///
/// One table, because the colour, the radius, the chip label and the legend all
/// have to agree. Splitting them across the map and its controls is how a
/// legend ends up describing colours the map no longer uses.
///
/// The `id` values are the `kind` column as `build_seed.py` writes it. Anything
/// unrecognised falls back to [church] rather than vanishing: a new kind
/// appearing upstream should show up plainly, not silently disappear from a
/// national map.
enum PlaceKind {
  /// Gilded, and the largest dot. Monasteries are what people travel to.
  monastery(
    id: 'monastery',
    label: 'Mănăstiri',
    singular: 'Mănăstire',
    colour: TroitaColors.gold,
    radius: 8,
  ),

  cathedral(
    id: 'cathedral',
    label: 'Catedrale',
    singular: 'Catedrală',
    colour: TroitaColors.burgundy,
    radius: 8,
  ),

  church(
    id: 'church',
    label: 'Biserici',
    singular: 'Biserică',
    colour: TroitaColors.feastRed,
    radius: 6,
  ),

  chapel(
    id: 'chapel',
    label: 'Paraclise',
    singular: 'Paraclis',
    colour: TroitaColors.feastBlue,
    radius: 5,
  ),

  /// The smallest and quietest. There are 1,505 of them and they are roadside
  /// markers, not destinations — at national zoom they are noise, which is why
  /// they start hidden.
  waysideCross(
    id: 'wayside_cross',
    label: 'Troițe',
    singular: 'Troiță',
    colour: TroitaColors.muted,
    radius: 4,
  );

  const PlaceKind({
    required this.id,
    required this.label,
    required this.singular,
    required this.colour,
    required this.radius,
  });

  /// The `kind` value stored in the database.
  final String id;

  /// Plural, for filter chips and the legend.
  final String label;

  /// Singular, for a single place's own card.
  final String singular;

  final Color colour;

  /// Pixel radius of the dot. Ordered by how far someone would travel for the
  /// thing, not by the size of the building.
  final double radius;

  static PlaceKind from(String? id) {
    for (final PlaceKind k in PlaceKind.values) {
      if (k.id == id) return k;
    }
    return PlaceKind.church;
  }

  /// Everything except troițe. They outnumber monasteries two to one and
  /// crowd the map without adding much, so they are opt-in.
  static Set<PlaceKind> get defaultVisible =>
      PlaceKind.values.toSet()..remove(PlaceKind.waysideCross);
}
