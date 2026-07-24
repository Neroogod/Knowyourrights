// Authenticated client for onboarding, emergency contacts, and custody alerts.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String? email;
  final List<String> channels;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    this.email,
    this.channels = const ['sms'],
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        status: json['status'] as String,
        email: json['email'] as String?,
        channels: (json['channels'] as List? ?? const ['sms']).cast<String>(),
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
  static const _rememberedEmailKey = 'kyr_remembered_email';
  static const _keepSignedInKey = 'kyr_keep_signed_in';
  static const _deviceIdKey = 'kyr_device_id';
  static const _queuedAlertsKey = 'kyr_queued_alerts';
  static String? _sessionToken;
  final http.Client _client;
  final FlutterSecureStorage _storage;

  bool get _managed => kSupabaseConfigured;
  GoTrueClient get _auth => Supabase.instance.client.auth;

  Future<String?> register(String email, String password) async {
    if (_managed) {
      await _auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'knowyourrights://auth/callback',
      );
      return null;
    }
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

  Future<(String, String?)> requestPasswordReset(String email) async {
    if (_managed) {
      await _auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'knowyourrights://auth/reset',
      );
      return (
        'If an account exists for this email, a password reset link has been sent.',
        null,
      );
    }
    final json = await _request(
      'POST',
      '/v1/auth/forgot-password',
      body: {'email': email},
      authenticated: false,
    );
    return (
      json['message'] as String,
      json['development_reset_token'] as String?,
    );
  }

  Future<void> resetPassword(String token, String password) async {
    if (_managed) {
      await _auth.updateUser(UserAttributes(password: password));
      return;
    }
    await _request(
      'POST',
      '/v1/auth/reset-password',
      body: {'token': token, 'password': password},
      authenticated: false,
    );
  }

  Future<void> login(
    String email,
    String password, {
    bool keepSignedIn = true,
  }) async {
    if (_managed) {
      final response = await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final token = response.session?.accessToken;
      if (token == null) {
        throw const AccountApiError(
          'Check your email verification, then sign in.',
        );
      }
      _sessionToken = token;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _rememberedEmailKey,
        email.trim().toLowerCase(),
      );
      await preferences.setBool(_keepSignedInKey, keepSignedIn);
      return;
    }
    final json = await _request(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    final token = json['access_token'] as String;
    _sessionToken = token;
    if (keepSignedIn) {
      await _storage.write(key: _tokenKey, value: token);
    } else {
      await _storage.delete(key: _tokenKey);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _rememberedEmailKey,
      email.trim().toLowerCase(),
    );
    await preferences.setBool(_keepSignedInKey, keepSignedIn);
  }

  Future<bool> get isSignedIn async => _managed
      ? _auth.currentSession != null
      : _sessionToken != null || (await _storage.read(key: _tokenKey)) != null;

  Future<String?> get rememberedEmail async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_rememberedEmailKey);
  }

  Future<bool> get keepSignedInPreference async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keepSignedInKey) ?? true;
  }

  Future<AccountProfile> profile() async {
    final json = await _request('GET', '/v1/profile');
    return AccountProfile.fromJson(json);
  }

  Future<void> signOut() async {
    _sessionToken = null;
    if (_managed) {
      await _auth.signOut(scope: SignOutScope.local);
      return;
    }
    await _storage.delete(key: _tokenKey);
  }

  Future<void> signOutOtherDevices() async {
    if (!_managed) {
      throw const AccountApiError('Managed sessions are not configured.');
    }
    await _auth.signOut(scope: SignOutScope.others);
  }

  Future<void> reauthenticate() async {
    if (!_managed) return;
    await _auth.reauthenticate();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    if (!_managed) return;
    final email = _auth.currentUser?.email;
    if (email == null) throw const AccountApiError('Please sign in again.');
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) {
      throw const AccountApiError('Reauthentication failed.');
    }
  }

  Future<void> changeEmail(String email, {String? nonce}) async {
    if (!_managed) {
      throw const AccountApiError('Managed email change is not configured.');
    }
    await _auth.updateUser(
      UserAttributes(email: email.trim().toLowerCase(), nonce: nonce),
      emailRedirectTo: 'knowyourrights://auth/callback',
    );
  }

  Future<Map<String, dynamic>> exportAccount() =>
      _request('GET', '/v1/account/export');

  Future<void> deleteAccount() async {
    await _request('DELETE', '/v1/account', body: {'confirmation': 'DELETE'});
    await signOut();
  }

  Future<List<Map<String, dynamic>>> sessions() =>
      _requestList('GET', '/v1/account/sessions');

  Future<void> saveProfile(String fullName, String phone) => _request(
    'PUT',
    '/v1/profile',
    body: {'full_name': fullName, 'phone': phone},
  );

  Future<(EmergencyContact, String?)> addContact(
    String name,
    String phone, {
    String? email,
    List<String> channels = const ['sms'],
    String? pushToken,
  }) async {
    final json = await _request(
      'POST',
      '/v1/emergency-contacts',
      body: {
        'name': name,
        'phone': phone,
        'email': ?email,
        'channels': channels,
        'push_token': ?pushToken,
      },
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

  Future<void> removeContact(String contactId) =>
      _request('DELETE', '/v1/emergency-contacts/$contactId');

  Future<Map<String, dynamic>> sendAlert({
    required String contactId,
    required String idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? stationName,
    bool isTest = false,
  }) async {
    final body = <String, dynamic>{
      'contact_id': contactId,
      'idempotency_key': idempotencyKey,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'accuracy': ?accuracy,
      'station_name': ?stationName,
      'is_test': isTest,
    };
    try {
      final result = await _request('POST', '/v1/custody-alerts', body: body);
      await _removeQueuedAlert(idempotencyKey);
      return result;
    } catch (_) {
      await _queueAlert(body);
      rethrow;
    }
  }

  Future<int> retryQueuedAlerts() async {
    final preferences = await SharedPreferences.getInstance();
    final queued =
        (jsonDecode(preferences.getString(_queuedAlertsKey) ?? '[]') as List)
            .cast<Map<String, dynamic>>();
    final remaining = <Map<String, dynamic>>[];
    var sent = 0;
    for (final body in queued) {
      try {
        await _request('POST', '/v1/custody-alerts', body: body);
        sent += 1;
      } catch (_) {
        remaining.add(body);
      }
    }
    await preferences.setString(_queuedAlertsKey, jsonEncode(remaining));
    return sent;
  }

  Future<void> _queueAlert(Map<String, dynamic> body) async {
    final preferences = await SharedPreferences.getInstance();
    final queued =
        (jsonDecode(preferences.getString(_queuedAlertsKey) ?? '[]') as List)
            .cast<Map<String, dynamic>>();
    final key = body['idempotency_key'];
    if (!queued.any((item) => item['idempotency_key'] == key)) {
      queued.add(body);
      await preferences.setString(_queuedAlertsKey, jsonEncode(queued));
    }
  }

  Future<void> _removeQueuedAlert(String idempotencyKey) async {
    final preferences = await SharedPreferences.getInstance();
    final queued =
        (jsonDecode(preferences.getString(_queuedAlertsKey) ?? '[]') as List)
            .cast<Map<String, dynamic>>();
    queued.removeWhere((item) => item['idempotency_key'] == idempotencyKey);
    await preferences.setString(_queuedAlertsKey, jsonEncode(queued));
  }

  Future<List<Map<String, dynamic>>> alertHistory() =>
      _requestList('GET', '/v1/custody-alerts');

  Future<Map<String, dynamic>> armCheckIn(int minutes, {String? stationName}) =>
      _request(
        'POST',
        '/v1/check-ins',
        body: {'minutes': minutes, 'station_name': ?stationName},
      );

  Future<Map<String, dynamic>?> activeCheckIn() async {
    final response = await _send('GET', '/v1/check-ins/active');
    if (response.statusCode == 200 && response.body == 'null') return null;
    final decoded = _decodeObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountApiError(_friendlyError(decoded['detail']));
    }
    return decoded;
  }

  Future<Map<String, dynamic>> completeCheckIn(String id) =>
      _request('POST', '/v1/check-ins/$id/safe');

  Future<Map<String, dynamic>> getAlert(String alertId) =>
      _request('GET', '/v1/custody-alerts/$alertId');

  Future<Map<String, dynamic>> cancelAlert(String alertId) =>
      _request('POST', '/v1/custody-alerts/$alertId/cancel');

  Future<Map<String, dynamic>> resolveAlert(String alertId) =>
      _request('POST', '/v1/custody-alerts/$alertId/resolve');

  Future<Map<String, dynamic>> retryAlert(String alertId) =>
      _request('POST', '/v1/custody-alerts/$alertId/retry');

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
    final decoded = _decodeObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountApiError(_friendlyError(decoded['detail']));
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _requestList(
    String method,
    String path,
  ) async {
    final response = await _send(method, path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _decodeObject(response);
      throw AccountApiError(_friendlyError(decoded['detail']));
    }
    try {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    } on FormatException {
      throw const AccountApiError(
        'The server returned an invalid response. Please try again.',
      );
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final preferences = await SharedPreferences.getInstance();
    var deviceId = preferences.getString(_deviceIdKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId =
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
          '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      await preferences.setString(_deviceIdKey, deviceId);
    }
    headers['X-Device-ID'] = deviceId;
    headers['X-Device-Name'] = 'KnowYourRights mobile app';
    if (authenticated) {
      final token = _managed
          ? _auth.currentSession?.accessToken
          : _sessionToken ?? await _storage.read(key: _tokenKey);
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

  String _friendlyError(Object? detail) {
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return (first['msg'] as String)
            .replaceFirst('Value error, ', '')
            .replaceFirst('String should have ', 'This field should have ');
      }
    }
    return 'Something went wrong. Check your details and try again.';
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw AccountApiError(
        response.statusCode >= 500
            ? 'The server could not complete the request. Please try again.'
            : 'The server returned an invalid response. Please try again.',
      );
    }
  }
}
