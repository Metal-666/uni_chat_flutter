import "chat/chat.dart";
import 'chat/chat_message/chat_message.dart';
import 'chat/chat_file/chat_file.dart';

class Query {
  List<Chat> chatList;

  Chat chat;

  ChatMessage chatMesage;

  ChatFile file;

  Query({this.chatList, this.chat, this.chatMesage, this.file});

  Map toJson() => {
        if (chatList != null) "chatList": chatList,
        if (chat != null) "chat": chat,
        if (chatMesage != null) "chatMesage": chatMesage,
        if (file != null) "file": file
      };

  factory Query.fromJson(dynamic json) {
    List<Chat> chatList = [];
    json["chatList"]?.forEach((item) {
      chatList.add(Chat.fromJson(item));
    });
    return Query(
        chatList: chatList,
        chat: json["chat"] != null ? Chat.fromJson(json["chat"]) : null,
        chatMesage: json["chatMesage"] != null
            ? ChatMessage.fromJson(json["chatMesage"])
            : null,
        file: json["file"] != null ? ChatFile.fromJson(json["file"]) : null);
  }
}
