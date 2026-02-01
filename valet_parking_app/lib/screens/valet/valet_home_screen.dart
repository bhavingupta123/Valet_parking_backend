import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../history_screen.dart';
import 'create_session_screen.dart';
import 'verify_otp_screen.dart';

class ValetHomeScreen extends StatefulWidget {
  const ValetHomeScreen({super.key});

  @override
  State<ValetHomeScreen> createState() => _ValetHomeScreenState();
}

class _ValetHomeScreenState extends State<ValetHomeScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<SessionProvider>().refreshAllActiveSessions();
      }
    });
  }

  Future<void> _loadData() async {
    final sessionProvider = context.read<SessionProvider>();
    await sessionProvider.loadAllActiveSessions();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valet Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) {
          // Separate sessions by status
          final pickupRequests = session.allActiveSessions
              .where((s) => s.status == SessionStatus.requested ||
                  s.status == SessionStatus.moving ||
                  s.status == SessionStatus.available)
              .toList();

          final parkedVehicles = session.allActiveSessions
              .where((s) => s.status == SessionStatus.parked ||
                  s.status == SessionStatus.pending)
              .toList();

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hello, ${auth.user?.name ?? 'Valet'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _ActionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Park Vehicle',
                    subtitle: 'Create new parking session',
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateSessionScreen(),
                      ),
                    ).then((_) => _loadData()),
                  ),

                  const SizedBox(height: 24),

                  // Pickup Requests Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pickup Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pickupRequests.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pickupRequests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (session.isLoading && session.allActiveSessions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (pickupRequests.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.grey[400]),
                            const SizedBox(width: 12),
                            const Text(
                              'No pickup requests',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...pickupRequests.map(
                      (pickup) => _PickupCard(
                        pickup: pickup,
                        onStatusChanged: (status) async {
                          final success = await session.updateSessionStatus(pickup.id, status);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Status updated to $status')),
                            );
                          }
                        },
                        onDeliver: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VerifyOTPScreen(session: pickup),
                          ),
                        ).then((_) => _loadData()),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // All Parked Vehicles Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parked Vehicles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (parkedVehicles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${parkedVehicles.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (parkedVehicles.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.local_parking, color: Colors.grey[400]),
                            const SizedBox(width: 12),
                            const Text(
                              'No parked vehicles',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...parkedVehicles.map(
                      (vehicle) => _ParkedVehicleCard(session: vehicle),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ParkedVehicleCard extends StatelessWidget {
  final ParkingSession session;

  const _ParkedVehicleCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isPending = session.status == SessionStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 50,
              decoration: BoxDecoration(
                color: isPending ? Colors.orange : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            // Vehicle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.vehicle != null)
                    Text(
                      session.vehicle!.registrationNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (session.vehicle != null)
                    Text(
                      '${session.vehicle!.make} ${session.vehicle!.model}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  if (session.customer != null)
                    Text(
                      session.customer!.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPending ? Colors.orange : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPending ? 'PENDING' : 'PARKED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final ParkingSession pickup;
  final Function(String) onStatusChanged;
  final VoidCallback onDeliver;

  const _PickupCard({
    required this.pickup,
    required this.onStatusChanged,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(pickup.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pickup.statusText.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (pickup.customer != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        pickup.customer!.phone,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Vehicle Info
            if (pickup.vehicle != null) ...[
              Text(
                pickup.vehicle!.registrationNumber,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${pickup.vehicle!.make} ${pickup.vehicle!.model} - ${pickup.vehicle!.color}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],

            if (pickup.customer != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    pickup.customer!.name,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),

            // Status Update Buttons
            const Text(
              'Update Status:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: 'Moving',
                    icon: Icons.directions_car,
                    color: Colors.orange,
                    isSelected: pickup.status == SessionStatus.moving,
                    onTap: () => onStatusChanged('moving'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: 'Ready',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    isSelected: pickup.status == SessionStatus.available,
                    onTap: () => onStatusChanged('available'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Deliver Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDeliver,
                icon: const Icon(Icons.key),
                label: const Text('Verify OTP & Deliver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.requested:
        return Colors.purple;
      case SessionStatus.moving:
        return Colors.orange;
      case SessionStatus.available:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
