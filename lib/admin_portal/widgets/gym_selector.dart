import 'package:flutter/material.dart';

class GymSelector extends StatefulWidget {
  const GymSelector({
    super.key,
    required this.selectedGymIdListenable,
  });

  final ValueListenable<String?> selectedGymIdListenable;

  @override
  State<GymSelector> createState() => _GymSelectorState();
}

class _GymSelectorState extends State<GymSelector> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedGymIdListenable.value ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selectedGymIdListenable,
      builder: (context, selectedGymId, _) {
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Active Gym ID',
                  helperText: selectedGymId == null || selectedGymId.isEmpty
                      ? 'Enter or paste a gym document ID to manage.'
                      : 'Managing gym: $selectedGymId',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final trimmed = _controller.text.trim();
                widget.selectedGymIdListenable.value =
                    trimmed.isEmpty ? null : trimmed;
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}
