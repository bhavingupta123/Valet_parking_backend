import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regNumberController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();

  @override
  void dispose() {
    _regNumberController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _addVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final sessionProvider = context.read<SessionProvider>();
    final success = await sessionProvider.addVehicle(
      registrationNumber: _regNumberController.text.toUpperCase(),
      make: _makeController.text,
      model: _modelController.text,
      color: _colorController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Registration Number
                  TextFormField(
                    controller: _regNumberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                      hintText: 'MH12AB1234',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter registration number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Make
                  TextFormField(
                    controller: _makeController,
                    decoration: const InputDecoration(
                      labelText: 'Make',
                      hintText: 'Honda, Toyota, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle make';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Model
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: 'City, Camry, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle model';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Color
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      hintText: 'White, Black, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.palette),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter vehicle color';
                      }
                      return null;
                    },
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

                  ElevatedButton(
                    onPressed: session.isLoading ? null : _addVehicle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: session.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Vehicle'),
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
