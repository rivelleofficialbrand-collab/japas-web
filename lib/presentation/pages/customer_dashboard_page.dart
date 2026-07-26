// lib/presentation/pages/customer_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import 'rating_page.dart';

final customerOrdersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value([]);
  return Supabase.instance.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('customer_id', user.id)
      .order('created_at', ascending: false)
      .map((data) => data as List<Map<String, dynamic>>);
});

class CustomerDashboardPage extends ConsumerWidget {
  const CustomerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    final user = ref.watch(authProvider).value;

    // Cek apakah order sudah dirating
    Future<bool> _hasRating(String orderId) async {
      final response = await Supabase.instance.client
          .from('ratings')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      return response != null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Customer'),
        backgroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text('Gagal memuat order: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(customerOrdersProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Belum ada order. Mulai pesan jasa sekarang!'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final statusColor = order['status'] == 'pending'
                  ? Colors.orange
                  : order['status'] == 'accepted'
                  ? Colors.blue
                  : order['status'] == 'completed'
                  ? Colors.green
                  : Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order['id'].toString().substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              order['status']?.toUpperCase() ?? 'PENDING',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Total: Rp ${order['total_price']?.toString() ?? '0'}'),
                      Text(
                        'Jadwal: ${order['schedule'] != null ? DateTime.parse(order['schedule']).toLocal().toString() : 'Belum diatur'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      // Tombol Rating (hanya muncul jika status completed dan belum pernah rating)
                      if (order['status'] == 'completed')
                        FutureBuilder<bool>(
                          future: _hasRating(order['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            if (snapshot.data == true) {
                              return Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Sudah dirating'),
                                ],
                              );
                            }
                            return ElevatedButton.icon(
                              onPressed: () async {
                                // Ambil data service dari order
                                final serviceResponse = await Supabase.instance.client
                                    .from('services')
                                    .select('title')
                                    .eq('id', order['service_id'])
                                    .maybeSingle();
                                final serviceTitle = serviceResponse?['title'] ?? 'Jasa';

                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RatingPage(
                                      orderId: order['id'],
                                      serviceTitle: serviceTitle,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  ref.invalidate(customerOrdersProvider);
                                }
                              },
                              icon: const Icon(Icons.star_border),
                              label: const Text('Beri Rating'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}