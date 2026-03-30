import 'package:flutter/material.dart';
import 'dart:async';
import '../services/pairing_service.dart';

enum MessageType { texte, image, audio, fichier }

class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool isMine;

  const ChatMessage({
    required this.content,
    required this.type,
    required this.sentAt,
    required this.isMine,
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
  bool _isLoadingRelation = true;
  final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      content: 'Salut, la liaison est active.',
      type: MessageType.texte,
      sentAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isMine: false,
    ),
    ChatMessage(
      content: 'Top, on peut discuter ici.',
      type: MessageType.texte,
      sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
      isMine: true,
    ),
  ];

  int _mockRemoteCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeRelation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMessages();
    });
  }

  Future<void> _initializeRelation() async {
    final fromRoute = widget.initialRelationCode;
    if (fromRoute != null && fromRoute.isNotEmpty) {
      await _pairingService.saveLastRelationCode(fromRoute);
      if (!mounted) return;
      setState(() {
        _activeRelationCode = fromRoute;
        _isLoadingRelation = false;
      });
      return;
    }

    final savedRelation = await _pairingService.getLastRelationCode();
    if (!mounted) return;
    setState(() {
      _activeRelationCode = savedRelation;
      _isLoadingRelation = false;
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshMessages() {
    if (!mounted) return;
    if (_activeRelationCode == null || _activeRelationCode!.isEmpty) return;

    // Simulation d'un message distant a chaque cycle pair.
    if (_mockRemoteCounter % 2 == 0) {
      setState(() {
        _messages.add(
          ChatMessage(
            content: 'Message recu automatiquement (${_mockRemoteCounter ~/ 2 + 1})',
            type: MessageType.texte,
            sentAt: DateTime.now(),
            isMine: false,
          ),
        );
      });
      _scrollToBottom();
    }

    _mockRemoteCounter++;
  }

  void _sendMessage() {
    if (_activeRelationCode == null || _activeRelationCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune discussion active. Lance une liaison.')),
      );
      return;
    }

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          content: content,
          type: _selectedType,
          sentAt: DateTime.now(),
          isMine: true,
        ),
      );
    });

    _messageController.clear();
    _scrollToBottom();
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
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.lightBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}