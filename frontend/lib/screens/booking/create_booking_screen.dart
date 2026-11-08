import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class CreateBookingScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const CreateBookingScreen({super.key, required this.onSuccess});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final ApiService _api = ApiService();
  int _currentStep = 0;

  // Step 1: Academic selection
  List<dynamic> _batches = [];
  List<dynamic> _semesters = [];
  List<dynamic> _courses = [];
  List<dynamic> _practicals = [];

  int? _selectedBatchId;
  int? _selectedSemesterId;
  int? _selectedCourseId;
  int? _selectedPracticalId;
  String? _selectedPracticalName;

  // Step 2: Schedule
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  final _groupNameCtrl = TextEditingController();

  // Step 3: Instructor
  List<dynamic> _instructors = [];
  int? _selectedInstructorId;
  String? _selectedInstructorName;

  // Step 4: Students (auto-populated)
  List<dynamic> _enrolledStudents = [];

  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadInstructors();
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    try {
      final r = await _api.getBatches();
      setState(() => _batches = r.data);
    } catch (_) {}
  }

  Future<void> _loadInstructors() async {
    try {
      final r = await _api.getUsersByRole('instructor');
      setState(() => _instructors = r.data is List ? r.data : []);
    } catch (_) {}
  }

  Future<void> _onBatchSelected(int? batchId) async {
    if (batchId == null) return;
    setState(() {
      _selectedBatchId = batchId;
      _selectedSemesterId = null;
      _selectedCourseId = null;
      _selectedPracticalId = null;
      _semesters = [];
      _courses = [];
      _practicals = [];
    });
    try {
      final r = await _api.getSemesters(batchId);
      setState(() => _semesters = r.data);
    } catch (_) {}
  }

  Future<void> _onSemesterSelected(int? semId) async {
    if (semId == null) return;
    setState(() {
      _selectedSemesterId = semId;
      _selectedCourseId = null;
      _selectedPracticalId = null;
      _courses = [];
      _practicals = [];
    });
    try {
      final r = await _api.getCourses(semId);
      setState(() => _courses = r.data);
    } catch (_) {}
  }

  Future<void> _onCourseSelected(int? courseId) async {
    if (courseId == null) return;
    setState(() {
      _selectedCourseId = courseId;
      _selectedPracticalId = null;
      _practicals = [];
    });
    try {
      final r = await _api.getPracticals(courseId);
      setState(() => _practicals = r.data);
    } catch (_) {}
  }

  Future<void> _loadEnrolledStudents() async {
    if (_selectedCourseId == null) return;
    setState(() => _loading = true);
    try {
      final r = await _api.getEnrollments(_selectedCourseId!);
      setState(() { _enrolledStudents = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _submitBooking() async {
    setState(() => _submitting = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
      final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

      await _api.createBooking({
        'practical_id': _selectedPracticalId,
        'instructor_id': _selectedInstructorId,
        'booking_date': dateStr,
        'start_time': startStr,
        'end_time': endStr,
        'group_name': _groupNameCtrl.text.trim().isNotEmpty ? _groupNameCtrl.text.trim() : null,
      });

      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request created successfully!'), backgroundColor: Colors.green));
        widget.onSuccess();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Booking Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),

              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Step content
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),

              // Navigation buttons
              const SizedBox(height: 16),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Academic', 'Schedule', 'Instructor', 'Review'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Expanded(
          child: Row(
            children: [
              if (i > 0) Expanded(child: Container(height: 2, color: isDone ? Colors.green : Colors.grey[300])),
              CircleAvatar(
                radius: 14,
                backgroundColor: isDone ? Colors.green : isActive ? Theme.of(context).primaryColor : Colors.grey[300],
                child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('${i + 1}', style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.grey[600])),
              ),
              if (i < steps.length - 1) Expanded(child: Container(height: 2, color: isDone ? Colors.green : Colors.grey[300])),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildAcademicStep();
      case 1: return _buildScheduleStep();
      case 2: return _buildInstructorStep();
      case 3: return _buildReviewStep();
      default: return const SizedBox();
    }
  }

  // ============================================================
  // STEP 1: Academic Selection
  // ============================================================
  Widget _buildAcademicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select the practical to book', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),

        // Batch dropdown
        DropdownButtonFormField<int>(
          value: _selectedBatchId,
          decoration: const InputDecoration(labelText: 'Batch *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups)),
          items: _batches.map<DropdownMenuItem<int>>((b) =>
            DropdownMenuItem(value: b['id'] as int, child: Text(b['name']))).toList(),
          onChanged: _onBatchSelected,
        ),
        const SizedBox(height: 16),

        // Semester dropdown
        DropdownButtonFormField<int>(
          value: _selectedSemesterId,
          decoration: const InputDecoration(labelText: 'Semester *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.date_range)),
          items: _semesters.map<DropdownMenuItem<int>>((s) =>
            DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))).toList(),
          onChanged: _onSemesterSelected,
        ),
        const SizedBox(height: 16),

        // Course dropdown
        DropdownButtonFormField<int>(
          value: _selectedCourseId,
          decoration: const InputDecoration(labelText: 'Course *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.menu_book)),
          items: _courses.map<DropdownMenuItem<int>>((c) =>
            DropdownMenuItem(value: c['id'] as int, child: Text('${c['code']} — ${c['name']}'))).toList(),
          onChanged: _onCourseSelected,
        ),
        const SizedBox(height: 16),

        // Practical dropdown
        DropdownButtonFormField<int>(
          value: _selectedPracticalId,
          decoration: const InputDecoration(labelText: 'Practical *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.science)),
          items: _practicals.map<DropdownMenuItem<int>>((p) =>
            DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))).toList(),
          onChanged: (v) {
            setState(() {
              _selectedPracticalId = v;
              _selectedPracticalName = _practicals.firstWhere((p) => p['id'] == v)['name'];
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // STEP 2: Schedule
  // ============================================================
  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set date, time and group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),

        // Date picker
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
          leading: const Icon(Icons.calendar_today, color: Colors.blue),
          title: const Text('Booking Date'),
          subtitle: Text(DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _selectedDate = d);
          },
        ),
        const SizedBox(height: 16),

        // Time pickers
        Row(
          children: [
            Expanded(
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
                leading: const Icon(Icons.access_time, color: Colors.green),
                title: const Text('Start Time'),
                subtitle: Text(_startTime.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _startTime);
                  if (t != null) setState(() => _startTime = t);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
                leading: const Icon(Icons.access_time_filled, color: Colors.orange),
                title: const Text('End Time'),
                subtitle: Text(_endTime.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _endTime);
                  if (t != null) setState(() => _endTime = t);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Group name
        TextField(
          controller: _groupNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Group Name (optional)',
            hintText: 'e.g. Group A, Group B',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.group_work),
          ),
        ),
        const SizedBox(height: 8),
        Text('If you have multiple groups, create a separate booking for each group.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
      ],
    );
  }

  // ============================================================
  // STEP 3: Instructor
  // ============================================================
  Widget _buildInstructorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select an instructor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),
        _instructors.isEmpty
          ? Center(child: Text('No instructors registered in the system', style: TextStyle(color: Colors.grey[500])))
          : Column(
              children: _instructors.map<Widget>((inst) {
                final isSelected = _selectedInstructorId == inst['id'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!, width: isSelected ? 2 : 1),
                  ),
                  color: isSelected ? Colors.blue[50] : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                      child: Icon(Icons.person, color: isSelected ? Colors.white : Colors.grey),
                    ),
                    title: Text(inst['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(inst['email']),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                    onTap: () {
                      setState(() {
                        _selectedInstructorId = inst['id'];
                        _selectedInstructorName = inst['name'];
                      });
                    },
                  ),
                );
              }).toList(),
            ),
      ],
    );
  }

  // ============================================================
  // STEP 4: Review
  // ============================================================
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review & Submit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _reviewRow(Icons.science, 'Practical', _selectedPracticalName ?? '-'),
                const Divider(),
                _reviewRow(Icons.calendar_today, 'Date', DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate)),
                const Divider(),
                _reviewRow(Icons.access_time, 'Time', '${_startTime.format(context)} — ${_endTime.format(context)}'),
                if (_groupNameCtrl.text.trim().isNotEmpty) ...[
                  const Divider(),
                  _reviewRow(Icons.group_work, 'Group', _groupNameCtrl.text.trim()),
                ],
                const Divider(),
                _reviewRow(Icons.person, 'Instructor', _selectedInstructorName ?? '-'),
                const Divider(),
                _reviewRow(Icons.people, 'Students', _loading ? 'Loading...' : '${_enrolledStudents.length} auto-enrolled'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Card(
          color: Colors.blue[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Students will be auto-populated from course enrollment. '
                  'After submission, Lab TO and Lab Assistant can add comments, '
                  'and Lab Incharge will approve or reject.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ============================================================
  // NAVIGATION BUTTONS
  // ============================================================
  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep--),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
          )
        else
          const SizedBox(),

        if (_currentStep < 3)
          ElevatedButton.icon(
            onPressed: _canProceed() ? () {
              if (_currentStep == 2) _loadEnrolledStudents(); // Load students before review
              setState(() => _currentStep++);
            } : null,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Next'),
          )
        else
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submitBooking,
            icon: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
            label: Text(_submitting ? 'Submitting...' : 'Submit Booking'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
      ],
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _selectedPracticalId != null;
      case 1: return true;
      case 2: return _selectedInstructorId != null;
      default: return true;
    }
  }
}
