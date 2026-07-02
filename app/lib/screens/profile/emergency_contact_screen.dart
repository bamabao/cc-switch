import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class EmergencyContactManageScreen extends StatefulWidget {
  const EmergencyContactManageScreen({super.key});

  @override
  State<EmergencyContactManageScreen> createState() => _EmergencyContactManageScreenState();
}

class _EmergencyContactManageScreenState extends State<EmergencyContactManageScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final result = await _api.get('${ApiConfig.emergencyContacts}?token=${_api.token ?? ""}');
      if (!mounted) return;
      setState(() {
        _contacts = result['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addContact() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        String relation = '儿子';
        return AlertDialog(
          title: const Text('添加紧急联系人'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名', hintText: '例如：李建国')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', hintText: '13812345678'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: relation, decoration: const InputDecoration(labelText: '关系'),
              items: ['儿子','女儿','配偶','邻居','其他'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) { if (v != null) relation = v; },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(onPressed: () {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              Navigator.pop(ctx, {'name': nameCtrl.text, 'phone': phoneCtrl.text, 'relation': relation});
            }, child: const Text('保存')),
          ],
        );
      },
    );
    if (result == null) return;
    try {
      await _api.post('${ApiConfig.emergencyContacts}?token=${_api.token ?? ""}', body: {
        'name': result['name'], 'phone': result['phone'], 'relation': result['relation'],
      });
      await _loadContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('紧急联系人已添加')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
    }
  }

  Future<void> _deleteContact(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除紧急联系人「$name」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('${ApiConfig.emergencyContacts}/$id?token=${_api.token ?? ""}');
      await _loadContacts();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('紧急联系人'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _addContact, tooltip: '添加联系人'),
      ]),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadContacts,
            child: _contacts.isEmpty
              ? const Center(child: Text('暂无紧急联系人\n点击右上角 + 添加', textAlign: TextAlign.center, style: TextStyle(fontSize: AppTheme.bodyLarge, color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    final name = c['name'] as String? ?? '';
                    final phone = c['phone'] as String? ?? '';
                    final relation = c['relation'] as String? ?? '';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 24, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontSize: AppTheme.bodyLarge, fontWeight: FontWeight.w600)),
                        subtitle: Text('$phone  |  $relation', style: const TextStyle(fontSize: AppTheme.bodyMedium)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                          onPressed: () => _deleteContact(c['id'] as int? ?? 0, name),
                        ),
                      ),
                    );
                  },
                ),
          ),
    );
  }
}
