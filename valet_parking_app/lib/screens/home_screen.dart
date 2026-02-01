import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import 'add_vehicle_screen.dart';
import 'history_screen.dart';
import 'valet/valet_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        context.read<SessionProvider>().refreshActiveSession();
      }
    });
  }

  Future<void> _loadData() async {
    final sessionProvider = context.read<SessionProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.isCustomer) {
      await sessionProvider.loadActiveSession();
      await sessionProvider.loadVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isValet) {
      return const ValetHomeScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valet Parking'),
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
          if (session.isLoading && session.activeSession == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hello, ${auth.user?.name ?? 'Customer'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Active Session Card
                  if (session.activeSession != null) ...[
                    _ActiveSessionCard(
                      session: session.activeSession!,
                      pickupOtp: session.pickupOtp,
                      onRequestPickup: () async {
                        final success = await session.requestPickup();
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pickup requested!')),
                          );
                        }
                      },
                      onAccept: () async {
                        final success = await session.acceptParking();
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Parking accepted!')),
                          );
                        }
                      },
                      onReject: () async {
                        final success = await session.rejectParking();
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Parking rejected')),
                          );
                        }
                      },
                      onCancelPickup: () async {
                        final success = await session.cancelPickup();
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pickup cancelled')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No active parking session',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your car will appear here when parked by a valet',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Vehicles Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Vehicles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddVehicleScreen(),
                          ),
                        ).then((_) => session.loadVehicles()),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (session.vehicles.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.car_rental,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text('No vehicles registered'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddVehicleScreen(),
                                ),
                              ).then((_) => session.loadVehicles()),
                              child: const Text('Add Vehicle'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...session.vehicles.map(
                      (vehicle) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.directions_car),
                          ),
                          title: Text(vehicle.registrationNumber),
                          subtitle: Text('${vehicle.make} ${vehicle.model} - ${vehicle.color}'),
                        ),
                      ),
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

class _ActiveSessionCard extends StatelessWidget {
  final ParkingSession session;
  final String? pickupOtp;
  final VoidCallback onRequestPickup;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancelPickup;

  const _ActiveSessionCard({
    required this.session,
    required this.pickupOtp,
    required this.onRequestPickup,
    required this.onAccept,
    required this.onReject,
    required this.onCancelPickup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_parking,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Active Parking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Vehicle Info
            if (session.vehicle != null) ...[
              Text(
                session.vehicle!.registrationNumber,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${session.vehicle!.make} ${session.vehicle!.model}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Ticket: ${session.ticketNumber}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              'Venue: ${session.venueName}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 16),

            // Pending Acceptance UI
            if (session.status == SessionStatus.pending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Valet wants to park your car',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Accept to confirm the parking session',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Status Progress (only show after accepted)
              _StatusProgress(currentStatus: session.status),

              const SizedBox(height: 16),

              // OTP Display (when pickup requested)
              if (pickupOtp != null || session.status == SessionStatus.requested ||
                  session.status == SessionStatus.moving ||
                  session.status == SessionStatus.available) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Pickup OTP',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickupOtp ?? session.pickupOtp ?? '------',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Show this to the valet when receiving your car',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Cancel pickup button
                if (session.status == SessionStatus.requested ||
                    session.status == SessionStatus.moving) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onCancelPickup,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Pickup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ] else if (session.status == SessionStatus.parked) ...[
                // Request Pickup Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRequestPickup,
                    icon: const Icon(Icons.car_rental),
                    label: const Text('Request Pickup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusProgress extends StatelessWidget {
  final SessionStatus currentStatus;

  const _StatusProgress({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StatusStep(
        icon: Icons.local_parking,
        label: 'Parked',
        isActive: true,
        isCompleted: _isAfter(currentStatus, SessionStatus.parked),
      ),
      _StatusStep(
        icon: Icons.notifications,
        label: 'Requested',
        isActive: _isAtOrAfter(currentStatus, SessionStatus.requested),
        isCompleted: _isAfter(currentStatus, SessionStatus.requested),
      ),
      _StatusStep(
        icon: Icons.directions_car,
        label: 'Moving',
        isActive: _isAtOrAfter(currentStatus, SessionStatus.moving),
        isCompleted: _isAfter(currentStatus, SessionStatus.moving),
      ),
      _StatusStep(
        icon: Icons.check_circle,
        label: 'Ready',
        isActive: _isAtOrAfter(currentStatus, SessionStatus.available),
        isCompleted: currentStatus == SessionStatus.delivered,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(child: steps[i]),
              if (i < steps.length - 1)
                Container(
                  height: 2,
                  width: 20,
                  color: steps[i].isCompleted ? Colors.green : Colors.grey[300],
                ),
            ],
          ],
        ),
      ],
    );
  }

  bool _isAtOrAfter(SessionStatus current, SessionStatus target) {
    final order = [
      SessionStatus.pending,
      SessionStatus.parked,
      SessionStatus.requested,
      SessionStatus.moving,
      SessionStatus.available,
      SessionStatus.delivered,
    ];
    final currentIndex = order.indexOf(current);
    final targetIndex = order.indexOf(target);
    if (currentIndex == -1 || targetIndex == -1) return false;
    return currentIndex >= targetIndex;
  }

  bool _isAfter(SessionStatus current, SessionStatus target) {
    final order = [
      SessionStatus.pending,
      SessionStatus.parked,
      SessionStatus.requested,
      SessionStatus.moving,
      SessionStatus.available,
      SessionStatus.delivered,
    ];
    final currentIndex = order.indexOf(current);
    final targetIndex = order.indexOf(target);
    if (currentIndex == -1 || targetIndex == -1) return false;
    return currentIndex > targetIndex;
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? Colors.green
        : isActive
            ? Theme.of(context).primaryColor
            : Colors.grey[400];

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : (isActive ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.grey[200]),
            shape: BoxShape.circle,
            border: Border.all(color: color!, width: 2),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
