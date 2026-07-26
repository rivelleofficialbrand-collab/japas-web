// lib/presentation/pages/home_page.dart
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'add_service_page.dart';
import 'booking_page.dart';
import 'vendor_dashboard_page.dart';
import 'customer_dashboard_page.dart';
import 'admin_dashboard_page.dart';

// ============================================================
// HAVERSINE FORMULA (Hitung Jarak)
// ============================================================
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

// ============================================================
// PROVIDERS
// ============================================================

final userLocationProvider = StateProvider<(double, double)?>((ref) => null);

final servicesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final stream = Supabase.instance.client
      .from('services')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return stream.map((data) => data as List<Map<String, dynamic>>);
});

final serviceRatingsProvider = FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client.rpc('get_service_ratings');
  Map<String, Map<String, dynamic>> result = {};
  for (var row in response) {
    result[row['service_id']] = {
      'avg_rating': (row['avg_rating'] as num).toDouble(),
      'total_reviews': row['total_reviews'] as int,
    };
  }
  return result;
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final vendorProfilesProvider = FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('id, latitude, longitude, name, location')
      .eq('role', 'vendor');
  Map<String, Map<String, dynamic>> result = {};
  for (var row in response) {
    result[row['id']] = {
      'latitude': row['latitude'] != null ? (row['latitude'] as num).toDouble() : null,
      'longitude': row['longitude'] != null ? (row['longitude'] as num).toDouble() : null,
      'name': row['name'] ?? 'Vendor',
      'location': row['location'] ?? '',
    };
  }
  return result;
});

final filteredServicesProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final servicesAsync = ref.watch(servicesStreamProvider);
  final ratingsAsync = ref.watch(serviceRatingsProvider);
  final vendorsAsync = ref.watch(vendorProfilesProvider);
  final query = ref.watch(searchQueryProvider);
  final userLoc = ref.watch(userLocationProvider);

  return servicesAsync.whenData((list) {
    final ratings = ratingsAsync.value ?? {};
    final vendors = vendorsAsync.value ?? {};
    final enriched = list.map((service) {
      final serviceId = service['id'];
      final vendorId = service['vendor_id'];
      final vendorData = vendors[vendorId] ?? {};
      final vendorLat = vendorData['latitude'];
      final vendorLng = vendorData['longitude'];
      final ratingData = ratings[serviceId] ?? {'avg_rating': 0.0, 'total_reviews': 0};

      double distance = -1;
      if (userLoc != null && vendorLat != null && vendorLng != null) {
        distance = calculateDistance(
          userLoc.$1,
          userLoc.$2,
          vendorLat,
          vendorLng,
        );
      }

      return {
        ...service,
        'avg_rating': ratingData['avg_rating'],
        'total_reviews': ratingData['total_reviews'],
        'vendor_name': vendorData['name'] ?? 'Vendor',
        'vendor_location': vendorData['location'] ?? '',
        'distance': distance,
        'has_location': vendorLat != null && vendorLng != null,
      };
    }).toList();

    List<Map<String, dynamic>> filtered = enriched;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((service) {
        final title = (service['title'] as String? ?? '').toLowerCase();
        final category = (service['category'] as String? ?? '').toLowerCase();
        final description = (service['description'] as String? ?? '').toLowerCase();
        return title.contains(q) || category.contains(q) || description.contains(q);
      }).toList();
    }

    filtered.sort((a, b) {
      if (userLoc == null) {
        return (b['avg_rating'] ?? 0).compareTo(a['avg_rating'] ?? 0);
      }
      final aHasLoc = a['has_location'] ?? false;
      final bHasLoc = b['has_location'] ?? false;
      if (aHasLoc && !bHasLoc) return -1;
      if (!aHasLoc && bHasLoc) return 1;
      if (aHasLoc && bHasLoc) {
        return (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity);
      }
      return (b['avg_rating'] ?? 0).compareTo(a['avg_rating'] ?? 0);
    });

    return filtered;
  });
});

