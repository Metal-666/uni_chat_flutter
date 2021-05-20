import 'banner/banner.dart';
import 'chat_file/chat_file.dart';
import 'chat_message/chat_message.dart';

class Chat {
  String key, name, description, password;

  List<ChatMessage> messages;
  List<ChatFile> files;

  Banner banner;

  Chat(
      {this.key,
      this.name,
      this.description,
      this.messages,
      this.files,
      this.password,
      this.banner});

  Map toJson() => {
        "key": key,
        if (name != null) "name": name,
        if (description != null) "description": description,
        if (password != null) "password": password,
        if (messages != null) "messages": messages,
        if (files != null) "files": files,
        if (banner != null) "banner": banner
      };

  factory Chat.fromJson(dynamic json) {
    List<ChatMessage> messages = [];
    json["messages"]?.forEach((item) {
      messages.add(ChatMessage.fromJson(item));
    });
    List<ChatFile> files = [];
    json["files"]?.forEach((item) {
      files.add(ChatFile.fromJson(item));
    });
    return Chat(
        key: json["key"],
        name: json["name"],
        description: json["description"],
        password: json["password"],
        messages: messages,
        files: files,
        banner:
            json["banner"] != null ? Banner.fromJson(json["banner"]) : null);
  }
}
