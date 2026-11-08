import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CleaningScheduleScreen extends StatefulWidget {
  const CleaningScheduleScreen({super.key});

  @override
  State<CleaningScheduleScreen> createState() => _CleaningScheduleScreenState();
}

class _CleaningScheduleScreenState extends State<CleaningScheduleScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<dynamic> _schedules = [];
  List<dynamic> _logs = [];
  List<dynamic> _overdue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getCleaningSchedules(),
        _api.getCleaningLogs(),
        _api.getOverdueCleaningTasks(),
      ]);
      setState(() {
        _schedules = results[0].data;
        _logs = results[1].data;
        _overdue = results[2].data;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final canCreate = auth.isMasterAdmin || auth.isLabIncharge || auth.isLabTO || auth.isLabAssistant;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cleaning Schedule',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  if (_overdue.isNotEmpty)
                    Text('${_overdue.length} overdue tasks', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500)),
                ],
              ),
              if (canCreate)
                ElevatedButton.icon(
                  onPressed: () => _showScheduleDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Schedule'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              const Tab(icon: Icon(Icons.schedule), text: 'Schedules'),
              Tab(icon: const Icon(Icons.history), text: 'Logs (${_logs.length})'),
              Tab(
                icon: Badge(
                  isLabelVisible: _overdue.isNotEmpty,
                  label: Text('${_overdue.length}'),
                  child: const Icon(Icons.warning_amber),
                ),
                text: 'Overdue',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSchedulesTab(),
                    _buildLogsTab(),
                    _buildOverdueTab(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCHEDULES TAB
  // ============================================================
  Widget _buildSchedulesTab() {
    if (_schedules.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cleaning_services, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No cleaning schedules yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      ]));
    }

    return ListView.builder(
      itemCount: _schedules.length,
      itemBuilder: (context, i) {
        final s = _schedules[i];
        final isEquipment = s['equipment_id'] != null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEquipment ? Colors.blue[100] : Colors.green[100],
              child: Icon(
                isEquipment ? Icons.build : Icons.cleaning_services,
                color: isEquipment ? Colors.blue : Colors.green,
              ),
            ),
            title: Text(s['task_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              _frequencyLabel(s['frequency']),
              if (isEquipment) 'Equipment: ${s['equipment_name'] ?? 'N/A'}',
              if (s['assigned_to'] != null) 'Assigned: ${s['assigned_to']}',
              if (s['scheduled_time'] != null) 'Time: ${s['scheduled_time']}',
            ].join(' • ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    _frequencyLabel(s['frequency']),
                    style: TextStyle(fontSize: 10, color: _frequencyColor(s['frequency']), fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _frequencyColor(s['frequency']).withValues(alpha: 0.1),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Mark Complete',
                  onPressed: () => _showCompletionDialog(s['id'], s['task_name']),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _showScheduleDialog(schedule: s);
                    if (action == 'delete') _confirmDelete(s['id'], s['task_name']);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOGS TAB
  // ============================================================
  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return Center(child: Text('No cleaning logs yet', style: TextStyle(color: Colors.grey[500])));
    }

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, i) {
        final log = _logs[i];
        final isCompleted = log['status'] == 'completed';
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          color: isCompleted ? Colors.green[50] : (log['status'] == 'missed' ? Colors.red[50] : null),
          child: ListTile(
            leading: Icon(
              isCompleted ? Icons.check_circle : (log['status'] == 'missed' ? Icons.cancel : Icons.pending),
              color: isCompleted ? Colors.green : (log['status'] == 'missed' ? Colors.red : Colors.orange),
            ),
            title: Text(log['task_name'] ?? 'Schedule #${log['schedule_id']}', style: const TextStyle(fontSize: 14)),
            subtitle: Text('Scheduled: ${log['scheduled_date']}${log['completed_by'] != null ? ' • By: ${log['completed_by']}' : ''}'),
            trailing: Chip(
              label: Text(
                (log['status'] ?? 'pending').toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : (log['status'] == 'missed' ? Colors.red : Colors.orange)),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OVERDUE TAB
  // ============================================================
  Widget _buildOverdueTab() {
    if (_overdue.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
        const SizedBox(height: 16),
        Text('No overdue tasks! Everything is up to date.', style: TextStyle(color: Colors.green[700], fontSize: 16)),
      ]));
    }

    return ListView.builder(
      itemCount: _overdue.length,
      itemBuilder: (context, i) {
        final o = _overdue[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.red[50],
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(o['task_name'] ?? 'Overdue Task', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Was due: ${o['scheduled_date']}'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => _showCompletionDialog(o['schedule_id'], o['task_name'] ?? ''),
              child: const Text('Complete Now'),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DIALOGS
  // ============================================================
  void _showScheduleDialog({Map<String, dynamic>? schedule}) {
    final nameCtrl = TextEditingController(text: schedule?['task_name'] ?? '');
    final descCtrl = TextEditingController(text: schedule?['description'] ?? '');
    final assignedCtrl = TextEditingController(text: schedule?['assigned_to'] ?? '');
    String frequency = schedule?['frequency'] ?? 'weekly';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(schedule == null ? 'Add Cleaning Schedule' : 'Edit Schedule'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Task Name *', hintText: 'e.g. Floor cleaning, Equipment wipe-down', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (v) => setDialogState(() => frequency = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: assignedCtrl,
                  decoration: const InputDecoration(labelText: 'Assigned To', hintText: 'e.g. Lab attendant name', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final data = {
                  'task_name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  'frequency': frequency,
                  'assigned_to': assignedCtrl.text.trim().isNotEmpty ? assignedCtrl.text.trim() : null,
                };
                try {
                  if (schedule == null) {
                    await _api.createCleaningSchedule(data);
                  } else {
                    await _api.updateCleaningSchedule(schedule['id'], data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(schedule == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionDialog(int scheduleId, String taskName) {
    final remarksCtrl = TextEditingController();
    final completedByCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete: $taskName'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: completedByCtrl,
                decoration: const InputDecoration(labelText: 'Completed By', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: remarksCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _api.logCleaningCompletion(scheduleId, {
                  'completed_by': completedByCtrl.text.trim(),
                  'remarks': remarksCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleaning task marked as complete!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _api.deleteCleaningSchedule(id);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _frequencyLabel(String? freq) {
    switch (freq) {
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      case 'custom': return 'Custom';
      default: return freq ?? '';
    }
  }

  Color _frequencyColor(String? freq) {
    switch (freq) {
      case 'daily': return Colors.blue;
      case 'weekly': return Colors.green;
      case 'monthly': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
