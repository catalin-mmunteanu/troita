import 'package:flutter/material.dart';

/// The kinds of place the map draws, and how each one looks.
///
/// One table, because the dot colour, its size, the legend row and the search
/// result marker all have to agree. Splitting them is how a legend ends up
/// describing colours the map no longer uses.
///
/// The palette is chosen against the base map rather than against the app's
/// theme. The first version reused theme colours — gold, burgundy, the feast
/// red, the feast blue, a muted brown — and three of the five were warm reds
/// and golds that read as one family at six pixels. These are five separate
/// hues, none of which the OpenFreeMap style already uses for something else:
/// water is light blue, parks are pale green, roads are yellow and orange, the
/// ground is beige. Size carries a second signal, so two kinds that a
/// colour-blind reader might confuse still differ at a glance.
///
/// The `id` values are the `kind` column as `build_seed.py` writes it. Anything
/// unrecognised falls back to [church] rather than vanishing: a new kind
/// appearing upstream should show up plainly, not disappear from the map.
enum PlaceKind {
  // Declared in legend order: the common case first, troițe last.

  church(
    id: 'church',
    label: 'Biserici',
    singular: 'Biserică',
    colour: Color(0xFFC62828), // deep red
    radius: 6,
  ),

  /// Purple, and the largest dot with cathedrals. Monasteries are what people
  /// travel to.
  monastery(
    id: 'monastery',
    label: 'Mănăstiri',
    singular: 'Mănăstire',
    colour: Color(0xFF7B1FA2), // purple
    radius: 8,
  ),

  /// Golden yellow is the one light colour in the set, so it gets a dark
  /// outline instead of a white one — on beige ground a white ring around
  /// yellow all but disappears.
  cathedral(
    id: 'cathedral',
    label: 'Catedrale',
    singular: 'Catedrală',
    colour: Color(0xFFF9A825), // golden yellow
    radius: 8,
    stroke: Color(0xFF5D4037),
  ),

  chapel(
    id: 'chapel',
    label: 'Paraclise',
    singular: 'Paraclis',
    colour: Color(0xFF1565C0), // blue, far darker than the map's water
    radius: 5,
  ),

  /// The smallest and quietest: 1,505 roadside markers, not destinations. At
  /// national zoom they are noise, which is why they start hidden.
  waysideCross(
    id: 'wayside_cross',
    label: 'Troițe',
    singular: 'Troiță',
    colour: Color(0xFF37474F), // charcoal
    radius: 4,
  );

  const PlaceKind({
    required this.id,
    required this.label,
    required this.singular,
    required this.colour,
    required this.radius,
    this.stroke = const Color(0xFFFFFFFF),
  });

  /// The `kind` value stored in the database.
  final String id;

  /// Plural, for the legend.
  final String label;

  /// Singular, for a single place's own card.
  final String singular;

  final Color colour;

  /// Outline drawn around the dot so it separates from whatever is under it.
  final Color stroke;

  /// Pixel radius of the dot. Ordered by how far someone would travel for the
  /// thing, not by the size of the building.
  final double radius;

  static PlaceKind from(String? id) {
    for (final PlaceKind k in PlaceKind.values) {
      if (k.id == id) return k;
    }
    return PlaceKind.church;
  }

  /// Only churches at first. They are what most people open the map for, and
  /// with everything switched on the country is a carpet of dots. The legend
  /// switches the rest on with one tap each.
  static Set<PlaceKind> get defaultVisible => <PlaceKind>{PlaceKind.church};
}
