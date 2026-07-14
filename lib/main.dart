import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = 'http://localhost:8000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyPrioritiesApp());
}

class AppColors {
  static const gradientStart = Color(0xFFFFB73C);
  static const gradientMid = Color(0xFFFE696C);
  static const gradientEnd = Color(0xFFFF2F57);
  static const backlogDot = Color(0xFFFF6B2C);
  static const doneDot = Color(0xFFD63AF0);
  static const urgentDot = Color(0xFFFF2D55);
  static const lightDot = Color(0xFFFFB020);
  static const importantDot = Color(0xFFFF4D97);
}

enum TaskStatus { backlog, light, important, urgent, done }

extension TaskStatusX on TaskStatus {
  String get key {
    switch (this) {
      case TaskStatus.backlog:
        return 'backlog';
      case TaskStatus.light:
        return 'light';
      case TaskStatus.important:
        return 'important';
      case TaskStatus.urgent:
        return 'urgent';
      case TaskStatus.done:
        return 'done';
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.backlog:
        return 'Backlog';
      case TaskStatus.light:
        return 'Light';
      case TaskStatus.important:
        return 'Important';
      case TaskStatus.urgent:
        return 'Urgent';
      case TaskStatus.done:
        return 'Done';
    }
  }

  Color get accent {
    switch (this) {
      case TaskStatus.backlog:
        return AppColors.backlogDot;
      case TaskStatus.light:
        return AppColors.lightDot;
      case TaskStatus.important:
        return AppColors.importantDot;
      case TaskStatus.urgent:
        return AppColors.urgentDot;
      case TaskStatus.done:
        return AppColors.doneDot;
    }
  }

  static TaskStatus fromKey(String value) {
    return TaskStatus.values.firstWhere((s) => s.key == value, orElse: () => TaskStatus.backlog);
  }
}

const importanceOptions = [TaskStatus.light, TaskStatus.important, TaskStatus.urgent];

class Subtask {
  Subtask({required this.id, required this.taskId, required this.content});
  final String id;
  final String taskId;
  final String content;

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(id: map['id'], taskId: map['task_id'] ?? '', content: map['content'] ?? '');
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.status,
    required this.boardDate,
    required this.subtasks,
  });

  final String id;
  String title;
  String notes;
  TaskStatus status;
  DateTime boardDate;
  List<Subtask> subtasks;

  factory Task.fromMap(Map<String, dynamic> map, List<Subtask> subtasks) {
    return Task(
      id: map['id'],
      title: map['title'],
      notes: map['notes'] ?? '',
      status: TaskStatusX.fromKey(map['status']),
      boardDate: DateTime.parse(map['board_date']),
      subtasks: subtasks,
    );
  }
}

class BoardRepository {
  final Uri _base = Uri.parse(apiBaseUrl);

  Future<void> rollover() async {
    await http.post(_base.resolve('/rollover'));
  }

  Future<List<Task>> fetchBoard() async {
    final res = await http.get(_base.resolve('/tasks'));
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((json) {
      final subs = (json['subtasks'] as List)
          .map((s) => Subtask.fromMap(s as Map<String, dynamic>))
          .toList();
      return Task.fromMap(json as Map<String, dynamic>, subs);
    }).toList();
  }

  Future<void> addTaskWithSubtasks({
    required String title,
    required String notes,
    required TaskStatus status,
    required List<String> subtaskContents,
  }) async {
    await http.post(
      _base.resolve('/tasks/with-subtasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'notes': notes,
        'status': status.key,
        'subtasks': subtaskContents,
      }),
    );
  }

  Future<void> deleteTask(String id) async {
    await http.delete(_base.resolve('/tasks/$id'));
  }

  Future<void> updateStatus(String id, TaskStatus status) async {
    await http.patch(
      _base.resolve('/tasks/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status.key}),
    );
  }
}

class DailyPrioritiesApp extends StatelessWidget {
  const DailyPrioritiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.urgentDot);
    return MaterialApp(
      title: 'Daily Priorities',
      theme: base.copyWith(textTheme: GoogleFonts.figtreeTextTheme(base.textTheme)),
      home: const BoardPage(),
    );
  }
}

