import 'package:uni_chat/client/message/query/chat/chat_file/chat_file.dart';

class ChatMessage {
  String key, text, type, creator;
  int timestamp;
  List<ChatFile> files;
  ChatMessage(
      {this.key,
      this.text,
      this.type,
      this.creator,
      this.files,
      this.timestamp});

  Map toJson() => {
        if (key != null) "key": key,
        if (text != null) "text": text,
        if (type != null) "type": type,
        if (creator != null) "creator": creator,
        if (files != null) "files": files,
        if (timestamp != null) "timestamp": timestamp
      };

  factory ChatMessage.fromJson(dynamic json) {
    List<ChatFile> files = [];
    json["files"]?.forEach((item) {
      files.add(ChatFile.fromJson(item));
    });
    return ChatMessage(
        key: json["key"],
        text: json["text"],
        type: json["type"],
        creator: json["creator"],
        files: files,
        timestamp: json["timestamp"]);
  }
}

class ChatMessageTypes {
  static const BASIC = "BASIC", META = "META";
}
