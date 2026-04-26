import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../api/auth_storage.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  bool _markingAll = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<Map<String, String>> _authHeaders() async {
    final jwt = await getJwt();
    if (jwt == null || jwt.isEmpty) return {};
    return {'Authorization': 'Bearer $jwt'};
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      final list = await ApiService.getList(
        'notifications/me?limit=100',
        headers: headers,
      );

      if (!mounted) return;
      setState(() {
        _notifications = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load notifications')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;

    setState(() => _markingAll = true);
    try {
      final headers = await _authHeaders();
      await ApiService.patch('notifications/me/read-all', {}, headers: headers);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (n) => {
                ...n,
                'isRead': true,
                'readAt': n['readAt'] ?? DateTime.now().toIso8601String(),
              },
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark all as read')),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markOneRead(Map<String, dynamic> notification) async {
    if (notification['isRead'] == true) return;

    final id = (notification['id'] ?? '').toString();
    if (id.isEmpty) return;

    try {
      final headers = await _authHeaders();
      await ApiService.patch('notifications/$id/read', {}, headers: headers);
      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((item) {
          final itemId = (item['id'] ?? '').toString();
          if (itemId != id) return item;
          return {
            ...item,
            'isRead': true,
            'readAt': item['readAt'] ?? DateTime.now().toIso8601String(),
          };
        }).toList();
      });
    } catch (_) {
      // Keep tap non-blocking if request fails.
    }
  }

  String _timeText(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';

    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((item) => item['isRead'] != true)
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Image.asset('assets/images/logo.png', height: 46),
                  const Spacer(),
                  TextButton(
                    onPressed: _notifications.isEmpty || _markingAll
                        ? null
                        : _markAllRead,
                    child: _markingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFEAEAEA)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: _notifications.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 180),
                                Center(child: Text('No notifications yet')),
                              ],
                            )
                          : ListView.separated(
                              itemCount: _notifications.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _notifications[index];
                                final isRead = item['isRead'] == true;
                                final title = (item['title'] ?? 'Notification')
                                    .toString();
                                final message = (item['message'] ?? '')
                                    .toString();
                                final time = _timeText(item['createdAt']);

                                return ListTile(
                                  onTap: () => _markOneRead(item),
                                  leading: Icon(
                                    isRead
                                        ? Icons.notifications_none
                                        : Icons.notifications_active,
                                    color: isRead
                                        ? Colors.grey
                                        : const Color(0xFF16807A),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(message),
                                  trailing: Text(
                                    time,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: unreadCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
    );
  }
}
