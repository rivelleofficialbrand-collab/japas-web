// lib/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLinkSent = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Jika sudah login, tutup halaman
    if (authState.hasValue && authState.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Japas',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLinkSent ? 'Cek email dan klik tombol "Sign in"' : 'Masuk dengan Email',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),

              // Input Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLinkSent, // Nonaktifkan setelah kirim link
                decoration: const InputDecoration(
                  labelText: 'Alamat Email',
                  hintText: 'contoh@email.com',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Pesan sukses kirim link
              if (_isLinkSent)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '✅ Link login sudah dikirim ke ${_emailController.text}.\nCek inbox/spam, lalu klik "Sign in".',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // TOMBOL KIRIM LINK (Primary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (authState.isLoading || _isLinkSent)
                      ? null
                      : () async {
                          if (_emailController.text.isEmpty ||
                              !_emailController.text.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Masukkan email yang valid')),
                            );
                            return;
                          }
                          try {
                            await ref
                                .read(authProvider.notifier)
                                .sendMagicLink(_emailController.text.trim());
                            setState(() => _isLinkSent = true);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: authState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLinkSent ? 'Link Terkirim ✅' : 'Kirim Link Login',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),

// 🔥 TOMBOL DEV LOGIN (BYPASS EMAIL)
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          if (_emailController.text.isEmpty ||
                              !_emailController.text.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Masukkan email yang valid')),
                            );
                            return;
                          }
                          
                          // Tampilkan loading di tombol
                          setState(() {}); // Trigger rebuild (opsional)
                          
                          try {
                            print('🔄 Menekan tombol Dev Login...');
                            await ref
                                .read(authProvider.notifier)
                                .devLogin(_emailController.text.trim());
                            print('✅ Dev Login selesai. State sekarang: ${authState.hasValue}');
                            
                            // Jika sukses, state akan berubah dan halaman otomatis tertutup
                          } catch (e) {
                            print('❌ Dev Login catch: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Dev Login gagal: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flash_on, size: 18),
                            SizedBox(width: 8),
                            Text('⚡ Dev Login (Bypass Email)'),
                          ],
                        ),
                ),
              ),


              // Tombol Kembali (jika sudah kirim link)
              if (_isLinkSent)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _isLinkSent = false);
                      _emailController.clear();
                    },
                    child: const Text('← Gunakan email lain'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}