import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../constants/app_constants.dart';
import '../academic/academic_management_screen.dart';
import '../equipment/equipment_management_screen.dart';
import '../consumable/consumable_management_screen.dart';
import '../booking/create_booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.science_outlined, size: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConstants.appName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(AppConstants.labName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          Chip(
            avatar: const Icon(Icons.person, size: 18),
            label: Text(_roleLabel(auth.userRole), style: const TextStyle(fontSize: 12)),
            backgroundColor: _roleColor(auth.userRole).withValues(alpha: 0.15),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, size: 32),
            onSelected: (value) {
              if (value == 'logout') auth.logout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(auth.user?['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_roleLabel(auth.userRole), style: TextStyle(fontSize: 11, color: _roleColor(auth.userRole))),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('Logout')])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Side navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const SizedBox(height: 8),
            destinations: _buildNavDestinations(auth.userRole),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Content
          Expanded(
            child: _buildContent(auth.userRole),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildNavDestinations(String role) {
    List<NavigationRailDestination> destinations = [
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Bookings')),
    ];

    if (role == 'master_admin') {
      destinations.addAll([
        const NavigationRailDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: Text('Users')),
        const NavigationRailDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: Text('Academic')),
        const NavigationRailDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: Text('Equipment')),
        const NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Consumables')),
      ]);
    }

    if (role == 'lab_incharge' || role == 'lab_to' || role == 'lab_assistant') {
      destinations.addAll([
        const NavigationRailDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: Text('Equipment')),
        const NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Consumables')),
      ]);
    }

    return destinations;
  }

  Widget _buildContent(String role) {
    switch (role) {
      case 'master_admin':
        return _buildAdminContent();
      case 'course_coordinator':
        return _buildCoordinatorContent();
      case 'instructor':
        return _buildInstructorContent();
      case 'lab_incharge':
      case 'lab_to':
      case 'lab_assistant':
        return _buildLabStaffContent();
      case 'student':
        return _buildStudentContent();
      default:
        return const Center(child: Text('Unknown role'));
    }
  }

  Widget _buildAdminContent() {
    switch (_selectedIndex) {
      case 0: return const _DashboardHome();
      case 1: return const _BookingListView();
      case 2: return const _UserManagementView();
      case 3: return const AcademicManagementScreen();
      case 4: return const EquipmentManagementScreen();
      case 5: return const ConsumableManagementScreen();
      default: return const _DashboardHome();
    }
  }

  Widget _buildCoordinatorContent() {
    switch (_selectedIndex) {
      case 0: return const _DashboardHome();
      case 1: return const _BookingListView();
      default: return const _DashboardHome();
    }
  }

  Widget _buildInstructorContent() {
    switch (_selectedIndex) {
      case 0: return const _DashboardHome();
      case 1: return const _InstructorScheduleView();
      default: return const _DashboardHome();
    }
  }

  Widget _buildLabStaffContent() {
    switch (_selectedIndex) {
      case 0: return const _DashboardHome();
      case 1: return const _BookingListView();
      case 2: return const EquipmentManagementScreen();
      case 3: return const ConsumableManagementScreen();
      default: return const _DashboardHome();
    }
  }

  Widget _buildStudentContent() {
    switch (_selectedIndex) {
      case 0: return const _DashboardHome();
      case 1: return const _LabAvailabilityView();
      default: return const _DashboardHome();
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'master_admin': return 'Master Admin';
      case 'course_coordinator': return 'Course Coordinator';
      case 'instructor': return 'Instructor';
      case 'lab_incharge': return 'Lab Incharge';
      case 'lab_to': return 'Lab TO';
      case 'lab_assistant': return 'Lab Assistant';
      case 'student': return 'Student';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'master_admin': return Colors.red;
      case 'course_coordinator': return Colors.blue;
      case 'instructor': return Colors.teal;
      case 'lab_incharge': return Colors.green;
      case 'lab_to': return Colors.orange;
      case 'lab_assistant': return Colors.purple;
      case 'student': return Colors.indigo;
      default: return Colors.grey;
    }
  }
}

