import 'dart:convert';

/// A first name the user follows for its name day, with who it is for.
///
/// Typed by hand from the name-day list, never read from the contacts: no
/// permission, and nothing about other people leaves the phone.
class SavedName {
  const SavedName(this.name, {this.label});

  /// As the name-day list spells it: "Andrei", "Maria".
  final String name;

  /// Optional, the user's own word for the person: "Mama", "Ionuț de la
  /// birou".
  final String? label;

  /// "Mama (Maria)", or just "Maria".
  String get display =>
      label == null || label!.isEmpty ? name : '$label ($name)';

  Map<String, Object?> toJson() =>
      <String, Object?>{'name': name, if (label != null) 'label': label};

  factory SavedName.fromJson(Map<String, Object?> j) =>
      SavedName(j['name']! as String, label: j['label'] as String?);

  static List<SavedName> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const <SavedName>[];
    try {
      return (jsonDecode(raw) as List<Object?>)
          .map((Object? e) => SavedName.fromJson(e! as Map<String, Object?>))
          .toList();
    } catch (_) {
      return const <SavedName>[];
    }
  }

  static String encodeList(List<SavedName> names) =>
      jsonEncode(names.map((SavedName n) => n.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      other is SavedName && other.name == name && other.label == label;

  @override
  int get hashCode => Object.hash(name, label);
}
