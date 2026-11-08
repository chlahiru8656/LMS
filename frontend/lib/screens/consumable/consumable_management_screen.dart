import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ConsumableManagementScreen extends StatefulWidget {
  const ConsumableManagementScreen({super.key});

  @override
  State<ConsumableManagementScreen> createState() => _ConsumableManagementScreenState();
}

class _ConsumableManagementScreenState extends State<ConsumableManagementScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _consumables = [];
  bool _loading = true;
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = _showLowStockOnly
          ? await _api.getLowStockItems()
          : await _api.getAllConsumables();
      setState(() { _consumables = r.data; _loading = false; });
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
                  Text('Consumable Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${_consumables.length} items${_showLowStockOnly ? ' (low stock)' : ''}',
                    style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Low Stock Only'),
                    selected: _showLowStockOnly,
                    onSelected: (v) { setState(() => _showLowStockOnly = v); _load(); },
                    selectedColor: Colors.red[100],
                  ),
                  const SizedBox(width: 12),
                  if (canCreate)
                    ElevatedButton.icon(
                      onPressed: () => _showConsumableDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Consumable'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _consumables.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No consumables found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]))
                : ListView.builder(
                    itemCount: _consumables.length,
                    itemBuilder: (context, i) {
                      final c = _consumables[i];
                      final isLow = (c['current_stock'] ?? 0) <= (c['min_threshold'] ?? 0);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isLow ? Colors.red[100] : Colors.green[100],
                            child: Icon(Icons.inventory_2, color: isLow ? Colors.red : Colors.green),
                          ),
                          title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if (c['category'] != null) c['category'],
                            'Stock: ${c['current_stock']} ${c['unit']}',
                            'Min: ${c['min_threshold']} ${c['unit']}',
                          ].join(' • ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLow) Chip(
                                label: const Text('LOW STOCK', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.red.withValues(alpha: 0.1),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  switch (action) {
                                    case 'usage': _showUsageDialog(c['id'], c['name']); break;
                                    case 'replenish': _showReplenishDialog(c['id'], c['name']); break;
                                    case 'edit': _showConsumableDialog(consumable: c); break;
                                    case 'detail': _showConsumableDetail(c['id']); break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.info, size: 18), SizedBox(width: 8), Text('View Details')])),
                                  const PopupMenuItem(value: 'usage', child: Row(children: [Icon(Icons.remove_circle_outline, size: 18), SizedBox(width: 8), Text('Record Usage')])),
                                  const PopupMenuItem(value: 'replenish', child: Row(children: [Icon(Icons.add_circle_outline, size: 18), SizedBox(width: 8), Text('Replenish')])),
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showConsumableDialog({Map<String, dynamic>? consumable}) {
    final nameCtrl = TextEditingController(text: consumable?['name'] ?? '');
    final catCtrl = TextEditingController(text: consumable?['category'] ?? '');
    final unitCtrl = TextEditingController(text: consumable?['unit'] ?? '');
    final stockCtrl = TextEditingController(text: consumable?['current_stock']?.toString() ?? '0');
    final threshCtrl = TextEditingController(text: consumable?['min_threshold']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(consumable == null ? 'Add Consumable' : 'Edit Consumable'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Aggregate, Chemical', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit *', hintText: 'e.g. kg, L, pcs', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Stock', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: threshCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Threshold', border: OutlineInputBorder()))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || unitCtrl.text.trim().isEmpty) return;
              final data = {
                'name': nameCtrl.text.trim(),
                'category': catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : null,
                'unit': unitCtrl.text.trim(),
                'current_stock': double.tryParse(stockCtrl.text.trim()) ?? 0,
                'min_threshold': double.tryParse(threshCtrl.text.trim()) ?? 0,
              };
              try {
                if (consumable == null) {
                  await _api.createConsumable(data);
                } else {
                  await _api.updateConsumable(consumable['id'], data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(consumable == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showUsageDialog(int consumableId, String name) {
    final qtyCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Usage — $name'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity Used *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose', hintText: 'e.g. Practical session, testing', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.recordUsage(consumableId, {
                  'quantity_used': double.tryParse(qtyCtrl.text.trim()) ?? 0,
                  'usage_date': DateTime.now().toIso8601String().substring(0, 10),
                  'purpose': purposeCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _showReplenishDialog(int consumableId, String name) {
    final qtyCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Replenish — $name'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity Added *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: supplierCtrl,
                decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost (LKR)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _api.recordReplenishment(consumableId, {
                  'quantity_added': double.tryParse(qtyCtrl.text.trim()) ?? 0,
                  'replenishment_date': DateTime.now().toIso8601String().substring(0, 10),
                  'supplier': supplierCtrl.text.trim(),
                  'cost': double.tryParse(costCtrl.text.trim()),
                  'remarks': remarksCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Replenish'),
          ),
        ],
      ),
    );
  }

  void _showConsumableDetail(int id) async {
    try {
      final r = await _api.getConsumableById(id);
      final c = r.data;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 500),
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
                        Expanded(child: Text(c['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(),
                    _detailRow('Category', c['category'] ?? '-'),
                    _detailRow('Unit', c['unit']),
                    _detailRow('Current Stock', '${c['current_stock']} ${c['unit']}'),
                    _detailRow('Min Threshold', '${c['min_threshold']} ${c['unit']}'),

                    if (c['usage_logs'] != null && (c['usage_logs'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Recent Usage', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(c['usage_logs'] as List).take(5).map((u) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        color: Colors.red[50],
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                          title: Text('-${u['quantity_used']} • ${u['purpose'] ?? ''}', style: const TextStyle(fontSize: 13)),
                          trailing: Text(u['usage_date'] ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                      )),
                    ],

                    if (c['replenishments'] != null && (c['replenishments'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Recent Replenishments', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(c['replenishments'] as List).take(5).map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        color: Colors.green[50],
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.add_circle_outline, size: 18, color: Colors.green),
                          title: Text('+${r['quantity_added']} • ${r['supplier'] ?? ''}', style: const TextStyle(fontSize: 13)),
                          trailing: Text(r['replenishment_date'] ?? '', style: const TextStyle(fontSize: 11)),
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
        SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
