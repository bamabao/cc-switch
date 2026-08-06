import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class PatientChatScreen extends StatefulWidget {
  final int doctorId;
  final int patientId;
  final String doctorName;

  const PatientChatScreen({super.key, required this.doctorId, required this.patientId, required this.doctorName});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final ApiService _api = ApiService();
  final http.Client _client = http.Client();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      // chat history 返回List，需要直接请求
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatHistory}?doctor_id=${widget.doctorId}&patient_id=${widget.patientId}&limit=100');
      final resp = await _client.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
        setState(() => _messages = list.cast<Map<String, dynamic>>());
      }
      setState(() => _loading = false);
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _send(String content) async {
    if (content.trim().isEmpty) return;
    setState(() => _messages.add({
      'sender_role': 'patient',
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    }));
    _controller.clear();
    _scrollToBottom();
    try {
      await _api.sendChatMessage(
        doctorId: widget.doctorId,
        patientId: widget.patientId,
        role: 'patient',
        senderId: widget.patientId,
        content: content,
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('💬 咨询${widget.doctorName}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 医生信息提示条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primaryColor.withOpacity(0.08),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 6),
                Expanded(
                  child: Text('医生一般会在工作时间回复，紧急情况请拨打120',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('还没有消息，给医生留言吧 👇', style: TextStyle(color: AppTheme.textLightGray)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final isPatient = m['sender_role'] == 'patient';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: isPatient ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isPatient) ...[
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Icon(Icons.medical_services, size: 16, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isPatient ? AppTheme.primaryColor : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: AppTheme.shadowCard,
                                    ),
                                    child: Text(
                                      m['content'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.4,
                                        color: isPatient ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isPatient) ...[
                                  const SizedBox(width: 8),
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Icon(Icons.person, size: 16, color: Colors.white),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // 输入区
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '给医生留言...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (t) => _send(t),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_controller.text),
                    child: Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
