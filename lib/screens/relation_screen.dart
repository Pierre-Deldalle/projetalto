import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/pairing_service.dart';

enum MessageType { texte, image, audio, fichier }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool isMine;
  final String senderId;
  final String? attachmentName;
  final String? attachmentMimeType;
  final String? attachmentBase64;
  final int? attachmentSize;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sentAt,
    required this.isMine,
    required this.senderId,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentBase64,
    this.attachmentSize,
  });

  bool get hasAttachment =>
      attachmentBase64 != null && attachmentBase64!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'sentAt': sentAt.toIso8601String(),
      'isMine': isMine,
      'senderId': senderId,
      'attachmentName': attachmentName,
      'attachmentMimeType': attachmentMimeType,
      'attachmentBase64': attachmentBase64,
      'attachmentSize': attachmentSize,
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
      attachmentName: json['attachmentName']?.toString(),
      attachmentMimeType: json['attachmentMimeType']?.toString(),
      attachmentBase64: json['attachmentBase64']?.toString(),
      attachmentSize: json['attachmentSize'] as int?,
    );
  }
}

class PendingAttachment {
  final Uint8List bytes;
  final String fileName;
  final String? mimeType;

  const PendingAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
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
  MessageType _selectedType = MessageType.texte;
  String? _localRelationCode;
  String? _remoteRelationCode;
  String? _localDeviceId;
  bool _isLoadingRelation = true;
  bool _isSending = false;
  PendingAttachment? _pendingAttachment;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;
  final List<ChatMessage> _messages = <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _initializeRelation();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingMessageId = null;
      });
    });
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
    _audioPlayer.dispose();
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
        final rawType = (parsed['type'] ?? _messageTypeFromKey(elementKey).name)
            .toString();
        final rawDate =
            (parsed['sentAt'] ?? raw['creationDate'] ?? raw['createdAt'])
                ?.toString();

        final messageId = (parsed['messageId'] ??
                '${raw['creationDate'] ?? rawDate}_${value.hashCode}')
            .toString();

        final message = ChatMessage(
          id: messageId,
          content: content,
          type: _messageTypeFromString(rawType),
          sentAt: rawDate == null
              ? DateTime.now()
              : DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now(),
          isMine: senderId == localId,
          senderId: senderId.isEmpty ? 'unknown' : senderId,
          attachmentName: parsed['attachmentName']?.toString(),
          attachmentMimeType: parsed['attachmentMimeType']?.toString(),
          attachmentBase64: parsed['attachmentBase64']?.toString(),
          attachmentSize: _toInt(parsed['attachmentSize']),
        );
        if ((message.content.isNotEmpty || message.hasAttachment) &&
            !_containsMessage(message.id)) {
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
    if (_selectedType == MessageType.texte && content.isEmpty) return;

    if (_selectedType != MessageType.texte && _pendingAttachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute un media avant envoi.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final messageId = const Uuid().v4();
      final attachmentBase64 = _pendingAttachment == null
          ? null
          : base64Encode(_pendingAttachment!.bytes);

      final payload = jsonEncode({
        'messageId': messageId,
        'senderId': _localDeviceId!,
        'content': content,
        'type': _messageTypeToApi(_selectedType),
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        'attachmentName': _pendingAttachment?.fileName,
        'attachmentMimeType': _pendingAttachment?.mimeType,
        'attachmentBase64': attachmentBase64,
        'attachmentSize': _pendingAttachment?.bytes.length,
      });

      await _pairingService.sendDiscussionMessage(
        relationCode: _remoteRelationCode!,
        senderId: _localDeviceId!,
        content: payload,
        type: _messageKeyForType(_selectedType),
      );

      final now = DateTime.now();
      setState(() {
        _messages.add(
          ChatMessage(
            id: messageId,
            content: content,
            type: _selectedType,
            sentAt: now,
            isMine: true,
            senderId: _localDeviceId!,
            attachmentName: _pendingAttachment?.fileName,
            attachmentMimeType: _pendingAttachment?.mimeType,
            attachmentBase64: attachmentBase64,
            attachmentSize: _pendingAttachment?.bytes.length,
          ),
        );
        _pendingAttachment = null;
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
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickAttachment() async {
    FileType type;
    switch (_selectedType) {
      case MessageType.image:
        type = FileType.image;
        break;
      case MessageType.audio:
        type = FileType.audio;
        break;
      case MessageType.fichier:
        type = FileType.any;
        break;
      case MessageType.texte:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selectionne d abord un type media.')),
        );
        return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
      withData: true,
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lire ce fichier.')),
      );
      return;
    }

    setState(() {
      _pendingAttachment = PendingAttachment(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.extension,
      );
    });
  }

  Future<void> _toggleAudio(ChatMessage message) async {
    if (!message.hasAttachment || message.attachmentBase64 == null) return;

    if (_playingMessageId == message.id) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _playingMessageId = null;
      });
      return;
    }

    final bytes = base64Decode(message.attachmentBase64!);
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(bytes));

    if (!mounted) return;
    setState(() {
      _playingMessageId = message.id;
    });
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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
      'attachmentName': null,
      'attachmentMimeType': null,
      'attachmentBase64': null,
      'attachmentSize': null,
    };
  }

  Widget _buildAttachmentView(ChatMessage message) {
    if (!message.hasAttachment || message.attachmentBase64 == null) {
      return const SizedBox.shrink();
    }

    final bytes = base64Decode(message.attachmentBase64!);

    if (message.type == MessageType.image) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Text(
              'Image non lisible',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    if (message.type == MessageType.audio) {
      final isPlaying = _playingMessageId == message.id;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _toggleAudio(message),
              icon: Icon(
                isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                color: Colors.white,
              ),
            ),
            Text(
              message.attachmentName ?? 'Audio',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${message.attachmentName ?? 'Fichier'}${message.attachmentSize != null ? ' (${message.attachmentSize} o)' : ''}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
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
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            _buildAttachmentView(message),
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
                IconButton(
                  onPressed:
                      _selectedType == MessageType.texte ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _selectedType == MessageType.texte
                          ? 'Ecrire un message...'
                          : 'Legende (optionnelle)',
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
          if (_pendingAttachment != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Piece jointe: ${_pendingAttachment!.fileName} (${_pendingAttachment!.bytes.length} o)',
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _pendingAttachment = null;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}