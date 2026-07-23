// Authenticated client for onboarding, emergency contacts, and custody alerts.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class AccountApiError implements Exception {
  final String message;
  const AccountApiError(this.message);

  @override
  String toString() => message;
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String status;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        status: json['status'] as String,
      );
}

class AccountProfile {
  final String email;
  final String? fullName;
  final String? phone;
  final bool emailVerified;
  final bool onboardingComplete;

  const AccountProfile({
    required this.email,
    required this.fullName,
    required this.phone,
    required this.emailVerified,
    required this.onboardingComplete,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
    emailVerified: json['email_verified'] as bool,
    onboardingComplete: json['onboarding_complete'] as bool,
  );
}

class AccountClient {
  AccountClient({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'kyr_access_token';
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<String?> register(String email, String password) async {
    final json = await _request(
      'POST',
      '/v1/auth/register',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    return json['development_verification_token'] as String?;
  }

  Future<void> verifyEmail(String token) => _request(
    'POST',
    '/v1/auth/verify-email',
    body: {'token': token},
    authenticated: false,
  );

  Future<void> login(String email, String password) async {
    final json = await _request(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _storage.write(key: _tokenKey, value: json['access_token'] as String);
  }

  Future<bool> get isSignedIn async =>
      (await _storage.read(key: _tokenKey)) != null;

  Future<AccountProfile> profile() async {
    final json = await _request('GET', '/v1/profile');
    return AccountProfile.fromJson(json);
  }

  Future<void> signOut() => _storage.delete(key: _tokenKey);

  Future<void> saveProfile(String fullName, String phone) => _request(
    'PUT',
    '/v1/profile',
    body: {'full_name': fullName, 'phone': phone},
  );

  Future<(EmergencyContact, String?)> addContact(
    String name,
    String phone,
  ) async {
    final json = await _request(
      'POST',
      '/v1/emergency-contacts',
      body: {'name': name, 'phone': phone},
    );
    return (
      EmergencyContact.fromJson(json),
      json['development_verification_token'] as String?,
    );
  }

  Future<void> verifyContact(String token) => _request(
    'POST',
    '/v1/emergency-contacts/verify',
    body: {'token': token},
    authenticated: false,
  );

  Future<List<EmergencyContact>> contacts() async {
    final rows = await _requestList('GET', '/v1/emergency-contacts');
    return rows.map(EmergencyContact.fromJson).toList();
  }

  Future<Map<String, dynamic>> sendAlert({
    required String contactId,
    required String idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) {
    return _request(
      'POST',
      '/v1/custody-alerts',
      body: {
        'contact_id': contactId,
        'idempotency_key': idempotencyKey,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'accuracy': ?accuracy,
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountApiError(decoded['detail']?.toString() ?? 'Request failed.');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _requestList(
    String method,
    String path,
  ) async {
    final response = await _send(method, path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw AccountApiError(decoded['detail']?.toString() ?? 'Request failed.');
    }
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) throw const AccountApiError('Please sign in first.');
      headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$kBaseUrl$path');
    return switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
      _ => _client.post(uri, headers: headers, body: jsonEncode(body)),
    };
  }
}
