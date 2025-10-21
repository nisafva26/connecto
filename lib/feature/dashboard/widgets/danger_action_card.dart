import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showDeleteAccountSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.tertiary, // your neon card color
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      bool confirmed = false;
      bool loading = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Container(
                  width: 44, height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(100),
                  ),
                ),

                // header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1212),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_forever, color: Color(0xFFFF6B6B), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Delete account?',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // bullets
                _Bullet(text: 'Permanently removes your profile and data.'),
                _Bullet(text: 'All your chats will be lost'),
                _Bullet(text: 'Cancels gatherings you host and removes your invites.'),

                const SizedBox(height: 12),

                // export data (optional action)
                // Align(
                //   alignment: Alignment.centerLeft,
                //   child: TextButton.icon(
                //     style: TextButton.styleFrom(foregroundColor: scheme.primary),
                //     onPressed: () {
                //       HapticFeedback.selectionClick();
                //       // TODO: wire up export flow
                //       ScaffoldMessenger.of(ctx).showSnackBar(
                //         const SnackBar(content: Text('Export coming soon')),
                //       );
                //     },
                //     icon: const Icon(Icons.download),
                //     label: const Text('Export my data (optional)'),
                //   ),
                // ),

                // confirm checkbox
                CheckboxListTile(
                  value: confirmed,
                  onChanged: loading ? null : (v) {
                    HapticFeedback.selectionClick();
                    setState(() => confirmed = v ?? false);
                  },
                  activeColor: const Color(0xFFFF6B6B),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I understand this action cannot be undone.',
                    style: TextStyle(color: Colors.white),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),

                // buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (!confirmed || loading)
                            ? null
                            : () async {
                                HapticFeedback.heavyImpact();
                                setState(() => loading = true);
                                try {
                                  await ref.read(authProvider.notifier)
                                      .deleteAccountFlow(context, ref);
                                  // if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Delete failed: $e')),
                                  );
                                  setState(() => loading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          disabledBackgroundColor: const Color(0x33FF6B6B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: loading
                              ? const SizedBox(
                                  key: ValueKey('prog'),
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Delete',
                                  key: ValueKey('txt'),
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 8.0, top: 6),
          child: Icon(Icons.check_circle, size: 16, color: Colors.white54),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }
}


class DangerActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const DangerActionCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2B0D0D), Color(0xFF1A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBD2D2D).withOpacity(0.35)),
        ),
        child: Row(
          children: const [
            Icon(Icons.delete_forever, color: Color(0xFFFF6B6B)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete account', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 2),
                  Text('Permanently remove your chats and data',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
