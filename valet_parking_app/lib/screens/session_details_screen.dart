import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    await context.read<SessionProvider>().loadActiveSession();
  }

  Future<void> _requestPickup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Pickup'),
        content: const Text(
          'Are you sure you want to request your car? '
          'You will receive an OTP to share with the valet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<SessionProvider>().requestPickup();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup requested! Check your OTP.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSession,
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, sessionProvider, _) {
          final session = sessionProvider.activeSession;

          if (sessionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (session == null) {
            return const Center(child: Text('Session not found'));
          }

          return RefreshIndicator(
            onRefresh: _loadSession,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header
                  _StatusHeader(session: session),
                  const SizedBox(height: 24),

                  // OTP Display (if requested)
                  if (sessionProvider.pickupOtp != null ||
                      session.status == SessionStatus.requested) ...[
                    _OTPCard(otp: sessionProvider.pickupOtp ?? session.pickupOtp),
                    const SizedBox(height: 24),
                  ],

                  // Vehicle Details
                  _SectionCard(
                    title: 'Vehicle Details',
                    icon: Icons.directions_car,
                    children: [
                      _DetailRow(
                        label: 'Registration',
                        value: session.vehicle?.registrationNumber ?? 'N/A',
                      ),
                      _DetailRow(
                        label: 'Make & Model',
                        value: session.vehicle != null
                            ? '${session.vehicle!.make} ${session.vehicle!.model}'
                            : 'N/A',
                      ),
                      _DetailRow(
                        label: 'Color',
                        value: session.vehicle?.color ?? 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ticket Details
                  _SectionCard(
                    title: 'Ticket Details',
                    icon: Icons.confirmation_number,
                    children: [
                      _DetailRow(
                        label: 'Ticket Number',
                        value: session.ticketNumber,
                      ),
                      _DetailRow(
                        label: 'Venue',
                        value: session.venueName,
                      ),
                      _DetailRow(
                        label: 'Parked At',
                        value: _formatDateTime(session.parkedAt),
                      ),
                      if (session.requestedAt != null)
                        _DetailRow(
                          label: 'Requested At',
                          value: _formatDateTime(session.requestedAt!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Valet Details
                  if (session.valet != null)
                    _SectionCard(
                      title: 'Valet Details',
                      icon: Icons.badge,
                      children: [
                        _DetailRow(
                          label: 'Name',
                          value: session.valet!.name,
                        ),
                        _DetailRow(
                          label: 'Phone',
                          value: session.valet!.phone,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Action Button
                  if (session.status == SessionStatus.parked)
                    ElevatedButton(
                      onPressed: _requestPickup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Request Pickup'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusHeader extends StatelessWidget {
  final ParkingSession session;

  const _StatusHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getStatusColor(session.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(session.status),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(session.status),
            size: 48,
            color: _getStatusColor(session.status),
          ),
          const SizedBox(height: 8),
          Text(
            session.statusText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(session.status),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.pending:
        return Colors.orange;
      case SessionStatus.parked:
        return Colors.blue;
      case SessionStatus.moving:
        return Colors.orange;
      case SessionStatus.available:
        return Colors.green;
      case SessionStatus.requested:
        return Colors.purple;
      case SessionStatus.inTransit:
        return Colors.indigo;
      case SessionStatus.delivered:
        return Colors.teal;
      case SessionStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SessionStatus status) {
    switch (status) {
      case SessionStatus.pending:
        return Icons.hourglass_empty;
      case SessionStatus.parked:
        return Icons.local_parking;
      case SessionStatus.moving:
        return Icons.directions_car;
      case SessionStatus.available:
        return Icons.check_circle_outline;
      case SessionStatus.requested:
        return Icons.notifications_active;
      case SessionStatus.inTransit:
        return Icons.directions_car;
      case SessionStatus.delivered:
        return Icons.check_circle;
      case SessionStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class _OTPCard extends StatelessWidget {
  final String? otp;

  const _OTPCard({this.otp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'Your Pickup OTP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            otp ?? '------',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this OTP with the valet to receive your car',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
