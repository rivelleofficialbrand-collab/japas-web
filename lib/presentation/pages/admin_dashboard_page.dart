// lib/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    // 🔥 Panggil fungsi RPC yang sudah dibuat di Supabase
    final response = await Supabase.instance.client.rpc('get_admin_stats');
    
    // Response bisa berbentuk Map atau List<Map> tergantung versi
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    
    return {
      'total_users': 0,
      'total_vendors': 0,
      'total_orders': 0,
      'completed_orders': 0,
    };
  } catch (e) {
    print('❌ Error ambil statistik admin: $e');
    // Kembalikan data kosong agar UI tetap tampil
    return {
      'total_users': 0,
      'total_vendors': 0,
      'total_orders': 0,
      'completed_orders': 0,
    };
  }
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final user = ref.watch(authProvider).value;

    // 🔒 Cek akses admin
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Akses ditolak. Hanya untuk admin.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔄 Data diperbarui')),
              );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat data statistik...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pastikan fungsi get_admin_stats() sudah dibuat di Supabase SQL Editor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminStatsProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Ringkasan Platform',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCard(
                      '👥 Total User',
                      stats['total_users']?.toString() ?? '0',
                      Colors.blue,
                      Icons.people,
                    ),
                    _buildCard(
                      '🛠️ Total Vendor',
                      stats['total_vendors']?.toString() ?? '0',
                      Colors.orange,
                      Icons.handyman,
                    ),
                    _buildCard(
                      '📦 Total Order',
                      stats['total_orders']?.toString() ?? '0',
                      Colors.purple,
                      Icons.shopping_cart,
                    ),
                    _buildCard(
                      '✅ Selesai',
                      stats['completed_orders']?.toString() ?? '0',
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Info tambahan (opsional)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Data ini diperbarui secara otomatis setiap kali Anda membuka halaman ini.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}