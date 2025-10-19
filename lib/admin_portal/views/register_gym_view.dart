import 'package:flutter/material.dart';
import 'package:rumblr/core/services/gym_portal_service.dart';

class RegisterGymView extends StatefulWidget {
  const RegisterGymView({super.key, this.onGymCreated});

  final ValueChanged<String>? onGymCreated;

  @override
  State<RegisterGymView> createState() => _RegisterGymViewState();
}

class _RegisterGymViewState extends State<RegisterGymView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _regionController = TextEditingController();
  final _primaryEmblemController = TextEditingController();
  final _emblemsController = TextEditingController();
  final _ownerIdController = TextEditingController();

  final GymPortalService _gymPortalService = GymPortalService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _regionController.dispose();
    _primaryEmblemController.dispose();
    _emblemsController.dispose();
    _ownerIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ownerId = _ownerIdController.text.trim();
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim().isEmpty
        ? null
        : _slugController.text.trim();
    final region = _regionController.text.trim().isEmpty
        ? null
        : _regionController.text.trim();
    final primaryEmblem = _primaryEmblemController.text.trim().isEmpty
        ? null
        : _primaryEmblemController.text.trim();
    final emblems = _emblemsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    try {
      setState(() => _isSubmitting = true);
      final gym = await _gymPortalService.createGym(
        ownerUserId: ownerId,
        name: name,
        slug: slug,
        region: region,
        primaryEmblemUrl: primaryEmblem,
        emblemUrls: emblems,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gym "${gym.name}" created. ID: ${gym.id}')),
      );
      widget.onGymCreated?.call(gym.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create gym: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register a Gym',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Provide basic gym information. The emblem URLs can be uploaded separately to Cloud Storage and pasted here for now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Gym Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerIdController,
                decoration: const InputDecoration(
                  labelText: 'Owner User ID',
                  helperText:
                      'Firebase Auth UID of the gym admin. You can add more admins later.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(
                  labelText: 'Slug (optional)',
                  helperText: 'Used for vanity URLs in the future.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(
                  labelText: 'Region (optional)',
                  helperText: 'E.g., San Francisco Bay Area.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primaryEmblemController,
                decoration: const InputDecoration(
                  labelText: 'Primary Emblem URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emblemsController,
                decoration: const InputDecoration(
                  labelText: 'Additional Emblem URLs (comma separated)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSubmitting ? 'Creating...' : 'Create Gym'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
