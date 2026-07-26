// lib/core/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String location;
  final String role;
  final double? latitude;
  final double? longitude;
  final bool isAdmin;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone = '',
    this.location = '',
    this.role = 'customer',
    this.latitude,
    this.longitude,
    this.isAdmin = false,
  });

  factory UserModel.fromSupabase(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? 'User',
      phone: data['phone'] ?? '',
      location: data['location'] ?? '',
      role: data['role'] ?? 'customer',
      latitude: data['latitude'] != null ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] != null ? (data['longitude'] as num).toDouble() : null,
      // 🔥 FIX: Cast ke bool? lalu fallback false jika null
      isAdmin: (data['is_admin'] as bool?) ?? false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  late final StreamSubscription<AuthState> _authSubscription;

  AuthNotifier() : super(const AsyncValue.data(null)) {
    _checkSession();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;
      final session = authState.session;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _handleSession(session);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AsyncValue.data(null);
      }
    });
  }

  void _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _handleSession(session);
    }
  }

  Future<void> _handleSession(Session? session) async {
    if (session == null) return;
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();

      if (response == null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': session.user.id,
          'email': session.user.email,
          'name': session.user.email?.split('@')[0] ?? 'User',
          'role': 'customer',
          'phone': '',
          'location': '',
          'latitude': null,
          'longitude': null,
          'is_admin': false,
        });
        final newProfile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .single();
        state = AsyncValue.data(UserModel.fromSupabase(newProfile));
      } else {
        state = AsyncValue.data(UserModel.fromSupabase(response));
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> sendMagicLink(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);
    } catch (e) {
      throw Exception('Gagal kirim link: $e');
    }
  }

  Future<void> devLogin(String email) async {
    state = const AsyncValue.loading();
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        state = AsyncValue.data(UserModel.fromSupabase(response));
        print('✅ Dev Login berhasil: ${response['email']}');
      } else {
        final allEmails = await Supabase.instance.client.from('profiles').select('email');
        print('❌ Email "$email" tidak ditemukan.');
        state = const AsyncValue.data(null);
        throw Exception('Email "$email" tidak ditemukan.');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      print('❌ Dev Login Error: $e');
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw Exception('User tidak login');
    }

    try {
      final Map<String, dynamic> data = {
        'name': name,
        'phone': phone,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
      };

      await Supabase.instance.client
          .from('profiles')
          .update(data)
          .eq('id', currentUser.id);

      final updatedUser = UserModel(
        id: currentUser.id,
        email: currentUser.email,
        name: name,
        phone: phone,
        location: location,
        role: currentUser.role,
        latitude: latitude,
        longitude: longitude,
        isAdmin: currentUser.isAdmin,
      );
      state = AsyncValue.data(updatedUser);
    } catch (e) {
      throw Exception('Gagal update profil: $e');
    }
  }

  void logout() async {
    await Supabase.instance.client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}