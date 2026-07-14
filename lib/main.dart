import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = 'http://localhost:8000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KambamApp());
}

class AppColors {
  static const purple = Color(0xFF713897);
  static const deepIndigo = Color(0xFF56108A);
  static const magenta = Color(0xFFDF81DF);
  static const lilac = Color(0xFFF5A8F8);
  static const teal = Color(0xFF0AA09F);
  static const darkTeal = Color(0xFF005C67);
  static const seaGreen = Color(0xFF65BBB0);
  static const mint = Color(0xFFB4E5E1);
  static const background = Color(0xFFF7F5FA);
}

enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get key {
    switch (this) {
      case Priority.low:
        return 'low';
      case Priority.medium:
        return 'medium';
      case Priority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case Priority.low:
        return AppColors.mint;
      case Priority.medium:
        return AppColors.teal;
      case Priority.high:
        return AppColors.deepIndigo;
    }
  }

  static Priority fromKey(String value) {
    return Priority.values.firstWhere((p) => p.key == value, orElse: () => Priority.medium);
  }
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
        return AppColors.purple;
      case TaskStatus.light:
        return AppColors.mint;
      case TaskStatus.important:
        return AppColors.teal;
      case TaskStatus.urgent:
        return AppColors.deepIndigo;
      case TaskStatus.done:
        return AppColors.seaGreen;
    }
  }

  static TaskStatus fromKey(String value) {
    return TaskStatus.values.firstWhere((s) => s.key == value, orElse: () => TaskStatus.backlog);
  }
}

class Subtask {
  Subtask({required this.id, required this.taskId, required this.content});
  final String id;
  final String taskId;
  String content;

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(id: map['id'], taskId: map['task_id'], content: map['content'] ?? '');
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.boardDate,
    required this.subtasks,
  });

  final String id;
  String title;
  Priority priority;
  TaskStatus status;
  DateTime boardDate;
  List<Subtask> subtasks;

  factory Task.fromMap(Map<String, dynamic> map, List<Subtask> subtasks) {
    return Task(
      id: map['id'],
      title: map['title'],
      priority: PriorityX.fromKey(map['priority']),
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

  Future<Task> addTask(String title, Priority priority, TaskStatus status) async {
    final res = await http.post(
      _base.resolve('/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'priority': priority.key,
        'status': status.key,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Task.fromMap(data, []);
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

  Future<Subtask> addSubtask(String taskId, String content) async {
    final res = await http.post(
      _base.resolve('/subtasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'task_id': taskId, 'content': content}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Subtask.fromMap(data);
  }

  Future<void> updateSubtask(String id, String content) async {
    await http.patch(
      _base.resolve('/subtasks/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
    );
  }

  Future<void> deleteSubtask(String id) async {
    await http.delete(_base.resolve('/subtasks/$id'));
  }
}

class KambamApp extends StatelessWidget {
  const KambamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        secondary: AppColors.teal,
      ),
    );

    return MaterialApp(
      title: 'Daily Priorities',
      theme: base.copyWith(
        textTheme: GoogleFonts.figtreeTextTheme(base.textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.deepIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.lilac, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lilac),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.purple, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purple,
            textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.teal,
            textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const BoardPage(),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AddTaskTriangleButton extends StatelessWidget {
  const AddTaskTriangleButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: CustomPaint(size: const Size(32, 28), painter: TrianglePainter()),
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

  List<Task> _tasksFor(TaskStatus status) {
    return tasks.where((t) => t.status == status).toList();
  }

  void _openAddDialog(TaskStatus initialStatus) {
    final titleController = TextEditingController();
    Priority selectedPriority = Priority.medium;
    TaskStatus selectedStatus = initialStatus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'What is on your mind?'),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: Priority.values.map((p) {
                        final selected = p == selectedPriority;
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: selected,
                          selectedColor: p.color.withOpacity(0.35),
                          onSelected: (_) => setDialogState(() => selectedPriority = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskStatus.values.map((s) {
                        final selected = s == selectedStatus;
                        return ChoiceChip(
                          label: Text(s.label),
                          selected: selected,
                          selectedColor: s.accent.withOpacity(0.35),
                          onSelected: (_) => setDialogState(() => selectedStatus = s),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    await repo.addTask(titleController.text.trim(), selectedPriority, selectedStatus);
                    await _refresh();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _addSubtask(Task task) async {
    await repo.addSubtask(task.id, '');
    await _refresh();
  }

  Future<void> _deleteSubtask(Subtask sub) async {
    await repo.deleteSubtask(sub.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Priorities')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
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
      floatingActionButton: AddTaskTriangleButton(onTap: () => _openAddDialog(TaskStatus.backlog)),
    );
  }

  Widget _buildColumn(TaskStatus status) {
    final columnTasks = _tasksFor(status);
    return Container(
      height: 320,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: status.accent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Text(
                status.label,
                style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) => details.data.status != status,
              onAcceptWithDetails: (details) => _moveTask(details.data, status),
              builder: (context, candidateData, rejectedData) {
                final highlighted = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: highlighted ? status.accent.withOpacity(0.08) : null,
                    border: highlighted ? Border.all(color: status.accent, width: 2) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: columnTasks.isEmpty
                      ? Center(
                          child: Text(
                            'Drop tasks here',
                            style: GoogleFonts.figtree(color: AppColors.darkTeal, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: columnTasks.length,
                          itemBuilder: (context, index) {
                            final task = columnTasks[index];
                            return _buildTaskCard(task, status);
                          },
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
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: task.priority.color, radius: 7),
        title: Text(task.title, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(task.priority.label, style: GoogleFonts.figtree(fontSize: 10, color: AppColors.darkTeal)),
        children: [
          ...task.subtasks.map((sub) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: sub.content),
                      maxLines: null,
                      minLines: 2,
                      style: GoogleFonts.figtree(fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Write something...'),
                      onChanged: (value) => sub.content = value,
                      onEditingComplete: () => repo.updateSubtask(sub.id, sub.content),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.purple),
                    onPressed: () => _deleteSubtask(sub),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => _addSubtask(task),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add subtask', style: TextStyle(fontSize: 11)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.deepIndigo),
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
            leading: CircleAvatar(backgroundColor: task.priority.color, radius: 7),
            title: Text(task.title, style: GoogleFonts.figtree(fontSize: 13)),
            subtitle: Text(task.priority.label, style: GoogleFonts.figtree(fontSize: 10)),
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
