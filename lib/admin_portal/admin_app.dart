import 'package:flutter/material.dart';
import 'package:rumblr/admin_portal/views/pending_requests_view.dart';
import 'package:rumblr/admin_portal/views/register_gym_view.dart';
import 'package:rumblr/admin_portal/views/roster_view.dart';
import 'package:rumblr/admin_portal/views/subscription_status_view.dart';
import 'package:rumblr/admin_portal/widgets/gym_selector.dart';
import 'package:rumblr/core/models/fighter_membership.dart';

enum AdminSection {
  registerGym,
  subscription,
  roster,
  requests,
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rumblr Admin Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const _AdminShell(),
    );
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  final ValueNotifier<String?> _selectedGymId = ValueNotifier<String?>(null);
  final ValueNotifier<AdminSection> _section =
      ValueNotifier<AdminSection>(AdminSection.registerGym);

  @override
  void dispose() {
    _selectedGymId.dispose();
    _section.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            ValueListenableBuilder<AdminSection>(
              valueListenable: _section,
              builder: (context, section, _) {
                return NavigationRail(
                  selectedIndex: AdminSection.values.indexOf(section),
                  onDestinationSelected: (index) {
                    _section.value = AdminSection.values[index];
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.apartment),
                      label: Text('Register Gym'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.credit_card),
                      label: Text('Subscription'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.group),
                      label: Text('Roster'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inbox),
                      label: Text('Requests'),
                    ),
                  ],
                );
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GymSelector(
                      selectedGymIdListenable: _selectedGymId,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ValueListenableBuilder<AdminSection>(
                      valueListenable: _section,
                      builder: (context, section, _) {
                        switch (section) {
                          case AdminSection.registerGym:
                            return RegisterGymView(
                              onGymCreated: (gymId) =>
                                  _selectedGymId.value = gymId,
                            );
                          case AdminSection.subscription:
                            return SubscriptionStatusView(
                              selectedGymIdListenable: _selectedGymId,
                            );
                          case AdminSection.roster:
                            return RosterView(
                              selectedGymIdListenable: _selectedGymId,
                            );
                          case AdminSection.requests:
                            return PendingRequestsView(
                              selectedGymIdListenable: _selectedGymId,
                              onMembershipAction: () {
                                // When a request is approved, default roster view may need refresh.
                                setState(() {});
                              },
                            );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
