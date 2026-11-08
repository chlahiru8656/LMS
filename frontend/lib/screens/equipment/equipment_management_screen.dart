import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class EquipmentManagementScreen extends StatefulWidget {
  const EquipmentManagementScreen({super.key});

  @override
  State<EquipmentManagementScreen> createState() => _EquipmentManagementScreenState();
}

class _EquipmentManagementScreenState extends State<EquipmentManagementScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _equipment = [];
  bool _loading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getAllEquipment(status: _statusFilter);
      setState(() { _equipment = r.data; _loading = false; });
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
                  Text('Equipment Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${_equipment.length} items', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              Row(
                children: [
                  // Status filter
                  DropdownButton<String>(
                    value: _statusFilter,
                    hint: const Text('All Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Status')),
                      DropdownMenuItem(value: 'available', child: Text('Available')),
                      DropdownMenuItem(value: 'in_use', child: Text('In Use')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                      DropdownMenuItem(value: 'out_of_service', child: Text('Out of Service')),
                    ],
                    onChanged: (v) { setState(() => _statusFilter = v); _load(); },
                  ),
                  const SizedBox(width: 12),
                  if (canCreate)
                    ElevatedButton.icon(
                      onPressed: () => _showEquipmentDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Equipment'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _equipment.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.build_circle, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No equipment found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]))
                : ListView.builder(
                    itemCount: _equipment.length,
                    itemBuilder: (context, i) {
                      final eq = _equipment[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(eq['status']).withValues(alpha: 0.15),
                            child: Icon(Icons.build, color: _statusColor(eq['status'])),
                          ),
                          title: Text(eq['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if (eq['model'] != null) 'Model: ${eq['model']}',
                            if (eq['serial_number'] != null) 'S/N: ${eq['serial_number']}',
                            if (eq['location_in_lab'] != null) eq['location_in_lab'],
                          ].join(' • ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (eq['approval_status'] == 'pending')
                                Chip(
                                  label: const Text('PENDING', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                ),
                              if (eq['next_calibration_due'] != null)
                                Tooltip(
                                  message: 'Next calibration: ${eq['next_calibration_due']}',
                                  child: Icon(Icons.warning_amber, size: 20, color: Colors.amber[700]),
                                ),
                              const SizedBox(width: 4),
                              _statusChip(eq['status']),
                            ],
                          ),
                          onTap: () => _showEquipmentDetail(eq['id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'in_use': return Colors.blue;
      case 'maintenance': return Colors.orange;
      case 'out_of_service': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _statusChip(String? status) {
    return Chip(
      label: Text((status ?? 'unknown').toUpperCase(),
        style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.bold)),
      backgroundColor: _statusColor(status).withValues(alpha: 0.1),
    );
  }

  void _showEquipmentDialog({Map<String, dynamic>? equipment}) {
    final nameCtrl = TextEditingController(text: equipment?['name'] ?? '');
    final modelCtrl = TextEditingController(text: equipment?['model'] ?? '');
    final serialCtrl = TextEditingController(text: equipment?['serial_number'] ?? '');
    final mfrCtrl = TextEditingController(text: equipment?['manufacturer'] ?? '');
    final locCtrl = TextEditingController(text: equipment?['location_in_lab'] ?? '');
    final descCtrl = TextEditingController(text: equipment?['description'] ?? '');
    String status = equipment?['status'] ?? 'available';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(equipment == null ? 'Add Equipment' : 'Edit Equipment'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: serialCtrl, decoration: const InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: mfrCtrl, decoration: const InputDecoration(labelText: 'Manufacturer', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location in Lab', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'available', child: Text('Available')),
                      DropdownMenuItem(value: 'in_use', child: Text('In Use')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Under Maintenance')),
                      DropdownMenuItem(value: 'out_of_service', child: Text('Out of Service')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final data = {
                  'name': nameCtrl.text.trim(),
                  'model': modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,
                  'serial_number': serialCtrl.text.trim().isNotEmpty ? serialCtrl.text.trim() : null,
                  'manufacturer': mfrCtrl.text.trim().isNotEmpty ? mfrCtrl.text.trim() : null,
                  'location_in_lab': locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : null,
                  'status': status,
                  'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                };
                try {
                  if (equipment == null) {
                    await _api.createEquipment(data);
                  } else {
                    await _api.updateEquipment(equipment['id'], data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(equipment == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentDetail(int id) async {
    try {
      final r = await _api.getEquipmentById(id);
      final eq = r.data;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
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
                        Expanded(child: Text(eq['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(),
                    if (eq['model'] != null) _detailRow('Model', eq['model']),
                    if (eq['serial_number'] != null) _detailRow('Serial Number', eq['serial_number']),
                    if (eq['manufacturer'] != null) _detailRow('Manufacturer', eq['manufacturer']),
                    if (eq['location_in_lab'] != null) _detailRow('Location', eq['location_in_lab']),
                    _detailRow('Status', (eq['status'] ?? '').toUpperCase()),
                    if (eq['next_calibration_due'] != null) _detailRow('Next Calibration', eq['next_calibration_due']),
                    if (eq['description'] != null) _detailRow('Description', eq['description']),

                    const SizedBox(height: 16),
                    // Action buttons
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () { Navigator.pop(ctx); _showMaintenanceDialog(id); },
                        icon: const Icon(Icons.handyman, size: 18),
                        label: const Text('Log Maintenance'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () { Navigator.pop(ctx); _showCalibrationDialog(id); },
                        icon: const Icon(Icons.verified, size: 18),
                        label: const Text('Log Calibration'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () { Navigator.pop(ctx); _showEquipmentDialog(equipment: eq); },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                    ]),

                    // Maintenance history
                    if (eq['maintenance_logs'] != null && (eq['maintenance_logs'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Recent Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(eq['maintenance_logs'] as List).take(5).map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        color: Colors.grey[50],
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.handyman, size: 18),
                          title: Text(m['maintenance_type'] ?? '', style: const TextStyle(fontSize: 13)),
                          subtitle: Text(m['description'] ?? ''),
                          trailing: Text(m['maintenance_date'] ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                    ],

                    // Calibration history
                    if (eq['calibrations'] != null && (eq['calibrations'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Recent Calibrations', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(eq['calibrations'] as List).take(5).map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        color: Colors.blue[50],
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.verified, size: 18, color: Colors.blue),
                          title: Text('Calibrated: ${c['calibration_date']}', style: const TextStyle(fontSize: 13)),
                          subtitle: Text('Next due: ${c['next_due_date']}'),
                          trailing: Text(c['certificate_number'] ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  void _showMaintenanceDialog(int equipmentId) {
    final descCtrl = TextEditingController();
    final performedCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    String type = 'routine';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Maintenance'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'routine', child: Text('Routine')),
                    DropdownMenuItem(value: 'preventive', child: Text('Preventive')),
                    DropdownMenuItem(value: 'corrective', child: Text('Corrective')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: performedCtrl, decoration: const InputDecoration(labelText: 'Performed By', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost (LKR)', border: OutlineInputBorder()))),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.logMaintenance(equipmentId, {
                    'maintenance_type': type,
                    'maintenance_date': DateTime.now().toIso8601String().substring(0, 10),
                    'description': descCtrl.text.trim(),
                    'performed_by': performedCtrl.text.trim(),
                    'cost': double.tryParse(costCtrl.text.trim()),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalibrationDialog(int equipmentId) {
    final performedCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    DateTime nextDue = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Calibration'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
                  title: const Text('Next Due Date'),
                  subtitle: Text('${nextDue.day}/${nextDue.month}/${nextDue.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: nextDue, firstDate: DateTime.now(), lastDate: DateTime(2035));
                    if (d != null) setDialogState(() => nextDue = d);
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: performedCtrl, decoration: const InputDecoration(labelText: 'Performed By', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Certificate No.', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: remarksCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.logCalibration(equipmentId, {
                    'calibration_date': DateTime.now().toIso8601String().substring(0, 10),
                    'next_due_date': '${nextDue.year}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}',
                    'performed_by': performedCtrl.text.trim(),
                    'certificate_number': certCtrl.text.trim(),
                    'remarks': remarksCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
