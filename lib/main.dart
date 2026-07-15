import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  theme = prefs.getBool('cool_theme') == true ? AppColors.cool : AppColors.warm;
  runApp(const DailyPrioritiesApp());
}

_ThemeColors theme = AppColors.warm;

class AppColors {
  static const warm = _ThemeColors(
    gradientStart: Color(0xFFFFB73C),
    gradientMid: Color(0xFFFF4D97),
    gradientEnd: Color(0xFFFF69B4),
    backlogDot: Color(0xFFFF6B2C),
    doneDot: Color(0xFFD63AF0),
    urgentDot: Color(0xFFFF2D55),
    lightDot: Color(0xFFFFB020),
    importantDot: Color(0xFFFF4D97),
    outlineGold: Color(0xFFFFB300),
    outlineBg: Color(0xFFFFB73C),
  );

  static const cool = _ThemeColors(
    gradientStart: Color(0xFF66BB6A),
    gradientMid: Color(0xFF26C6DA),
    gradientEnd: Color(0xFF42A5F5),
    backlogDot: Color(0xFF2E7D32),
    doneDot: Color(0xFF5C6BC0),
    urgentDot: Color(0xFF1E88E5),
    lightDot: Color(0xFF81C784),
    importantDot: Color(0xFF00ACC1),
    outlineGold: Color(0xFF42A5F5),
    outlineBg: Color(0xFF66BB6A),
  );
}

class _ThemeColors {
  const _ThemeColors({
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.backlogDot,
    required this.doneDot,
    required this.urgentDot,
    required this.lightDot,
    required this.importantDot,
    required this.outlineGold,
    required this.outlineBg,
  });

  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color backlogDot;
  final Color doneDot;
  final Color urgentDot;
  final Color lightDot;
  final Color importantDot;
  final Color outlineGold;
  final Color outlineBg;
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
        return theme.backlogDot;
      case TaskStatus.light:
        return theme.lightDot;
      case TaskStatus.important:
        return theme.importantDot;
      case TaskStatus.urgent:
        return theme.urgentDot;
      case TaskStatus.done:
        return theme.doneDot;
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'content': content,
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'notes': notes,
    'status': status.key,
    'board_date': '${boardDate.year.toString().padLeft(4, '0')}-${boardDate.month.toString().padLeft(2, '0')}-${boardDate.day.toString().padLeft(2, '0')}',
    'subtasks': subtasks.map((s) => s.toMap()).toList(),
  };
}

class BoardRepository {
  static const _storageKey = 'daily_kanban_tasks';
  final _random = Random();

  List<Task> _tasks = [];
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _tasks = jsonList.map((json) {
        final subs = (json['subtasks'] as List)
            .map((s) => Subtask.fromMap(s as Map<String, dynamic>))
            .toList();
        return Task.fromMap(json as Map<String, dynamic>, subs);
      }).toList();
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _tasks.map((t) => t.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99999)}';

  String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> rollover() async {
    await _load();
    final todayKey = _dateKey(DateTime.now());
    bool changed = false;
    for (final task in _tasks) {
      if (_dateKey(task.boardDate) != todayKey && task.status != TaskStatus.done) {
        task.boardDate = DateTime.now();
        task.status = TaskStatus.backlog;
        changed = true;
      }
    }
    if (changed) await _save();
  }

  Future<List<Task>> fetchBoard() async {
    await _load();
    final todayKey = _dateKey(DateTime.now());
    return _tasks.where((t) => _dateKey(t.boardDate) == todayKey).toList();
  }

  Future<void> addTaskWithSubtasks({
    required String title,
    required String notes,
    required TaskStatus status,
    required List<String> subtaskContents,
  }) async {
    await _load();
    final id = _generateId();
    final now = DateTime.now();
    final task = Task(
      id: id,
      title: title,
      notes: notes,
      status: status,
      boardDate: DateTime(now.year, now.month, now.day),
      subtasks: subtaskContents
          .map((c) => Subtask(id: _generateId(), taskId: id, content: c))
          .toList(),
    );
    _tasks.add(task);
    await _save();
  }

  Future<void> deleteTask(String id) async {
    await _load();
    _tasks.removeWhere((t) => t.id == id);
    await _save();
  }

  Future<void> updateStatus(String id, TaskStatus status) async {
    await _load();
    final task = _tasks.firstWhere((t) => t.id == id);
    task.status = status;
    await _save();
  }

  Future<void> updateTask({
    required String id,
    required String title,
    required String notes,
    required TaskStatus status,
    required List<String> subtaskContents,
  }) async {
    await _load();
    final task = _tasks.firstWhere((t) => t.id == id);
    task.title = title;
    task.notes = notes;
    task.status = status;
    task.subtasks = subtaskContents
        .map((c) => Subtask(id: _generateId(), taskId: id, content: c))
        .toList();
    await _save();
  }
}

class DailyPrioritiesApp extends StatelessWidget {
  const DailyPrioritiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: theme.urgentDot);
    return MaterialApp(
      title: 'Daily Priorities',
      theme: base.copyWith(textTheme: GoogleFonts.figtreeTextTheme(base.textTheme)),
      home: const BoardPage(),
    );
  }
}

