import 'package:flutter/foundation.dart';
import '../../data/repositories/gig_repository.dart';
import 'models/chat_message.dart';


class ChatViewModel extends ChangeNotifier {
  ChatViewModel(this._repo);
  
  //final GigRepository _repo;
  List<ChatMessage> _messages = [];
  bool isLoading = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Simulates fetching the conversation log for the active matched gig workspace
  void load() {
    isLoading = true;
    notifyListeners();

    // Matching names/contexts from your client's design specifications
    _messages = [
      const ChatMessage(
        id: 'm1', 
        text: "Hey! I saw your swipe on my Wig Install gig.", 
        isMe: false, 
        timestamp: "2:10 PM",
      ),
      const ChatMessage(
        id: 'm2', 
        text: "Yes! Is it still available for tomorrow?", 
        isMe: true, 
        timestamp: "2:12 PM",
      ),
      const ChatMessage(
        id: 'm3', 
        text: "Yes it is! Can you come over by 2 PM tomorrow?", 
        isMe: false, 
        timestamp: "2:13 PM",
      ),
    ];

    isLoading = false;
    notifyListeners();
  }

  /// Appends a new chat bubble locally to the message history log stream
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final newMsg = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      isMe: true,
      timestamp: "Just now",
    );

    _messages = [..._messages, newMsg];
    notifyListeners();
  }
}