class OutlineCircleButton extends StatelessWidget {
  const OutlineCircleButton({super.key, required this.onTap, this.size = 64, this.strokeWidth = 2.5});
  final VoidCallback onTap;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: strokeWidth),
          ),
        ),
      ),
    );
  }
}

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final repo = BoardRepository();
  List<Task> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await repo.rollover();
    await _refresh();
  }

  Future<void> _refresh() async {
    final result = await repo.fetchBoard();
    setState(() {
      tasks = result;
      loading = false;
    });
  }

  List<Task> _tasksFor(TaskStatus status) => tasks.where((t) => t.status == status).toList();

  Future<void> _openAddScreen(TaskStatus initialStatus) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(repo: repo, initialStatus: initialStatus)),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _deleteTask(Task task) async {
    await repo.deleteTask(task.id);
    await _refresh();
  }

  Future<void> _moveTask(Task task, TaskStatus status) async {
    if (task.status == status) return;
    setState(() => task.status = status);
    await repo.updateStatus(task.id, status);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Daily Priorities', style: GoogleFonts.figtree(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildColumn(TaskStatus.backlog)),
                    Expanded(child: _buildColumn(TaskStatus.done)),
                  ],
                ),
                _buildColumn(TaskStatus.urgent),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildColumn(TaskStatus.light)),
                    Expanded(child: _buildColumn(TaskStatus.important)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: OutlineCircleButton(onTap: () => _openAddScreen(TaskStatus.light)),
    );
  }

  Widget _buildColumn(TaskStatus status) {
    final columnTasks = _tasksFor(status);
    return Container(
      height: 320,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: status.accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(status.label, style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                  child: Text('${columnTasks.length}', style: GoogleFonts.figtree(color: Colors.white, fontSize: 12)),
                ),
                const Spacer(),
                OutlineCircleButton(size: 26, strokeWidth: 1.5, onTap: () => _openAddScreen(status)),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) => details.data.status != status,
              onAcceptWithDetails: (details) => _moveTask(details.data, status),
              builder: (context, candidateData, rejectedData) {
                final highlighted = candidateData.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: highlighted ? 0.18 : 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: columnTasks.isEmpty
                      ? Center(
                          child: Text('Drop tasks here', style: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: columnTasks.length,
                          itemBuilder: (context, index) => _buildTaskCard(columnTasks[index], status),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, TaskStatus status) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: task.status.accent, radius: 7),
        title: Text(task.title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
        children: [
          if (task.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(task.notes, style: GoogleFonts.figtree(fontSize: 12)),
              ),
            ),
          if (task.subtasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: task.subtasks.map((s) {
                  return Row(
                    children: [
                      const Icon(Icons.circle, size: 5),
                      const SizedBox(width: 6),
                      Expanded(child: Text(s.content, style: GoogleFonts.figtree(fontSize: 12))),
                    ],
                  );
                }).toList(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.urgentDot),
                onPressed: () => _deleteTask(task),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );

    final preview = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 240,
        child: Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: task.status.accent, radius: 7),
            title: Text(task.title, style: GoogleFonts.figtree(fontSize: 13)),
          ),
        ),
      ),
    );

    return LongPressDraggable<Task>(
      data: task,
      feedback: preview,
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, required this.repo, required this.initialStatus});
  final BoardRepository repo;
  final TaskStatus initialStatus;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleController = TextEditingController();
  final notesController = TextEditingController();
  final subtaskController = TextEditingController();
  final List<String> subtasks = [];
  late TaskStatus selectedStatus;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedStatus = importanceOptions.contains(widget.initialStatus) ? widget.initialStatus : TaskStatus.light;
  }

  void _addSubtaskToList() {
    final text = subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      subtasks.add(text);
      subtaskController.clear();
    });
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty) return;
    setState(() => saving = true);
    await widget.repo.addTaskWithSubtasks(
      title: titleController.text.trim(),
      notes: notesController.text.trim(),
      status: selectedStatus,
      subtaskContents: subtasks,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('New task', style: GoogleFonts.figtree(fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Task name', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: GoogleFonts.figtree(color: Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'What is on your mind?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Importance', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TaskStatus>(
                      value: selectedStatus,
                      isExpanded: true,
                      items: importanceOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.label, style: GoogleFonts.figtree()));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => selectedStatus = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Notes', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 5,
                  style: GoogleFonts.figtree(color: Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Write anything...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Subtasks', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subtaskController,
                        style: GoogleFonts.figtree(color: Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Add a subtask',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _addSubtaskToList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlineCircleButton(size: 44, strokeWidth: 2, onTap: _addSubtaskToList),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: subtasks.asMap().entries.map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.circle, size: 6, color: Colors.white),
                      title: Text(entry.value, style: GoogleFonts.figtree(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.white),
                        onPressed: () => setState(() => subtasks.removeAt(entry.key)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.urgentDot,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save', style: GoogleFonts.figtree(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