class OutlineCircleButton extends StatelessWidget {
  const OutlineCircleButton({super.key, required this.onTap, this.size = 36, this.strokeWidth = 3, this.color});
  final VoidCallback onTap;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gold = color ?? theme.outlineGold;
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
            color: theme.outlineBg.withValues(alpha: 0.25),
            border: Border.all(color: gold, width: strokeWidth),
            boxShadow: [
              BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: gold.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
              BoxShadow(color: gold.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 8)),
            ],
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
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await repo.rollover();
    await _refresh();
    _scheduleMidnightRollover();
  }

  Future<void> _toggleTheme() async {
    final isCool = theme == AppColors.cool;
    theme = isCool ? AppColors.warm : AppColors.cool;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cool_theme', !isCool);
    setState(() {});
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () async {
      await repo.rollover();
      await _refresh();
      _scheduleMidnightRollover();
    });
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

  Future<void> _openEditScreen(Task task) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(repo: repo, initialStatus: task.status, editTask: task)),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.gradientStart, theme.gradientMid, theme.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Row(
                    children: [
                      Text('Daily Priorities', style: GoogleFonts.figtree(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
                      Text(theme == AppColors.cool ? ' 🌿' : ' ☀️', style: GoogleFonts.figtree(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
                      const Spacer(),
                      OutlineCircleButton(onTap: () => _openAddScreen(TaskStatus.light)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggleTheme,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Icon(Icons.palette, size: 18, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
      onTap: () => _openEditScreen(task),
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
  const AddTaskScreen({super.key, required this.repo, required this.initialStatus, this.editTask});
  final BoardRepository repo;
  final TaskStatus initialStatus;
  final Task? editTask;

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
    final task = widget.editTask;
    if (task != null) {
      titleController.text = task.title;
      notesController.text = task.notes;
      subtasks.addAll(task.subtasks.map((s) => s.content));
    }
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

  Future<void> _confirmDeleteInEdit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.gradientMid,
        title: Text('Delete task', style: GoogleFonts.figtree(color: Colors.white)),
        content: Text('Delete "${widget.editTask!.title}"?', style: GoogleFonts.figtree(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.figtree(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.figtree(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.repo.deleteTask(widget.editTask!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _shareTask() {
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    final subtaskList = subtasks.map((s) => '  - $s').join('\n');
    final text = StringBuffer('📌 $title\n');
    if (notes.isNotEmpty) text.write('\n$notes\n');
    if (subtaskList.isNotEmpty) text.write('\n$subtaskList');
    Share.share(text.toString());
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty) return;
    setState(() => saving = true);
    final task = widget.editTask;
    if (task != null) {
      await widget.repo.updateTask(
        id: task.id,
        title: titleController.text.trim(),
        notes: notesController.text.trim(),
        status: selectedStatus,
        subtaskContents: subtasks,
      );
    } else {
      await widget.repo.addTaskWithSubtasks(
        title: titleController.text.trim(),
        notes: notesController.text.trim(),
        status: selectedStatus,
        subtaskContents: subtasks,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.gradientStart, theme.gradientMid, theme.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.editTask != null ? 'Edit task' : 'New task', style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white)),
                    const Spacer(),
                    if (widget.editTask != null) ...[
                      IconButton(
                        icon: Icon(Icons.check, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                        onPressed: _save,
                      ),
                      IconButton(
                        icon: Icon(Icons.share, size: 18, color: Colors.white.withValues(alpha: 0.8)),
                        onPressed: _shareTask,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () => _confirmDeleteInEdit(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text('Task name', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  cursorColor: const Color(0xFFFFB6C1),
                  cursorWidth: 3,
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
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: DropdownMenu<TaskStatus>(
                    initialSelection: selectedStatus,
                    expandedInsets: EdgeInsets.zero,
                    textStyle: GoogleFonts.figtree(color: Colors.white),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIconColor: Colors.white,
                    ),
                    menuStyle: MenuStyle(
                      elevation: WidgetStateProperty.all(0),
                      shadowColor: WidgetStateProperty.all(Colors.transparent),
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    dropdownMenuEntries: importanceOptions.map((s) {
                      final itemColors = <TaskStatus, Color>{
                        TaskStatus.light: theme.lightDot,
                        TaskStatus.important: theme.importantDot,
                        TaskStatus.urgent: theme.urgentDot,
                      };
                      return DropdownMenuEntry<TaskStatus>(
                        value: s,
                        label: s.label,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(itemColors[s]!.withValues(alpha: 0.7)),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      );
                    }).toList(),
                    onSelected: (value) {
                      if (value != null) setState(() => selectedStatus = value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text('Notes', style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 5,
                  cursorColor: const Color(0xFFFFB6C1),
                  cursorWidth: 3,
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
                        cursorColor: const Color(0xFFFFB6C1),
                        cursorWidth: 3,
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
                    OutlineCircleButton(onTap: _addSubtaskToList),
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
            );
          },
        ),
      ),
      ),
    );
  }
}

