/// API URLs
const String countriesApiUrl =
    'https://restcountries.com/v3.1/all?fields=name,cca2,flags';
const String flagCdnBaseUrl = 'https://flagcdn.com/w320';

/// SharedPreferences keys
class StorageKeys {
  static const String solvedCodes = 'solved_country_codes';
  static const String totalScore = 'total_score';
}

/// Game constants
const Map<int, int> pointsTable = {1: 10, 2: 8, 3: 5};
const int maxAttempts = 3;
