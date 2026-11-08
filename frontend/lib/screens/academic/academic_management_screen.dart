import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AcademicManagementScreen extends StatefulWidget {
  const AcademicManagementScreen({super.key});

  @override
  State<AcademicManagementScreen> createState() => _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<dynamic> _batches = [];
  List<dynamic> _semesters = [];
  List<dynamic> _courses = [];
  List<dynamic> _practicals = [];
  List<dynamic> _enrollments = [];
  List<dynamic> _allStudents = [];

  int? _selectedBatchId;
  int? _selectedSemesterId;
  int? _selectedCourseId;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBatches();
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getBatches();
      setState(() { _batches = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadSemesters(int batchId) async {
    try {
      final r = await _api.getSemesters(batchId);
      setState(() { _semesters = r.data; _selectedSemesterId = null; _courses = []; _practicals = []; });
    } catch (_) {}
  }

  Future<void> _loadCourses(int semesterId) async {
    try {
      final r = await _api.getCourses(semesterId);
      setState(() { _courses = r.data; _selectedCourseId = null; _practicals = []; });
    } catch (_) {}
  }

  Future<void> _loadPracticals(int courseId) async {
    try {
      final r = await _api.getPracticals(courseId);
      setState(() => _practicals = r.data);
    } catch (_) {}
  }

  Future<void> _loadEnrollments(int courseId) async {
    try {
      final r = await _api.getEnrollments(courseId);
      setState(() => _enrollments = r.data);
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    try {
      final r = await _api.getApprovedStudents();
      setState(() => _allStudents = r.data is List ? r.data : []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Academic Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Manage Batches, Semesters, Courses & Practicals',
            style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.groups), text: 'Batches'),
              Tab(icon: Icon(Icons.date_range), text: 'Semesters'),
              Tab(icon: Icon(Icons.menu_book), text: 'Courses'),
              Tab(icon: Icon(Icons.science), text: 'Practicals'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBatchesTab(),
                _buildSemestersTab(),
                _buildCoursesTab(),
                _buildPracticalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BATCHES TAB
  // ============================================================
  Widget _buildBatchesTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showBatchDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Batch'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _batches.isEmpty
              ? Center(child: Text('No batches yet. Add one to get started.', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, i) {
                    final b = _batches[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${b['year']}'.substring(2))),
                        title: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Year: ${b['year']} • ${b['is_active'] == 1 ? 'Active' : 'Inactive'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Edit',
                              onPressed: () => _showBatchDialog(batch: b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete('batch', b['id'], b['name']),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() => _selectedBatchId = b['id']);
                          _loadSemesters(b['id']);
                          _tabController.animateTo(1);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // SEMESTERS TAB
  // ============================================================
  Widget _buildSemestersTab() {
    return Column(
      children: [
        // Batch selector
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedBatchId,
                decoration: const InputDecoration(
                  labelText: 'Select Batch',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _batches.map<DropdownMenuItem<int>>((b) =>
                  DropdownMenuItem(value: b['id'] as int, child: Text(b['name']))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedBatchId = v);
                    _loadSemesters(v);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _selectedBatchId == null ? null : () => _showSemesterDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Semester'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _selectedBatchId == null
            ? Center(child: Text('Select a batch first', style: TextStyle(color: Colors.grey[500])))
            : _semesters.isEmpty
              ? Center(child: Text('No semesters for this batch', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: _semesters.length,
                  itemBuilder: (context, i) {
                    final s = _semesters[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('S${s['semester_number']}')),
                        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Semester ${s['semester_number']}'),
                        onTap: () {
                          setState(() => _selectedSemesterId = s['id']);
                          _loadCourses(s['id']);
                          _tabController.animateTo(2);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // COURSES TAB
  // ============================================================
  Widget _buildCoursesTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedBatchId,
                decoration: const InputDecoration(labelText: 'Batch', border: OutlineInputBorder(), isDense: true),
                items: _batches.map<DropdownMenuItem<int>>((b) =>
                  DropdownMenuItem(value: b['id'] as int, child: Text(b['name']))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() { _selectedBatchId = v; _selectedSemesterId = null; _courses = []; });
                    _loadSemesters(v);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedSemesterId,
                decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder(), isDense: true),
                items: _semesters.map<DropdownMenuItem<int>>((s) =>
                  DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedSemesterId = v);
                    _loadCourses(v);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _selectedSemesterId == null ? null : () => _showCourseDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Course'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _selectedSemesterId == null
            ? Center(child: Text('Select a batch and semester', style: TextStyle(color: Colors.grey[500])))
            : _courses.isEmpty
              ? Center(child: Text('No courses for this semester', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: _courses.length,
                  itemBuilder: (context, i) {
                    final c = _courses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.menu_book, size: 20, color: Colors.blue),
                        ),
                        title: Text('${c['code']} — ${c['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Coordinator: ${c['coordinator_name'] ?? 'Not assigned'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.people, size: 18),
                              label: const Text('Enroll'),
                              onPressed: () => _showEnrollmentDialog(c['id'], c['code']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward, size: 20),
                              tooltip: 'View Practicals',
                              onPressed: () {
                                setState(() => _selectedCourseId = c['id']);
                                _loadPracticals(c['id']);
                                _tabController.animateTo(3);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // PRACTICALS TAB
  // ============================================================
  Widget _buildPracticalsTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _selectedCourseId != null
                ? Text('Practicals for course',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))
                : Text('Select a course from the Courses tab first',
                    style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton.icon(
              onPressed: _selectedCourseId == null ? null : () => _showPracticalDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Practical'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _selectedCourseId == null
            ? Center(child: Text('Navigate from Courses tab', style: TextStyle(color: Colors.grey[500])))
            : _practicals.isEmpty
              ? Center(child: Text('No practicals for this course', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: _practicals.length,
                  itemBuilder: (context, i) {
                    final p = _practicals[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[100],
                          child: const Icon(Icons.science, size: 20, color: Colors.teal),
                        ),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p['description'] ?? 'No description'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // DIALOGS
  // ============================================================
  void _showBatchDialog({Map<String, dynamic>? batch}) {
    final nameCtrl = TextEditingController(text: batch?['name'] ?? '');
    final yearCtrl = TextEditingController(text: batch?['year']?.toString() ?? DateTime.now().year.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(batch == null ? 'Add Batch' : 'Edit Batch'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Batch Name', hintText: 'e.g. Batch 2023')),
              const SizedBox(height: 12),
              TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Year', hintText: 'e.g. 2023'),
                keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {'name': nameCtrl.text.trim(), 'year': int.tryParse(yearCtrl.text.trim()) ?? DateTime.now().year};
              try {
                if (batch == null) {
                  await _api.createBatch(data);
                } else {
                  await _api.updateBatch(batch['id'], data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadBatches();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(batch == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showSemesterDialog() {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Semester'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Semester Name', hintText: 'e.g. Semester 3')),
              const SizedBox(height: 12),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Semester Number', hintText: 'e.g. 3'),
                keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.createSemester({
                  'batch_id': _selectedBatchId,
                  'name': nameCtrl.text.trim(),
                  'semester_number': int.tryParse(numCtrl.text.trim()) ?? 1,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSemesters(_selectedBatchId!);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCourseDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Course'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Course Code', hintText: 'e.g. CE2201')),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Course Name', hintText: 'e.g. Building Materials')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.createCourse({
                  'semester_id': _selectedSemesterId,
                  'code': codeCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadCourses(_selectedSemesterId!);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showPracticalDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Practical'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Practical Name', hintText: 'e.g. Concrete Mix Design')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the practical session...')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _api.createPractical({
                  'course_id': _selectedCourseId,
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadPracticals(_selectedCourseId!);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEnrollmentDialog(int courseId, String courseCode) async {
    await _loadEnrollments(courseId);
    if (!mounted) return;

    final enrolledIds = _enrollments.map((e) => e['student_id']).toSet();
    final availableStudents = _allStudents.where((s) => !enrolledIds.contains(s['id'])).toList();
    final selected = <int>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Enroll Students — $courseCode'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currently enrolled: ${_enrollments.length} students',
                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                const Divider(),
                Text('Available students (${availableStudents.length}):',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Expanded(
                  child: availableStudents.isEmpty
                    ? Center(child: Text('All approved students are enrolled', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: availableStudents.length,
                        itemBuilder: (context, i) {
                          final s = availableStudents[i];
                          return CheckboxListTile(
                            value: selected.contains(s['id']),
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) { selected.add(s['id']); } else { selected.remove(s['id']); }
                              });
                            },
                            title: Text(s['name']),
                            subtitle: Text('${s['student_staff_id'] ?? ''} • ${s['email']}'),
                            dense: true,
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty ? null : () async {
                try {
                  await _api.bulkEnroll(courseId, selected.toList());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${selected.length} students enrolled successfully')));
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text('Enroll ${selected.length} Students'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String type, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                if (type == 'batch') await _api.deleteBatch(id);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadBatches();
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
}
