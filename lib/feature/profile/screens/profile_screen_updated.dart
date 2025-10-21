import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:connecto/feature/dashboard/screens/access_request_admin.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/dashboard/widgets/danger_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



class ProfileScreenUpdated extends ConsumerWidget {
  const ProfileScreenUpdated({super.key});

  // admins
  final Set<String> adminPhones = const {
    '+971559533272',
    '+916282745946',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final accessRequestsAsync = ref.watch(adminNotificationsProvider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          final isAdmin = adminPhones.contains(user.phoneNumber);

          final initials = user.fullName
              .split(' ')
              .where((s) => s.isNotEmpty)
              .map((s) => s[0])
              .take(2)
              .join()
              .toUpperCase();

          return SafeArea(
            child: LayoutBuilder(
              builder: (ctx, c) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== Header =====
                      _HeaderCard(
                        initials: initials,
                        name: user.fullName,
                        gender: user.gender,
                        phone: user.phoneNumber,
                      ),
                      const SizedBox(height: 16),

                      // ===== Stats =====
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              label: 'Friends',
                              value: '${user.friends.length}',
                              icon: Icons.people_alt_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Expanded(
                          //   child: _StatPill(
                          //     label: 'Gatherings',
                          //     value: '${user.gatherings?.length ?? 0}',
                          //     icon: Icons.event_outlined,
                          //   ),
                          // ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ===== Info list =====
                      _InfoTile(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: user.phoneNumber,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Gender',
                        value: user.gender,
                      ),

                      const SizedBox(height: 20),

                      // ===== Admin Card (conditional) =====
                      if (isAdmin) _AdminCard(accessRequestsAsync: accessRequestsAsync),

                      // ===== Account group =====
                      const SizedBox(height: 20),
                      _SectionLabel('Account'),
                      const SizedBox(height: 12),
                      DangerActionCard(
                        onTap: () => showDeleteAccountSheet(context, ref),
                      ),

                      const SizedBox(height: 28),

                      // ===== Logout CTA =====
                      _LogoutButton(onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(authProvider.notifier).logout(ref, context);
                      }),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ----------------- Widgets -----------------

class _HeaderCard extends StatelessWidget {
  final String initials;
  final String name;
  final String gender;
  final String phone;
  const _HeaderCard({
    required this.initials,
    required this.name,
    required this.gender,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF082824), Color(0xFF041614)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // avatar with glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: scheme.tertiary,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(gender, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        phone,
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatPill({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF03FFE2)),
          const SizedBox(width: 10),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              )),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends ConsumerWidget {
  final AsyncValue<List<dynamic>> accessRequestsAsync; // adjust to your type
  const _AdminCard({required this.accessRequestsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/profile/admin-access-requests'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.tertiary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF03FFE2)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("User Access Requests",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  accessRequestsAsync.when(
                    data: (reqs) => Text(
                      "${reqs.length} pending",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    loading: () => const Text("Loading…",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    error: (e, _) => const Text("Error",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: .3),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout, color: Colors.black),
        label: const Text(
          'Logout',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff03FFE2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
