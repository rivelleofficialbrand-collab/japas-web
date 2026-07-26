// lib/presentation/pages/vendor_dashboard_page.dart
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

final vendorOrdersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value([]);
  return Supabase.instance.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('vendor_id', user.id)
      .order('created_at', ascending: false)
      .map((data) => data as List<Map<String, dynamic>>);
});

class VendorDashboardPage extends ConsumerStatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  ConsumerState<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends ConsumerState<VendorDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Request izin notifikasi browser
    if (html.window.navigator?.permissions != null) {
      html.window.navigator!.permissions!.query({'name': 'notifications'}).then((status) {
        print('🔔 Notification permission: ${status.state}');
      });
    }
  }

  void _showBrowserNotification(String title, String body) {
    try {
      if (html.Notification.supported) {
        final notification = html.Notification(title, body: body, icon: 'favicon.ico');
        // Notifikasi otomatis tampil
        Future.delayed(const Duration(seconds: 5), () => notification.close());
      }
    } catch (e) {
      print('⚠️ Gagal notifikasi: $e');
    }
  }

  int _pendingCount(List<Map<String, dynamic>> orders) {
    return orders.where((o) => o['status'] == 'pending').length;
  }

  Future<void> _exportCSV(BuildContext context, List<Map<String, dynamic>> orders) async {
    try {
      final completedOrders = orders.where((o) => o['status'] == 'completed').toList();
      if (completedOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada transaksi selesai untuk diexport')),
        );
        return;
      }

      List<Map<String, dynamic>> enrichedOrders = [];
      for (var order in completedOrders) {
        final customer = await Supabase.instance.client
            .from('profiles')
            .select('name')
            .eq('id', order['customer_id'])
            .maybeSingle();
        final service = await Supabase.instance.client
            .from('services')
            .select('title')
            .eq('id', order['service_id'])
            .maybeSingle();

        enrichedOrders.add({
          'order_id': order['id'],
          'customer_name': customer?['name'] ?? 'Unknown',
          'service_title': service?['title'] ?? 'Unknown',
          'total_price': order['total_price'] ?? 0,
          'schedule': order['schedule'] != null
              ? DateTime.parse(order['schedule']).toLocal().toString()
              : '-',
          'completed_at': order['completed_at'] != null
              ? DateTime.parse(order['completed_at']).toLocal().toString()
              : '-',
        });
      }

      String csv = 'Order ID,Customer Name,Service,Total Price,Schedule,Completed At\n';
      for (var row in enrichedOrders) {
        csv +=
            '${row['order_id']},${row['customer_name']},${row['service_title']},${row['total_price']},${row['schedule']},${row['completed_at']}\n';
      }

      final blob = html.Blob([csv], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'transaksi_japas_${DateTime.now().toIso8601String()}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ File CSV berhasil diunduh!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Gagal export: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Vendor'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () {
              ref.invalidate(vendorOrdersProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔄 Dashboard di-refresh')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppTheme.primary),
            onPressed: () async {
              final orders = ref.read(vendorOrdersProvider).value;
              if (orders != null) {
                await _exportCSV(context, orders);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data belum siap, coba lagi')),
                );
              }
            },
          ),
        ],
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
                onPressed: () => ref.invalidate(vendorOrdersProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (orders) {
          final pendingNow = _pendingCount(orders);

          return Column(
            children: [
              if (pendingNow > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🔔 Ada $pendingNow pesanan baru menunggu konfirmasi!',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
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
                            if (order['status'] == 'completed')
                              FutureBuilder(
                                future: Supabase.instance.client
                                    .from('ratings')
                                    .select('rating, review')
                                    .eq('order_id', order['id'])
                                    .maybeSingle(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const SizedBox.shrink();
                                  }
                                  if (snapshot.hasData && snapshot.data != null) {
                                    final rating = snapshot.data!;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text('${rating['rating']}/5'),
                                          const SizedBox(width: 12),
                                          if (rating['review'] != null && rating['review'].isNotEmpty)
                                            Expanded(
                                              child: Text(
                                                '"${rating['review']}"',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (order['status'] == 'pending')
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await Supabase.instance.client
                                              .from('orders')
                                              .update({'status': 'accepted'})
                                              .eq('id', order['id']);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('✅ Order diterima'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            ref.invalidate(vendorOrdersProvider);
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('❌ Gagal: $e')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Terima'),
                                    ),
                                  ),
                                if (order['status'] == 'pending')
                                  const SizedBox(width: 8),
                                if (order['status'] == 'pending')
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await Supabase.instance.client
                                              .from('orders')
                                              .update({'status': 'cancelled'})
                                              .eq('id', order['id']);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('❌ Order ditolak'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            ref.invalidate(vendorOrdersProvider);
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('❌ Gagal: $e')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                if (order['status'] == 'accepted')
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await Supabase.instance.client
                                              .from('orders')
                                              .update({
                                                'status': 'completed',
                                                'completed_at': DateTime.now().toIso8601String(),
                                              })
                                              .eq('id', order['id']);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('✅ Order selesai!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            ref.invalidate(vendorOrdersProvider);
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('❌ Gagal: $e')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Selesai'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}