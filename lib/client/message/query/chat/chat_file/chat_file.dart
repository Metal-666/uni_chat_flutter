import 'dart:typed_data';

class ChatFile {
  String key, chatKey, extension, name, data, destination;
  Uint8List bytes;
  bool isDownloading = false;

  ChatFile(
      {this.key,
      this.chatKey,
      this.extension,
      this.name,
      this.data,
      this.destination});

  Map toJson() => {
        if (key != null) "key": key,
        if (chatKey != null) "chatKey": chatKey,
        if (extension != null) "extension": extension,
        if (name != null) "name": name,
        if (data != null) "data": data,
        if (destination != null) "destination": destination
      };

  static ChatFile fromJson(dynamic json) {
    return ChatFile(
        key: json["key"],
        chatKey: json["chatKey"],
        extension: json["extension"],
        name: json["name"],
        data: json["data"],
        destination: json["destination"]);
  }
}

class ChatFileDestination {
  static const String DOWNLOAD = "DOWNLOAD",
      CHAT_STORAGE = "CHAT_STORAGE",
      ENLARGED_MESSAGE = "ENLARGED_MESSAGE";
}
