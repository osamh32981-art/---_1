import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اتصالي الذكي_1',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اتصالي الذكي_1'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
```html
<!DOCTYPE html>
<html>
<head>
    <title>LAN Chat App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
            color: #333;
            display: flex;
            flex-direction: column;
            height: 100vh;
        }

        header {
            background-color: #4CAF50;
            color: white;
            padding: 15px 20px;
            text-align: center;
            font-size: 24px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
        }

        main {
            flex: 1;
            display: flex;
            overflow: hidden;
        }

        .sidebar {
            width: 250px;
            background-color: #e0e0e0;
            border-right: 1px solid #ccc;
            overflow-y: auto;
            padding: 15px;
            box-shadow: 2px 0 5px rgba(0,0,0,0.1);
        }

        .sidebar h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 1px solid #ccc;
            padding-bottom: 10px;
            margin-bottom: 15px;
        }

        .contact-list ul {
            list-style: none;
            padding: 0;
            margin: 0;
        }

        .contact-list li {
            padding: 12px 10px;
            cursor: pointer;
            border-radius: 5px;
            margin-bottom: 8px;
            background-color: #fff;
            transition: background-color 0.2s ease;
            display: flex;
            align-items: center;
        }

        .contact-list li:hover {
            background-color: #d5f5e3;
        }

        .contact-list li img {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            margin-right: 15px;
            object-fit: cover;
        }

        .contact-list li span {
            font-weight: bold;
        }

        .chat-area {
            flex: 1;
            display: flex;
            flex-direction: column;
            background-color: #fff;
        }

        .chat-header {
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            font-size: 18px;
            font-weight: bold;
            text-align: center;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .chat-messages {
            flex: 1;
            padding: 20px;
            overflow-y: auto;
            background-image: url('background.jpg'); /* Replace with your background image */
            background-size: cover;
            background-position: center;
            display: flex;
            flex-direction: column;
        }

        .message {
            max-width: 60%;
            margin-bottom: 15px;
            padding: 10px 15px;
            border-radius: 10px;
            word-wrap: break-word;
            line-height: 1.4;
        }

        .sent {
            background-color: #dcf8c6;
            align-self: flex-end;
            margin-left: auto;
        }

        .received {
            background-color: #ece5dd;
            align-self: flex-start;
        }

        .message-meta {
            font-size: 11px;
            color: #555;
            margin-top: 5px;
            text-align: right;
        }

        .sent .message-meta {
            text-align: right;
        }

        .received .message-meta {
            text-align: left;
        }

        .input-area {
            background-color: #f9f9f9;
            padding: 15px 20px;
            border-top: 1px solid #ccc;
            display: flex;
            align-items: center;
            box-shadow: 0 -2px 5px rgba(0,0,0,0.1);
        }

        .input-area input[type="text"] {
            flex: 1;
            padding: 12px 15px;
            border: 1px solid #ccc;
            border-radius: 25px;
            margin-right: 10px;
            font-size: 16px;
            outline: none;
            transition: border-color 0.3s ease;
        }

        .input-area input[type="text"]:focus {
            border-color: #4CAF50;
        }

        .input-area button {
            background-color: #4CAF50;
            color: white;
            border: none;
            padding: 12px 18px;
            border-radius: 50%;
            cursor: pointer;
            font-size: 20px;
            transition: background-color 0.2s ease;
            outline: none;
            width: 45px;
            height: 45px;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .input-area button:hover {
            background-color: #45a049;
        }

        .input-area .icon-button {
            background-color: #f9f9f9;
            color: #555;
            border: none;
            font-size: 22px;
            cursor: pointer;
            margin: 0 10px;
            transition: color 0.2s ease;
            padding: 5px;
        }

        .input-area .icon-button:hover {
            color: #4CAF50;
        }

        /* Tool and Command Buttons */
        .command-panel {
            width: 50px;
            background-color: #e0e0e0;
            border-left: 1px solid #ccc;
            display: flex;
            flex-direction: column;
            justify-content: flex-start;
            align-items: center;
            padding: 10px 0;
            box-shadow: -2px 0 5px rgba(0,0,0,0.1);
        }

        .command-panel .command-button {
            background: none;
            border: none;
            color: #555;
            font-size: 24px;
            cursor: pointer;
            margin-bottom: 15px;
            transition: color 0.2s ease;
            padding: 10px;
        }

        .command-panel .command-button:hover {
            color: #4CAF50;
        }

        /* Color Picker Example */
        .color-picker {
            position: relative;
            display: inline-block;
        }

        .color-picker input[type="color"] {
            width: 30px;
            height: 30px;
            border: none;
            cursor: pointer;
            border-radius: 5px;
            background: none;
            padding: 0;
            appearance: none;
            -webkit-appearance: none;
            -moz-appearance: none;
        }

        /* For Webkit browsers */
        .color-picker input[type="color"]::-webkit-color-swatch-wrapper {
            padding: 0;
        }
        .color-picker input[type="color"]::-webkit-color-swatch {
            border: none;
            border-radius: 5px;
        }

        /* For Firefox */
        .color-picker input[type="color"]::-moz-color-swatch {
            border: none;
            border-radius: 5px;
        }

        /* Notification Sounds */
        .sound-settings {
            position: relative;
            display: inline-block;
        }

        .sound-settings select {
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 5px;
            font-size: 14px;
            cursor: pointer;
            outline: none;
        }

        /* Placeholder for voice/video call buttons */
        .call-buttons {
            display: flex;
            align-items: center;
        }

        .call-buttons .icon-button {
            margin-left: 15px;
        }

    </style>
</head>
<body>

    <header>
        <h1>LAN Connect (Your App Name)</h1>
    </header>

    <main>
        <div class="sidebar">
            <h2>Contacts</h2>
            <div class="contact-list">
                <ul>
                    <li onclick="selectContact('user1')">
                        <img src="user1_avatar.jpg" alt="User 1">
                        <span>Alice</span>
                    </li>
                    <li onclick="selectContact('user2')">
                        <img src="user2_avatar.jpg" alt="User 2">
                        <span>Bob</span>
                    </li>
                    <li onclick="selectContact('user3')">
                        <img src="user3_avatar.jpg" alt="User 3">
                        <span>Charlie</span>
                    </li>
                    <!-- Add more contacts here -->
                </ul>
            </div>
        </div>

        <div class="chat-area">
            <div class="chat-header">
                <span id="current-chat-name">Select a contact</span>
                <div class="call-buttons">
                    <button class="icon-button" title="Voice Call" onclick="startVoiceCall()">
                        <i class="fas fa-phone"></i> <!-- You'll need Font Awesome CDN for icons -->
                    </button>
                    <button class="icon-button" title="Video Call" onclick="startVideoCall()">
                        <i class="fas fa-video"></i> <!-- You'll need Font Awesome CDN for icons -->
                    </button>
                </div>
            </div>
            <div class="chat-messages" id="chat-messages">
                <!-- Messages will appear here -->
                <div class="message received">
                    Hello! How are you?
                    <div class="message-meta">10:30 AM</div>
                </div>
                <div class="message sent">
                    I'm doing great, thanks!
                    <div class="message-meta">10:31 AM</div>
                </div>
            </div>
            <div class="input-area">
                <button class="icon-button" title="Attach File" onclick="attachFile()">
                    <i class="fas fa-paperclip"></i>
                </button>
                <div class="color-picker">
                    <input type="color" id="message-color" value="#000000" title="Message Color">
                </div>
                <input type="text" id="message-input" placeholder="Type a message...">
                <button class="icon-button" title="Emoji" onclick="addEmoji()">
                    <i class="far fa-smile"></i>
                </button>
                <button id="send-button" onclick="sendMessage()">
                    <i class="fas fa-paper-plane"></i>
                </button>
            </div>
        </div>

        <div class="command-panel">
            <button class="command-button" title="Bold" onclick="formatText('bold')">
                <i class="fas fa-bold"></i>
            </button>
            <button class="command-button" title="Italic" onclick="formatText('italic')">
                <i class="fas fa-italic"></i>
            </button>
            <button class="command-button" title="Underline" onclick="formatText('underline')">
                <i class="fas fa-underline"></i>
            </button>
            <button class="command-button" title="Strikethrough" onclick="formatText('strikethrough')">
                <i class="fas fa-strikethrough"></i>
            </button>
            <div class="sound-settings">
                <select id="notification-sound" title="Notification Sound">
                    <option value="default">Default</option>
                    <option value="sound1">Chime</option>
                    <option value="sound2">Ping</option>
                    <option value="sound3">Whistle</option>
                    <!-- Add more sound options -->
                </select>
            </div>
            <!-- Add more command buttons as needed -->
        </div>
    </main>

    <!-- Include Font Awesome for icons (you can host this locally or use a CDN) -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/js/all.min.js"></script>

    <script>
        // --- JavaScript Functionality (for basic interaction, actual LAN implementation requires backend) ---

        function selectContact(contactId) {
            const currentChatName = document.getElementById('current-chat-name');
            // In a real app, this would load the chat history for the selected contact
            if (contactId === 'user1') {
                currentChatName.innerText = 'Alice';
            } else if (contactId === 'user2') {
                currentChatName.innerText = 'Bob';
            } else if (contactId === 'user3') {
                currentChatName.innerText = 'Charlie';
            }
            // Clear previous messages
            document.getElementById('chat-messages').innerHTML = '';
        }

        function sendMessage() {
            const messageInput = document.getElementById('message-input');
            const messageText = messageInput.value.trim();
            const messageColor = document.getElementById('message-color').value;

            if (messageText === '') return;

            const chatMessages = document.getElementById('chat-messages');

            const newMessage = document.createElement('div');
            newMessage.classList.add('message', 'sent');
            newMessage.style.backgroundColor = messageColor; // Apply selected color

            const textNode = document.createTextNode(messageText);
            newMessage.appendChild(textNode);

            const messageMeta = document.createElement('div');
            messageMeta.classList.add('message-meta');
            messageMeta.innerText = getCurrentTime();
            newMessage.appendChild(messageMeta);

            chatMessages.appendChild(newMessage);
            messageInput.value = '';
            scrollToBottom();

            // Play notification sound (for sent message - usually not played)
            // You would typically play a "delivered" sound here, or nothing.
        }

        function addMessage(text, type = 'received') {
            const chatMessages = document.getElementById('chat-messages');
            const newMessage = document.createElement('div');
            newMessage.classList.add('message', type);

            const textNode = document.createTextNode(text);
            newMessage.appendChild(textNode);

            const messageMeta = document.createElement('div');
            messageMeta.classList.add('message-meta');
            messageMeta.innerText = getCurrentTime();
            newMessage.appendChild(messageMeta);

            chatMessages.appendChild(newMessage);
            scrollToBottom();

            // Play notification sound for received messages
            playNotificationSound();
        }

        function scrollToBottom() {
            const chatMessages = document.getElementById('chat-messages');
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }

        function getCurrentTime() {
            const now = new Date();
            const hours = String(now.getHours()).padStart(2, '0');
            const minutes = String(now.getMinutes()).padStart(2, '0');
            return `${hours}:${minutes}`;
        }

        function playNotificationSound() {
            const soundSelect = document.getElementById('notification-sound');
            const selectedSound = soundSelect.value;

            let audioSrc = '';
            switch (selectedSound) {
                case 'sound1':
                    audioSrc = 'chime.mp3'; // Replace with your sound file path
                    break;
                case 'sound2':
                    audioSrc = 'ping.wav';  // Replace with your sound file path
                    break;
                case 'sound3':
                    audioSrc = 'whistle.ogg'; // Replace with your sound file path
                    break;
                default:
                    // Default browser sound or no sound
                    return;
            }

            const audio = new Audio(audioSrc);
            audio.play().catch(error => console.log("Sound playback failed:", error));
        }

        // --- Placeholder functions for advanced features ---

        function startVoiceCall() {
            alert('Initiating Voice Call (LAN)...');
            // In a real app: Implement WebRTC or a custom LAN call protocol
        }

        function startVideoCall() {
            alert('Initiating Video Call (LAN)...');
            // In a real app: Implement WebRTC or a custom LAN call protocol
        }

        function attachFile() {
            alert('File Attachment (LAN)...');
            // In a real app: Use File API and LAN transfer protocols
        }

        function addEmoji() {
            alert('Adding Emoji...');
            // In a real app: Implement emoji picker and insertion
            // For now, you could inject emoji characters:
            // const messageInput = document.getElementById('message-input');
            // messageInput.value += '😊';
        }

        function formatText(format) {
            const messageInput = document.getElementById('message-input');
            const selection = window.getSelection();
            const text = messageInput.value;

            if (selection.rangeCount > 0) {
                const range = selection.getRangeAt(0);
                const selectedText = range.toString();

                if (selectedText) {
                    let formattedText = '';
                    switch (format) {
                        case 'bold':
                            formattedText = `<strong>${selectedText}</strong>`;
                            break;
                        case 'italic':
                            formattedText = `<em>${selectedText}</em>`;
                            break;
                        case 'underline':
                            formattedText = `<u>${selectedText}</u>`;
                            break;
                        case 'strikethrough':
                            formattedText = `<s>${selectedText}</s>`;
                            break;
                    }

                    // This is a simplified approach. For rich text editing, a contenteditable div is better.
                    // For input fields, direct manipulation is complex.
                    // A common approach for basic formatting is to add tags if you were using a rich text editor.
                    // For a simple input, you might just change the color of the input itself or offer pre-formatted text.

                    // For this example, we'll just show an alert and suggest manual formatting
                    alert(`Apply "${format}" formatting. For rich text, consider a contenteditable div.`);
                }
            } else {
                alert(`Select text in the input box to apply "${format}" formatting.`);
            }
        }

        // --- Example: Add some initial received messages ---
        // document.addEventListener('DOMContentLoaded', () => {
        //     addMessage('Welcome to LAN Connect!', 'received');
        //     addMessage('Let\'s start chatting.', 'received');
        // });

        // --- Event Listener for Enter Key to Send Message ---
        document.getElementById('message-input').addEventListener('keypress', function(event) {
            if (event.key === 'Enter') {
                event.preventDefault(); // Prevent default form submission/newline
                sendMessage();
            }
        });

        // --- Placeholder for background image ---
        // Make sure you have a 'background.jpg' in the same directory or provide a correct path.
        // If not, you can set a solid color like:
        // .chat-messages { background-color: #f0f0f0; }

    </script>

</body>
</html>
```}