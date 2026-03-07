/// Sport type constants mirroring the backend SPORT_TYPES array from @/lib/sports.
/// Default sport when none is provided or value is invalid: 'futsal'.

class SportItem {
  final String id; // matches backend SPORT_TYPES value (lowercase)
  final String name; // display name (title-cased)
  final String emoji;

  const SportItem({
    required this.id,
    required this.name,
    required this.emoji,
  });
}

/// All 15 sport types supported by the backend.
const List<SportItem> kAllSports = [
  SportItem(id: 'futsal', name: 'Futsal', emoji: '⚽'),
  SportItem(id: 'cricket', name: 'Cricket', emoji: '🏏'),
  SportItem(id: 'basketball', name: 'Basketball', emoji: '🏀'),
  SportItem(id: 'volleyball', name: 'Volleyball', emoji: '🏐'),
  SportItem(id: 'badminton', name: 'Badminton', emoji: '🏸'),
  SportItem(id: 'tennis', name: 'Tennis', emoji: '🎾'),
  SportItem(id: 'football', name: 'Football', emoji: '🏈'),
  SportItem(id: 'swimming', name: 'Swimming', emoji: '🏊'),
  SportItem(id: 'table tennis', name: 'Table Tennis', emoji: '🏓'),
  SportItem(id: 'boxing', name: 'Boxing', emoji: '🥊'),
  SportItem(id: 'kabaddi', name: 'Kabaddi', emoji: '🤼'),
  SportItem(id: 'archery', name: 'Archery', emoji: '🏹'),
  SportItem(id: 'cycling', name: 'Cycling', emoji: '🚴'),
  SportItem(id: 'yoga', name: 'Yoga', emoji: '🧘'),
  SportItem(id: 'gym', name: 'Gym', emoji: '💪'),
];

/// The 5 featured sports shown in quick-access chips on the home screen
/// and the venue list screen's top sport bar.
const List<SportItem> kFeaturedSports = [
  SportItem(id: 'futsal', name: 'Futsal', emoji: '⚽'),
  SportItem(id: 'badminton', name: 'Badminton', emoji: '🏸'),
  SportItem(id: 'cricket', name: 'Cricket', emoji: '🏏'),
  SportItem(id: 'basketball', name: 'Basketball', emoji: '🏀'),
  SportItem(id: 'table tennis', name: 'Table Tennis', emoji: '🏓'),
];

/// Returns the [SportItem] for the given backend [id], or null if not found.
SportItem? sportItemById(String id) {
  try {
    return kAllSports.firstWhere(
      (s) => s.id.toLowerCase() == id.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

/// Returns the display name for a backend sport id.
/// Falls back to capitalising the first letter of [id].
String sportDisplayName(String id) {
  final item = sportItemById(id);
  if (item != null) return item.name;
  if (id.isEmpty) return 'Futsal';
  return id[0].toUpperCase() + id.substring(1);
}

/// Returns the emoji for a backend sport id. Falls back to '🏟️'.
String sportEmoji(String id) => sportItemById(id)?.emoji ?? '🏟️';
