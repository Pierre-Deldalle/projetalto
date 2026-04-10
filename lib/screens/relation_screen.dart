import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/pairing_service.dart';

enum MessageType { texte }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool isMine;
  final String senderId;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sentAt,
    required this.isMine,
    required this.senderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'sentAt': sentAt.toIso8601String(),
      'isMine': isMine,
      'senderId': senderId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] ?? 'texte').toString();
    return ChatMessage(
      id: (json['id'] ?? const Uuid().v4()).toString(),
      content: (json['content'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => MessageType.texte,
      ),
      sentAt: DateTime.tryParse((json['sentAt'] ?? '').toString()) ??
          DateTime.now(),
      isMine: json['isMine'] == true,
      senderId: (json['senderId'] ?? '').toString(),
    );
  }
}

class RelationScreen extends StatefulWidget {
  final String? initialLocalRelationCode;
  final String? initialRemoteRelationCode;

  const RelationScreen({
    super.key,
    this.initialLocalRelationCode,
    this.initialRemoteRelationCode,
  });

  @override
  State<RelationScreen> createState() => _RelationScreenState();
}

class _RelationScreenState extends State<RelationScreen> {
  final PairingService _pairingService = PairingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Timer _refreshTimer;
  String? _localRelationCode;
  String? _remoteRelationCode;
  String? _localDeviceId;
  bool _isLoadingRelation = true;
  bool _isSending = false;
  final List<ChatMessage> _messages = <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _initializeRelation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMessages();
    });
  }

  Future<void> _initializeRelation() async {
    final deviceId = await _pairingService.getOrCreateDeviceId();
    String? localCode = widget.initialLocalRelationCode;
    String? remoteCode = widget.initialRemoteRelationCode;

    if (localCode == null || localCode.isEmpty) {
      final savedContext = await _pairingService.getDiscussionContext();
      localCode = savedContext['localRelationCode'];
      remoteCode = savedContext['remoteRelationCode'];
    }

    if (localCode != null && localCode.isNotEmpty) {
      final history = await _pairingService.getLocalHistory(localCode);
      _messages
        ..clear()
        ..addAll(history.map(ChatMessage.fromJson));
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      await _pairingService.saveLastRelationCode(localCode);
      await _pairingService.saveDiscussionContext(
        localRelationCode: localCode,
        remoteRelationCode: remoteCode,
      );
    }

    if (!mounted) return;
    setState(() {
      _localRelationCode = localCode;
      _remoteRelationCode = remoteCode;
      _localDeviceId = deviceId;
      _isLoadingRelation = false;
    });

    if (localCode != null && localCode.isNotEmpty) {
      await _refreshInbox();
    }
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshMessages() async {
    await _refreshInbox();
  }

  Future<void> _refreshInbox() async {
    if (!mounted) return;
    if (_localRelationCode == null || _localRelationCode!.isEmpty) return;

    try {
      final rawElements = await _pairingService.fetchDiscussionMessages(
        _localRelationCode!,
      );
      if (!mounted) return;

      final localId = _localDeviceId ?? '';
      final List<ChatMessage> incoming = [];

      for (final raw in rawElements) {
        final elementKey = (raw['key'] ?? 'MESSAGE').toString();
        final value = (raw['value'] ?? '').toString();

        if (elementKey.toUpperCase() == 'CHANNEL') {
          final channelData = _parseElementValue(value);
          final replyCode = (channelData['replyCode'] ?? '').toString();
          if (replyCode.isNotEmpty && replyCode != _remoteRelationCode) {
            _remoteRelationCode = replyCode;
            await _pairingService.saveDiscussionContext(
              localRelationCode: _localRelationCode!,
              remoteRelationCode: replyCode,
            );
            if (mounted) {
              setState(() {});
            }
          }
          continue;
        }

        final parsed = _parseElementValue(value);

        final senderId = (parsed['senderId'] ?? '').toString();
        final content = (parsed['content'] ?? value).toString();
        final rawDate =
            (parsed['sentAt'] ?? raw['creationDate'] ?? raw['createdAt'])
                ?.toString();

        final messageId = (parsed['messageId'] ??
                '${raw['creationDate'] ?? rawDate}_${value.hashCode}')
            .toString();

        final message = ChatMessage(
          id: messageId,
          content: content,
          type: MessageType.texte,
          sentAt: rawDate == null
              ? DateTime.now()
              : DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now(),
          isMine: senderId == localId,
          senderId: senderId.isEmpty ? 'unknown' : senderId,
        );
        if (message.content.isNotEmpty && !_containsMessage(message.id)) {
          incoming.add(message);
        }
      }

      if (incoming.isNotEmpty) {
        setState(() {
          _messages.addAll(incoming);
          _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          for (var i = 0; i < _messages.length; i++) {
            final m = _messages[i];
            _messages[i] = ChatMessage(
              id: m.id,
              content: m.content,
              type: m.type,
              sentAt: m.sentAt,
              isMine: m.senderId == localId,
              senderId: m.senderId,
            );
          }
        });
        await _persistLocalHistory();
        _scrollToBottom();
      }
    } catch (_) {
      // On ignore les erreurs de sync periodique pour ne pas bloquer l'UI.
    }
  }

  Future<void> _sendMessage() async {
    if (_localRelationCode == null || _localRelationCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune discussion active. Lance une liaison.')),
      );
      return;
    }

    if (_remoteRelationCode == null || _remoteRelationCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion en cours... attends 2-3 secondes.')),
      );
      return;
    }

    if (_localDeviceId == null || _localDeviceId!.isEmpty) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messageId = const Uuid().v4();

      final payload = jsonEncode({
        'messageId': messageId,
        'senderId': _localDeviceId!,
        'content': content,
        'type': 'texte',
        'sentAt': DateTime.now().toUtc().toIso8601String(),
      });

      await _pairingService.sendDiscussionMessage(
        relationCode: _remoteRelationCode!,
        senderId: _localDeviceId!,
        content: payload,
        type: 'MESSAGE',
      );

      final now = DateTime.now();
      setState(() {
        _messages.add(
          ChatMessage(
            id: messageId,
            content: content,
            type: MessageType.texte,
            sentAt: now,
            isMine: true,
            senderId: _localDeviceId!,
          ),
        );
      });
      await _persistLocalHistory();
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec de l envoi: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  bool _containsMessage(String id) {
    return _messages.any((m) => m.id == id);
  }

  Future<void> _persistLocalHistory() async {
    if (_localRelationCode == null || _localRelationCode!.isEmpty) return;
    await _pairingService.saveLocalHistory(
      _localRelationCode!,
      _messages.map((m) => m.toJson()).toList(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  IconData _iconForType() {
    return Icons.chat_bubble_outline;
  }

  String _labelForType() {
    return 'Texte';
  }

  Map<String, dynamic> _parseElementValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Value non-JSON: on garde un fallback texte brut.
    }

    return {
      'content': value,
      'type': 'texte',
      'senderId': '',
    };
  }

  Widget _buildMessageItem(ChatMessage message) {
    final alignment =
        message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isMine ? Colors.lightBlue : Colors.grey.shade900;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconForType(), size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  _labelForType(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            const SizedBox(height: 6),
            Text(
              _formatTime(message.sentAt),
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Discussion'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Local: ${_localRelationCode ?? '-'} | Remote: ${_remoteRelationCode ?? '-'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingRelation
                ? const Center(child: CircularProgressIndicator())
                : (_localRelationCode == null || _localRelationCode!.isEmpty)
                ? const Center(
                    child: Text(
                      'Aucune discussion a reprendre. Scanne un appareil pour commencer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun message',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageItem(_messages[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.grey.shade800),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ecrire un message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey.shade900,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.lightBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}