// ============================================================
// HOMEPAGE
// ============================================================
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final servicesAsync = ref.watch(filteredServicesProvider);
    final userLoc = ref.watch(userLocationProvider);
    final user = authState.value;
    final themeMode = ref.watch(themeProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (userLoc == null) {
        try {
          final pos = await html.window.navigator.geolocation?.getCurrentPosition();
          if (pos != null) {
            final coords = pos.coords as dynamic;
            final lat = coords.latitude as double?;
            final lng = coords.longitude as double?;
            if (lat != null && lng != null) {
              ref.read(userLocationProvider.notifier).state = (lat, lng);
              ref.invalidate(servicesStreamProvider);
              ref.invalidate(vendorProfilesProvider);
            }
          }
        } catch (e) {
          print('⚠️ Gagal ambil lokasi GPS: $e');
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Japas',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              color: AppTheme.primary,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
          if (authState.hasValue && user != null && user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.red),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                );
              },
              tooltip: 'Admin Panel',
            ),
          if (authState.hasValue && user != null)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: AppTheme.primary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerDashboardPage()),
                );
              },
              tooltip: 'Dashboard Customer',
            ),
          if (authState.hasValue && user?.role == 'vendor')
            IconButton(
              icon: const Icon(Icons.dashboard, color: AppTheme.primary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VendorDashboardPage()),
                );
              },
              tooltip: 'Dashboard Vendor',
            ),
          if (authState.hasValue && user != null)
            IconButton(
              icon: const Icon(Icons.person, color: AppTheme.primary),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
                if (result == true) {
                  ref.invalidate(authProvider);
                  ref.invalidate(vendorProfilesProvider);
                }
              },
              tooltip: 'Edit Profil',
            ),
          if (authState.hasValue && user != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              tooltip: 'Logout',
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text('Login'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(servicesStreamProvider);
          ref.invalidate(serviceRatingsProvider);
          ref.invalidate(vendorProfilesProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Cari jasa terdekat...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.clear, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (userLoc != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '📍 Menampilkan jasa terdekat dari lokasi Anda (${userLoc.$1.toStringAsFixed(4)}, ${userLoc.$2.toStringAsFixed(4)})',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '⏳ Mendeteksi lokasi untuk mencari jasa terdekat...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),

              if (authState.hasValue && user != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.check, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, ${user.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Role: ${user.role}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (user.location.isNotEmpty)
                              Text(
                                '📍 ${user.location}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.secondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Login untuk memesan jasa atau daftar sebagai vendor',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              const Text(
                '🔥 Jasa Terdekat & Terbaik',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              servicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text('Gagal memuat jasa: $err'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(servicesStreamProvider);
                          ref.invalidate(serviceRatingsProvider);
                          ref.invalidate(vendorProfilesProvider);
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
                data: (services) {
                  if (services.isEmpty) {
                    final query = ref.watch(searchQueryProvider);
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              query.isEmpty
                                  ? 'Belum ada jasa terdaftar. Ayo jadi vendor pertama!'
                                  : 'Tidak ada jasa yang cocok dengan "$query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final priceFormat = 'Rp ${service['price'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
                      final vendorName = service['vendor_name'] ?? 'Vendor';
                      final vendorId = service['vendor_id'] ?? '';
                      final avgRating = service['avg_rating'] ?? 0.0;
                      final totalReviews = service['total_reviews'] ?? 0;
                      final distance = service['distance'] ?? -1;
                      final hasLocation = service['has_location'] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: Text(
                              service['category']?.isNotEmpty == true
                                  ? service['category'][0].toUpperCase()
                                  : '📦',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          title: Text(
                            service['title'] ?? 'Jasa Tanpa Judul',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                priceFormat,
                                style: const TextStyle(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  if (totalReviews > 0) ...[
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      avgRating.toStringAsFixed(1),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '($totalReviews)',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ] else
                                    Text(
                                      'Belum ada rating',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  const Spacer(),
                                  if (hasLocation && distance >= 0)
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.blue, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          distance < 1
                                              ? '${(distance * 1000).toStringAsFixed(0)} m'
                                              : '${distance.toStringAsFixed(1)} km',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    const Text(
                                      '📍 Lokasi tidak tersedia',
                                      style: TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                ],
                              ),
                              Text(
                                'by $vendorName',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: authState.hasValue && user != null
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BookingPage(
                                          service: service,
                                          vendorId: vendorId,
                                        ),
                                      ),
                                    );
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Silakan login terlebih dahulu!'),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Pesan'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: (authState.hasValue && user?.role == 'vendor')
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddServicePage()),
                );
                if (result == true) {
                  ref.invalidate(servicesStreamProvider);
                  ref.invalidate(serviceRatingsProvider);
                  ref.invalidate(vendorProfilesProvider);
                }
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}