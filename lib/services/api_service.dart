import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/country.dart';
import '../utils/constants.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Country>> fetchCountries() async {
    final response = await _client
        .get(Uri.parse(countriesApiUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch countries: HTTP ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
    return jsonList
        .map((json) => Country.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
