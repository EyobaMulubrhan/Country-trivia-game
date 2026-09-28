import 'package:flutter_test/flutter_test.dart';
import 'package:country_trivia/models/country.dart';

void main() {
  group('Country', () {
    test('fromJson parses name.common and cca2 correctly', () {
      final json = {
        'name': {'common': 'Germany'},
        'cca2': 'DE',
      };

      final country = Country.fromJson(json);

      expect(country.name, 'Germany');
      expect(country.cca2, 'DE');
    });

    test('flagUrl returns correct URL format', () {
      const country = Country(name: 'Germany', cca2: 'DE');

      expect(country.flagUrl, 'https://flagcdn.com/w320/de.png');
    });

    test('flagUrl lowercases cca2', () {
      const country = Country(name: 'United States', cca2: 'US');

      expect(country.flagUrl, 'https://flagcdn.com/w320/us.png');
    });

    test('equality works correctly', () {
      const country1 = Country(name: 'Germany', cca2: 'DE');
      const country2 = Country(name: 'Germany', cca2: 'DE');
      const country3 = Country(name: 'France', cca2: 'FR');

      expect(country1, equals(country2));
      expect(country1, isNot(equals(country3)));
    });

    test('hashCode is consistent with equality', () {
      const country1 = Country(name: 'Germany', cca2: 'DE');
      const country2 = Country(name: 'Germany', cca2: 'DE');

      expect(country1.hashCode, equals(country2.hashCode));
    });

    test('toString contains name and cca2', () {
      const country = Country(name: 'Germany', cca2: 'DE');

      final str = country.toString();

      expect(str, contains('Germany'));
      expect(str, contains('DE'));
    });
  });
}
