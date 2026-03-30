import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../services/pairing_service.dart';

enum MessageType { texte, image, audio, fichier }

class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool isMine;
  final String senderId;

  const ChatMessage({
    required this.content,
    required this.type,
    required this.sentAt,
    required this.isMine,
    required this.senderId,
  });
}

class RelationScreen extends StatefulWidget {
  final String? initialRelationCode;

  const RelationScreen({super.key, this.initialRelationCode});

  @override
  State<RelationScreen> createState() => _RelationScreenState();
}

class _RelationScreenState extends State<RelationScreen> {
  final PairingService _pairingService = PairingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Timer _refreshTimer;
  MessageType _selectedType = MessageType.texte;
  String? _activeRelationCode;
  String? _localDeviceId;
  bool _isLoadingRelation = true;
  bool _isSending = false;
  DateTime? _lastLocalSendAt;
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
    if (!mounted) return;

    final fromRoute = widget.initialRelationCode;
    if (fromRoute != null && fromRoute.isNotEmpty) {
      await _pairingService.saveLastRelationCode(fromRoute);
      if (!mounted) return;
      setState(() {
        _activeRelationCode = fromRoute;
        _localDeviceId = deviceId;
        _isLoadingRelation = false;
      });
      await _refreshMessages();
      return;
    }

    final savedRelation = await _pairingService.getLastRelationCode();
    if (!mounted) return;
    setState(() {
      _activeRelationCode = savedRelation;
      _localDeviceId = deviceId;
      _isLoadingRelation = false;
    });

    if (savedRelation != null && savedRelation.isNotEmpty) {
      await _refreshMessages();
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
    if (!mounted) return;
    if (_activeRelationCode == null || _activeRelationCode!.isEmpty) return;

    // Evite de re-consommer son propre message juste apres envoi (API read-once).
    if (_lastLocalSendAt != null &&
        DateTime.now().difference(_lastLocalSendAt!).inSeconds < 3) {
      return;
    }

    try {
      final rawElements = await _pairingService.fetchDiscussionMessages(
        _activeRelationCode!,
      );
      if (!mounted) return;

      final localId = _localDeviceId ?? '';
      final mapped = rawElements.map((raw) {
        final elementKey = (raw['key'] ?? 'MESSAGE').toString();
        final value = (raw['value'] ?? '').toString();
        final parsed = _parseElementValue(value);

        final senderId = (parsed['senderId'] ?? '').toString();
        final content = (parsed['content'] ?? value).toString();
        final rawType = (parsed['type'] ?? _messageTypeFromKey(elementKey).name)
            .toString();
        final rawDate =
            (parsed['sentAt'] ?? raw['creationDate'] ?? raw['createdAt'])
                ?.toString();

        return ChatMessage(
          content: content,
          type: _messageTypeFromString(rawType),
          sentAt: rawDate == null
              ? DateTime.now()
              : DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now(),
          isMine: senderId == localId,
          senderId: senderId,
        );
      }).where((m) => m.senderId != localId && m.content.isNotEmpty).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

      if (mapped.isNotEmpty) {
        setState(() {
          _messages.addAll(mapped);
        });
        _scrollToBottom();
      }
    } catch (_) {
      // On ignore les erreurs de sync periodique pour ne pas bloquer l'UI.
    }
  }

  Future<void> _sendMessage() async {
    if (_activeRelationCode == null || _activeRelationCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune discussion active. Lance une liaison.')),
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
      final payload = jsonEncode({
        'senderId': _localDeviceId!,
        'content': content,
        'type': _messageTypeToApi(_selectedType),
        'sentAt': DateTime.now().toUtc().toIso8601String(),
      });

      await _pairingService.sendDiscussionMessage(
        relationCode: _activeRelationCode!,
        senderId: _localDeviceId!,
        content: payload,
        type: _messageKeyForType(_selectedType),
      );

      final now = DateTime.now();
      setState(() {
        _messages.add(
          ChatMessage(
            content: content,
            type: _selectedType,
            sentAt: now,
            isMine: true,
            senderId: _localDeviceId!,
          ),
        );
        _lastLocalSendAt = now;
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec de l envoi: $message')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
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

  IconData _iconForType(MessageType type) {
    switch (type) {
      case MessageType.texte:
        return Icons.chat_bubble_outline;
      case MessageType.image:
        return Icons.image_outlined;
      case MessageType.audio:
        return Icons.mic_none;
      case MessageType.fichier:
        return Icons.attach_file;
    }
  }

  String _labelForType(MessageType type) {
    switch (type) {
      case MessageType.texte:
        return 'Texte';
      case MessageType.image:
        return 'Image';
      case MessageType.audio:
        return 'Audio';
      case MessageType.fichier:
        return 'Fichier';
    }
  }

  MessageType _messageTypeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'audio':
        return MessageType.audio;
      case 'fichier':
      case 'file':
        return MessageType.fichier;
      default:
        return MessageType.texte;
    }
  }

  MessageType _messageTypeFromKey(String key) {
    switch (key.toUpperCase()) {
      case 'IMAGE':
        return MessageType.image;
      case 'AUDIO':
        return MessageType.audio;
      case 'FICHIER':
      case 'FILE':
        return MessageType.fichier;
      default:
        return MessageType.texte;
    }
  }

  String _messageTypeToApi(MessageType type) {
    switch (type) {
      case MessageType.texte:
        return 'texte';
      case MessageType.image:
        return 'image';
      case MessageType.audio:
        return 'audio';
      case MessageType.fichier:
        return 'fichier';
    }
  }

  String _messageKeyForType(MessageType type) {
    switch (type) {
      case MessageType.texte:
        return 'MESSAGE';
      case MessageType.image:
        return 'IMAGE';
      case MessageType.audio:
        return 'AUDIO';
      case MessageType.fichier:
        return 'FICHIER';
    }
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
                Icon(_iconForType(message.type), size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  _labelForType(message.type),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                'Relation: ${_activeRelationCode ?? '-'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingRelation
                ? const Center(child: CircularProgressIndicator())
                : (_activeRelationCode == null || _activeRelationCode!.isEmpty)
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
                DropdownButton<MessageType>(
                  value: _selectedType,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (MessageType? value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = value;
                    });
                  },
                  items: MessageType.values.map((type) {
                    return DropdownMenuItem<MessageType>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_iconForType(type), color: Colors.white70, size: 18),
                          const SizedBox(width: 6),
                          Text(_labelForType(type)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
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