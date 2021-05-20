import 'package:uni_chat/client/message/query/chat/chat.dart';

class ChatRoom {
  Chat chat;
  List<User> users = [];
  ChatRoom(this.chat);
}

class User {
  String key, name;
  User({this.key, this.name});
}
