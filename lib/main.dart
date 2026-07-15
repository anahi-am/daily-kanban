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
  static const gradientMid = Color(0xFFFF4D97);
  static const gradientEnd = Color(0xFFFF69B4);
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
        title: Text('Daily Priorities', style: GoogleFonts.figtree(fontWeight: FontWeight.w800, color: Colors.white)),
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
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildColumn(TaskStatus.done)),
                        Expanded(child: _buildColumn(TaskStatus.urgent)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildColumn(TaskStatus.light)),
                        Expanded(child: _buildColumn(TaskStatus.important)),
                      ],
                    ),
                    _buildColumn(TaskStatus.backlog),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 12,
                child: OutlineCircleButton(onTap: () => _openAddScreen(TaskStatus.light)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(TaskStatus status) {
    final columnTasks = _tasksFor(status);
    return Container(
      height: 300,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: [
                Text(status.label, style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                  child: Text('${columnTasks.length}', style: GoogleFonts.figtree(color: Colors.white, fontSize: 10)),
                ),
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
                  margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: highlighted ? 0.18 : 0.1),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: columnTasks.isEmpty
                      ? Center(
                          child: Text('Drop here', style: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(4),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
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
    final card = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: task.status.accent, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (task.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.notes,
              style: GoogleFonts.figtree(fontSize: 9, color: Colors.white70),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (task.subtasks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${task.subtasks.length} subtask${task.subtasks.length > 1 ? 's' : ''}',
              style: GoogleFonts.figtree(fontSize: 8, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );

    final preview = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 140,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Text(task.title, style: GoogleFonts.figtree(fontSize: 11, color: Colors.white)),
        ),
      ),
    );

    return GestureDetector(
      onLongPress: () => _deleteTask(task),
      child: LongPressDraggable<Task>(
        data: task,
        feedback: preview,
        childWhenDragging: Opacity(opacity: 0.2, child: card),
        child: card,
      ),
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
                  style: GoogleFonts.figtree(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    hintText: 'What is on your mind?',
                    hintStyle: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Importance', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TaskStatus>(
                      value: selectedStatus,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFCC4477),
                      items: importanceOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.label, style: GoogleFonts.figtree(color: Colors.white)));
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
                  style: GoogleFonts.figtree(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    hintText: 'Write anything...',
                    hintStyle: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.5)),
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
                        style: GoogleFonts.figtree(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.15),
                          hintText: 'Add a subtask',
                          hintStyle: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.5)),
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
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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