// ============================================================
// DASHBOARD HOME (with live stats)
// ============================================================
class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final r = await _api.getDashboardSummary();
      setState(() { _stats = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${auth.userName}!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${AppConstants.labName} — ${AppConstants.department}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 32),

          // Quick stats cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(icon: Icons.calendar_today, label: "Today's Bookings",
                value: _loading ? '...' : '${_stats['todays_bookings'] ?? 0}', color: Colors.blue),
              _StatCard(icon: Icons.pending_actions, label: 'Pending Requests',
                value: _loading ? '...' : '${_stats['pending_requests'] ?? 0}', color: Colors.orange),
              _StatCard(icon: Icons.build_circle, label: 'Equipment',
                value: _loading ? '...' : '${_stats['total_equipment'] ?? 0}', color: Colors.green),
              _StatCard(icon: Icons.inventory_2, label: 'Low Stock Items',
                value: _loading ? '...' : '${_stats['low_stock_items'] ?? 0}', color: Colors.red),
            ],
          ),

          const SizedBox(height: 32),
          if (auth.userStatus == 'pending')
            Card(
              color: Colors.amber[50],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.hourglass_top, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(child: Text('Your account is pending admin approval. Some features may be restricted.',
                    style: TextStyle(color: Colors.amber))),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOOKING LIST VIEW
// ============================================================
class _BookingListView extends StatefulWidget {
  const _BookingListView();
  @override State<_BookingListView> createState() => _BookingListViewState();
}

class _BookingListViewState extends State<_BookingListView> {
  final ApiService _api = ApiService();
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final auth = context.read<AuthProvider>();
      final response = auth.isCourseCoordinator
          ? await _api.getMyBookingRequests()
          : await _api.getAllBookingRequests();
      setState(() { _bookings = response.data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Booking Requests', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (context.read<AuthProvider>().isCourseCoordinator)
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CreateBookingScreen(onSuccess: _loadBookings),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Booking'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _bookings.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No booking requests yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]))
                : ListView.builder(
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final b = _bookings[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: _statusIcon(b['status']),
                          title: Text(b['practical_name'] ?? 'Booking #${b['id']}'),
                          subtitle: Text('${b['course_code']} • ${b['booking_date']} • ${b['start_time']}-${b['end_time']}${b['group_name'] != null ? ' • ${b['group_name']}' : ''}'),
                          trailing: _statusChip(b['status']),
                          onTap: () => _showBookingDetail(context, b['id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'pending': return const Icon(Icons.hourglass_top, color: Colors.orange);
      case 'to_reviewed': return const Icon(Icons.comment, color: Colors.blue);
      case 'approved': return const Icon(Icons.check_circle, color: Colors.green);
      case 'rejected': return const Icon(Icons.cancel, color: Colors.red);
      default: return const Icon(Icons.help_outline);
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'to_reviewed': color = Colors.blue; break;
      case 'approved': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Chip(
      label: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  void _showBookingDetail(BuildContext context, int id) async {
    try {
      final response = await _api.getBookingById(id);
      final booking = response.data;
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => _BookingDetailDialog(booking: booking, api: _api, onUpdate: _loadBookings),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading booking: $e')));
      }
    }
  }
}

// ============================================================
// BOOKING DETAIL DIALOG
// ============================================================
class _BookingDetailDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final ApiService api;
  final VoidCallback onUpdate;

  const _BookingDetailDialog({required this.booking, required this.api, required this.onUpdate});

  @override
  State<_BookingDetailDialog> createState() => _BookingDetailDialogState();
}

class _BookingDetailDialogState extends State<_BookingDetailDialog> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final auth = context.read<AuthProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Booking #${b['id']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),

                // Info rows
                _infoRow('Practical', b['practical_name']),
                _infoRow('Course', '${b['course_code']} - ${b['course_name']}'),
                _infoRow('Batch', b['batch_name']),
                _infoRow('Date', '${b['booking_date']}'),
                _infoRow('Time', '${b['start_time']} - ${b['end_time']}'),
                if (b['group_name'] != null) _infoRow('Group', b['group_name']),
                _infoRow('Requested By', b['requested_by_name']),
                _infoRow('Instructor', b['instructor_name']),
                _infoRow('Status', b['status'].toString().toUpperCase()),
                _infoRow('Students', '${(b['students'] as List?)?.length ?? 0} enrolled'),

                // Comments section
                const SizedBox(height: 16),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (b['comments'] != null && (b['comments'] as List).isNotEmpty)
                  ...((b['comments'] as List).map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(c['commenter_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('(${c['commenter_role']})', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          Text(c['comment']),
                          Text(c['created_at'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  )))
                else
                  Text('No comments yet', style: TextStyle(color: Colors.grey[400])),

                // Add comment (TO / Assistant / Incharge)
                if (auth.isLabTO || auth.isLabAssistant || auth.isLabIncharge) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a comment about equipment readiness, consumable availability...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_commentController.text.trim().isEmpty) return;
                      try {
                        await widget.api.addBookingComment(b['id'], _commentController.text.trim());
                        _commentController.clear();
                        widget.onUpdate();
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Add Comment'),
                  ),
                ],

                // Approve / Reject (Incharge only)
                if (auth.isLabIncharge && b['status'] != 'approved' && b['status'] != 'rejected') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            try {
                              await widget.api.updateBookingStatus(b['id'], 'approved');
                              widget.onUpdate();
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () async {
                            try {
                              await widget.api.updateBookingStatus(b['id'], 'rejected');
                              widget.onUpdate();
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ============================================================
// USER MANAGEMENT VIEW
// ============================================================
class _UserManagementView extends StatefulWidget {
  const _UserManagementView();
  @override State<_UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<_UserManagementView> {
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _api.getAllUsers();
      setState(() { _users = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_users.where((u) => u['status'] == 'pending').length} pending approvals', style: TextStyle(color: Colors.orange[700])),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, i) {
                final u = _users[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u['name'][0])),
                    title: Text(u['name']),
                    subtitle: Text('${u['email']} • ${u['student_staff_id'] ?? ''} • ${u['role']}'),
                    trailing: u['status'] == 'pending'
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), tooltip: 'Approve',
                              onPressed: () async { await _api.updateUserStatus(u['id'], 'approved'); _load(); }),
                            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), tooltip: 'Reject',
                              onPressed: () async { await _api.updateUserStatus(u['id'], 'rejected'); _load(); }),
                          ])
                        : Chip(label: Text(u['status'].toUpperCase(), style: TextStyle(fontSize: 11, color: u['status'] == 'approved' ? Colors.green : Colors.red))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INSTRUCTOR SCHEDULE VIEW
// ============================================================
class _InstructorScheduleView extends StatefulWidget {
  const _InstructorScheduleView();
  @override State<_InstructorScheduleView> createState() => _InstructorScheduleViewState();
}

class _InstructorScheduleViewState extends State<_InstructorScheduleView> {
  final ApiService _api = ApiService();
  List<dynamic> _schedule = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _api.getMySchedule();
      setState(() { _schedule = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Schedule', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _schedule.isEmpty
                ? Center(child: Text('No scheduled sessions', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    itemCount: _schedule.length,
                    itemBuilder: (context, i) {
                      final s = _schedule[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.event, color: Colors.teal),
                          title: Text(s['practical_name']),
                          subtitle: Text('${s['course_code']} • ${s['booking_date']} • ${s['start_time']}-${s['end_time']}'),
                          trailing: s['group_name'] != null ? Chip(label: Text(s['group_name'])) : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LAB AVAILABILITY VIEW (for students)
// ============================================================
class _LabAvailabilityView extends StatefulWidget {
  const _LabAvailabilityView();
  @override State<_LabAvailabilityView> createState() => _LabAvailabilityViewState();
}

class _LabAvailabilityViewState extends State<_LabAvailabilityView> {
  final ApiService _api = ApiService();
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _slots = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final r = await _api.getLabAvailability(dateStr);
      setState(() { _slots = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BML Availability', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) { _selectedDate = d; _load(); }
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator())
          else if (_slots.isEmpty)
            Card(color: Colors.green[50], child: const Padding(padding: EdgeInsets.all(16),
              child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('All time slots are available on this date')])))
          else
            ...(_slots.map((s) => Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text('${s['start_time']} - ${s['end_time']}'),
                trailing: const Chip(label: Text('BOOKED', style: TextStyle(color: Colors.red, fontSize: 11))),
              ),
            ))),
        ],
      ),
    );
  }
}
