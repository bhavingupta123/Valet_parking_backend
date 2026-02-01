import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/vehicle.dart';
import '../../providers/session_provider.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _regNumberController = TextEditingController();
  final _venueController = TextEditingController();

  Vehicle? _foundVehicle;
  User? _foundOwner;
  bool _searched = false;

  @override
  void dispose() {
    _regNumberController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _searchVehicle() async {
    if (_regNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter registration number')),
      );
      return;
    }

    final sessionProvider = context.read<SessionProvider>();
    final result = await sessionProvider.searchVehicle(
      _regNumberController.text.toUpperCase(),
    );

    setState(() {
      _searched = true;
      if (result != null) {
        _foundVehicle = Vehicle.fromJson(result['vehicle']);
        _foundOwner = User.fromJson(result['owner']);
      } else {
        _foundVehicle = null;
        _foundOwner = null;
      }
    });
  }

  Future<void> _createSession() async {
    if (_foundVehicle == null || _foundOwner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search for a valid vehicle first')),
      );
      return;
    }

    if (_venueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter venue name')),
      );
      return;
    }

    final sessionProvider = context.read<SessionProvider>();
    final success = await sessionProvider.createSession(
      vehicleId: _foundVehicle!.id,
      customerId: _foundOwner!.id,
      venueName: _venueController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking session created successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Park Vehicle'),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Vehicle
                const Text(
                  'Step 1: Find Vehicle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _regNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number',
                          hintText: 'MH12AB1234',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: session.isLoading ? null : _searchVehicle,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Search Results
                if (_searched) ...[
                  if (_foundVehicle != null && _foundOwner != null) ...[
                    Card(
                      color: Colors.green.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Vehicle Found',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Registration',
                              value: _foundVehicle!.registrationNumber,
                            ),
                            _DetailRow(
                              label: 'Vehicle',
                              value: '${_foundVehicle!.make} ${_foundVehicle!.model}',
                            ),
                            _DetailRow(
                              label: 'Color',
                              value: _foundVehicle!.color,
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Owner',
                              value: _foundOwner!.name,
                            ),
                            _DetailRow(
                              label: 'Phone',
                              value: _foundOwner!.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      color: Colors.red.withOpacity(0.1),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vehicle not found. Ask the customer to register their vehicle first.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                if (_foundVehicle != null) ...[
                  const SizedBox(height: 24),

                  // Venue Input
                  const Text(
                    'Step 2: Enter Venue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue Name',
                      hintText: 'Taj Hotel Mumbai',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (session.error != null) ...[
                    Text(
                      session.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create Button
                  ElevatedButton(
                    onPressed: session.isLoading ? null : _createSession,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: session.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Parking Session'),
                  ),
                ],
              ],
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
