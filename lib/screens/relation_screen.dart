import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/pairing_service.dart';

/// Type de contenu pour les messages de la discussion.
enum MessageType { texte }

/// Modèle de données représentant un message dans la discussion.
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

  /// Convertit un message en JSON pour le stockage local.
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

  /// Crée un message à partir d'un objet JSON.
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

/// Écran de discussion affichant les messages échangés entre deux appareils appairés.
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
  // Services et Contrôleurs
  final PairingService _pairingService = PairingService();
  final TextEditingController _messageInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // État de la discussion
  Timer? _refreshTimer;
  String? _localRelationCode;
  String? _remoteRelationCode;
  String? _localDeviceId;
  bool _isLoading = true;
  bool _isSendingMessage = false;
  final List<ChatMessage> _messages = <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
    
    // Rafraîchissement automatique de la boîte de réception toutes les 5 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLatestMessages();
    });
  }

  /// Initialise la session de discussion en récupérant les codes et l'historique local.
  Future<void> _initializeChatSession() async {
    final deviceId = await _pairingService.getOrCreateDeviceId();
    String? localCode = widget.initialLocalRelationCode;
    String? remoteCode = widget.initialRemoteRelationCode;

    // Si les codes ne sont pas fournis par la navigation, on les cherche en stockage local
    if (localCode == null || localCode.isEmpty) {
      final savedContext = await _pairingService.getDiscussionContext();
      localCode = savedContext['localRelationCode'];
      remoteCode = savedContext['remoteRelationCode'];
    }

    // Chargement de l'historique local pour un affichage immédiat
    if (localCode != null && localCode.isNotEmpty) {
      final history = await _pairingService.getLocalHistory(localCode);
      _messages
        ..clear()
        ..addAll(history.map(ChatMessage.fromJson));
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      // Mise à jour de la dernière relation active
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
      _isLoading = false;
    });

    // Premier rafraîchissement depuis le serveur
    if (localCode != null && localCode.isNotEmpty) {
      await _fetchLatestMessages();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  /// Récupère les nouveaux messages depuis le serveur.
  Future<void> _fetchLatestMessages() async {
    if (!mounted) return;
    if (_localRelationCode == null || _localRelationCode!.isEmpty) return;

    try {
      final rawElements = await _pairingService.fetchDiscussionMessages(
        _localRelationCode!,
      );
      if (!mounted) return;

      final localId = _localDeviceId ?? '';
      final List<ChatMessage> newIncomingMessages = [];

      for (final raw in rawElements) {
        final elementKey = (raw['key'] ?? 'MESSAGE').toString();
        final value = (raw['value'] ?? '').toString();

        // Cas particulier : message système pour établir ou mettre à jour le canal retour
        if (elementKey.toUpperCase() == 'CHANNEL') {
          final channelData = _parseJsonValue(value);
          final replyCode = (channelData['replyCode'] ?? '').toString();
          if (replyCode.isNotEmpty && replyCode != _remoteRelationCode) {
            _remoteRelationCode = replyCode;
            await _pairingService.saveDiscussionContext(
              localRelationCode: _localRelationCode!,
              remoteRelationCode: replyCode,
            );
            if (mounted) setState(() {});
          }
          continue;
        }

        // Parsing du message utilisateur
        final parsed = _parseJsonValue(value);
        final senderId = (parsed['senderId'] ?? '').toString();
        final content = (parsed['content'] ?? value).toString();
        final rawDate = (parsed['sentAt'] ?? raw['creationDate'] ?? raw['createdAt'])?.toString();

        final messageId = (parsed['messageId'] ?? '${raw['creationDate'] ?? rawDate}_${value.hashCode}').toString();

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

        // On n'ajoute que si le message n'est pas déjà présent localement
        if (message.content.isNotEmpty && !_isAlreadyInHistory(message.id)) {
          newIncomingMessages.add(message);
        }
      }

      if (newIncomingMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(newIncomingMessages);
          _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          
          // Mise à jour de l'appartenance des messages (isMine) au cas où l'ID local aurait changé
          for (var i = 0; i < _messages.length; i++) {
            final m = _messages[i];
            if (m.senderId == localId && !m.isMine) {
              _messages[i] = ChatMessage(
                id: m.id,
                content: m.content,
                type: m.type,
                sentAt: m.sentAt,
                isMine: true,
                senderId: m.senderId,
              );
            }
          }
        });
        await _persistMessagesToLocalStorage();
        _scrollToLastMessage();
      }
    } catch (_) {
      // Les erreurs de rafraîchissement silencieux ne doivent pas perturber l'expérience utilisateur
    }
  }

  /// Envoie le texte saisi au serveur.
  Future<void> _handleSendMessage() async {
    if (_localRelationCode == null || _localRelationCode!.isEmpty) {
      _showSimpleSnackBar('Aucune discussion active. Lance une liaison.');
      return;
    }

    if (_remoteRelationCode == null || _remoteRelationCode!.isEmpty) {
      _showSimpleSnackBar('Connexion en cours... attends quelques secondes.');
      return;
    }

    final messageContent = _messageInputController.text.trim();
    if (messageContent.isEmpty) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final messageId = const Uuid().v4();
      final now = DateTime.now();

      final messagePayload = jsonEncode({
        'messageId': messageId,
        'senderId': _localDeviceId ?? 'unknown',
        'content': messageContent,
        'type': 'texte',
        'sentAt': now.toUtc().toIso8601String(),
      });

      // Envoi au code distant de l'interlocuteur
      await _pairingService.sendDiscussionMessage(
        relationCode: _remoteRelationCode!,
        senderId: _localDeviceId ?? 'unknown',
        content: messagePayload,
        type: 'MESSAGE',
      );

      // Ajout immédiat à l'UI locale pour une sensation de réactivité
      setState(() {
        _messages.add(
          ChatMessage(
            id: messageId,
            content: messageContent,
            type: MessageType.texte,
            sentAt: now,
            isMine: true,
            senderId: _localDeviceId ?? 'unknown',
          ),
        );
      });
      
      await _persistMessagesToLocalStorage();
      _messageInputController.clear();
      _scrollToLastMessage();
      
    } catch (e) {
      if (!mounted) return;
      _showSimpleSnackBar('Échec de l\'envoi : ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  /// Vérifie si un message est déjà présent dans la liste actuelle.
  bool _isAlreadyInHistory(String id) {
    return _messages.any((m) => m.id == id);
  }

  /// Sauvegarde l'état actuel de la discussion en stockage sécurisé.
  Future<void> _persistMessagesToLocalStorage() async {
    if (_localRelationCode == null || _localRelationCode!.isEmpty) return;
    await _pairingService.saveLocalHistory(
      _localRelationCode!,
      _messages.map((m) => m.toJson()).toList(),
    );
  }

  /// Fait défiler la liste vers le bas pour afficher le dernier message.
  void _scrollToLastMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Formate l'heure d'envoi.
  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Helper pour parser du JSON ou retourner un fallback texte.
  Map<String, dynamic> _parseJsonValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {'content': value, 'type': 'texte', 'senderId': ''};
  }

  void _showSimpleSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Construit une bulle de message individuelle.
  Widget _buildMessageBubble(ChatMessage message) {
    final isMine = message.isMine;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMine ? Colors.lightBlue : Colors.grey.shade900;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.chat_bubble_outline, size: 12, color: Colors.white70),
                SizedBox(width: 6),
                Text('Texte', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatDateTime(message.sentAt),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
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
        elevation: 0,
      ),
      body: Column(
        children: [
          // Bandeau d'information sur les codes de liaison
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            color: Colors.grey.shade900.withOpacity(0.5),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local: ${_localRelationCode?.substring(0, 8) ?? '-'}... | Distant: ${_remoteRelationCode?.substring(0, 8) ?? '-'}...',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // Zone des messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_localRelationCode == null || _localRelationCode!.isEmpty)
                ? const Center(
                    child: Text(
                      'Aucune discussion active.\nScannez un QR Code pour commencer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text('Aucun message échangé.', style: TextStyle(color: Colors.white70)),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                  ),
          ),

          // Barre de saisie
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageInputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Écrire un message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    child: IconButton(
                      onPressed: _isSendingMessage ? null : _handleSendMessage,
                      icon: _isSendingMessage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
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
