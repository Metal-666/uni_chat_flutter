import 'dart:async';
import "dart:convert";
import 'dart:io';
import 'dart:typed_data';

import "package:flutter/material.dart" hide Actions;
import "package:flutter_icons/flutter_icons.dart";
import 'package:uni_chat/chat/chat_room.dart';
import 'package:uni_chat/client/message/query/chat/chat_file/chat_file.dart';
import 'package:uni_chat/preference_manager.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'message/actions.dart';
import 'message/core/core.dart';
import 'message/error/error.dart';
import 'message/message.dart';
import 'message/query/chat/chat.dart';
import 'message/query/query.dart';

Status status = Status.disconnected;

const String defaultAddress = "ws://metal666-server.pp.ua:2052";

WebSocketChannel webSocket;

StateSetter _setter;

class Client {
  static String key;

  static Function onData, onDisconnected;

  static List<ChatRoom> activeChatRooms = [];

  static List<Chat> anonymousChatList = [], accessibleChatList = [];

  static StreamSubscription webSocketSubscription;

  static Map<String, Pair<String, String>> filesToUpload = {};

  static List<ChatFile> enlargedMessageFiles = [];
  static StateSetter enlargedMessageStateSetter;

  static reverseAction() {
    switch (status) {
      case Status.connected:
      case Status.connecting:
        stop();
        break;
      case Status.disconnected:
        start(_setter, false);
        break;
    }
  }

  static start(StateSetter setState, bool firstTime) {
    _setter = setState;
    print("connecting");
    if (!firstTime ||
        PreferenceManager.getPreference(Preferences.autoconnect) == "true") {
      webSocket = IOWebSocketChannel.connect(getIp());
      _setter(() => status = Status.connecting);
      webSocketSubscription = webSocket.stream.listen(
          (data) => _onMessage(data),
          onError: (error) => stop(),
          cancelOnError: true,
          onDone: () => stop());
      send(Message(Core(Actions.PING)));
    }
  }

  static _onMessage(data) {
    print("received a message: " + data);
    Message message = Message.fromJson(jsonDecode(data));
    if (message.core?.action != null) {
      switch (message.core.action) {
        case Actions.PONG:
          if (status != Status.connected) {
            _setter(() => status = Status.connected);
            onData?.call(message.core.action, null);
          }
          Timer(Duration(minutes: 1), () {
            send(Message(Core(Actions.PING)));
          });
          break;
        case Actions.LOGIN_ANONYMOUS:
          if (message.core.key != null) {
            key = message.core.key;
            onData?.call(message.core.action, null);
          } else {
            sendError(false, "No key specified");
          }
          break;
        case Actions.LIST_CHAT_ROOMS:
          _setter(() => Client.anonymousChatList = message.query?.chatList);
          break;
        case Actions.LIST_ACCESSIBLE_CHAT_ROOMS:
          _setter(() => Client.accessibleChatList = message.query?.chatList);
          break;
        case Actions.JOIN_CHAT_ROOM:
          activeChatRooms.add(ChatRoom(message.query?.chat));
          onData?.call(message.core.action, message.query?.chat);
          break;
        case Actions.REMOVE_CHAT_ROOM:
          _setter(() => Client.anonymousChatList
              .removeWhere((chat) => chat.key == message.query?.chat?.key));
          break;
        case Actions.ADD_CHAT_ROOM:
          _setter(() => Client.anonymousChatList.add(message.query?.chat));
          break;
        case Actions.GET_CHAT_FILES:
          _setter(() => accessibleChatList
              .firstWhere((chat) => chat.key == message.query?.chat?.key)
              .files = message.query?.chat?.files);
          break;
        case Actions.UNLOCK_CHAT_ROOM:
          _setter(() => Client.anonymousChatList
              .firstWhere((chat) => chat.key == message.query?.chat?.key)
              .password = ChatRoomProtectoionStatus.UNLOCKED);
          break;
        case Actions.LEAVE_CHAT_ROOM:
          int index = activeChatRooms.indexWhere(
              (chatRoom) => chatRoom.chat.key == message.query?.chat?.key);
          activeChatRooms.removeAt(index);
          onData?.call(message.core.action, index);
          break;
        case Actions.GET_FILE:
          switch (message.query?.file?.destination) {
            case ChatFileDestination.CHAT_STORAGE:
              ChatFile file = activeChatRooms
                  .firstWhere(
                      (chat) => chat.chat.key == message.query?.chat?.key)
                  .chat
                  .files
                  .firstWhere((file) => file.key == message.query?.file?.key);
              file.data = message.query?.file?.data;
              _setter(() => file.bytes = base64.decode(file.data));
              break;
            case ChatFileDestination.DOWNLOAD:
              Directory directory = Directory(
                  PreferenceManager.getPreference(Preferences.downloadsDir));
              if (message.query.file != null && directory.existsSync()) {
                File file = File(
                    "${directory.path}/${message.query.file.name}.${message.query.file.extension}");
                if (file.existsSync()) {
                  file.deleteSync();
                }
                file.createSync();
                print(file.existsSync());
                file.writeAsBytesSync(base64.decode(message.query.file.data),
                    flush: true);
              }
              break;
            case ChatFileDestination.ENLARGED_MESSAGE:
              enlargedMessageStateSetter?.call(() {
                ChatFile file = enlargedMessageFiles.firstWhere((file) =>
                    file.key == message.query.file.key &&
                    file.chatKey == message.query.file.chatKey);
                file.data = message.query.file.data;
                file.bytes = base64.decode(file.data);
              });
              break;
          }
          break;
        case Actions.GET_FILE_META:
          switch (message.query?.file?.destination) {
            case ChatFileDestination.ENLARGED_MESSAGE:
              enlargedMessageStateSetter
                  ?.call(() => enlargedMessageFiles.add(message.query.file));
              break;
          }
          break;
        case Actions.START_FILE_UPLOAD:
          String key = message.query.file.key;
          String path = message.query.file.name;
          String extension = filesToUpload[message.query.file.name].b;
          File(path).readAsBytes().then((bytes) {
            String data = base64.encode(bytes);
            String name = filesToUpload[message.query.file.name].a;
            send(Message(Core(Actions.UPLOAD_FILE),
                query: Query(
                    file: ChatFile(
                        data: data,
                        key: key,
                        extension: extension,
                        name: extension == null
                            ? name
                            : name.substring(
                                0, name.length - extension.length - 1)))));
            filesToUpload.remove(message.query.file.name);
          });
          break;
        case Actions.ADD_CHAT_MESSAGE:
          if (message.query?.chatMesage != null) {
            _setter(() => activeChatRooms
                .firstWhere(
                    (chatRoom) => chatRoom.chat.key == message.query.chat.key)
                ?.chat
                ?.messages
                ?.add(message.query.chatMesage));
          }
          break;
        case Actions.ADD_CHAT_FILE:
          if (message.query?.file != null) {
            _setter(() => activeChatRooms
                .firstWhere(
                    (chatRoom) => chatRoom.chat.key == message.query.chat.key)
                ?.chat
                ?.files
                ?.add(message.query.file));
          }
          break;
        case Actions.CHANGE_ANONYMOUS_NAME:
          onData?.call(message.core.action, message.auth.username);
      }
    } else {
      sendError(false, "No action specified");
    }
  }

  static stop() {
    print("stopping client");
    webSocket?.sink?.close();
    webSocket = null;
    webSocketSubscription?.cancel();

    _setter(() {
      status = Status.disconnected;
      activeChatRooms.clear();
      anonymousChatList.clear();
      onDisconnected?.call();
    });
  }

  static send(Message message) {
    message.core.key ??= key;
    webSocket?.sink?.add(jsonEncode(message));
  }

  static sendBinary(Uint8List bytes) {
    webSocket?.sink?.add(bytes);
  }

  static sendError(bool clientOtherwiseServer, String text) {
    send(Message(Core(Actions.ERROR),
        error: Error(
            type: clientOtherwiseServer ? ErrorTypes.CLIENT : ErrorTypes.SERVER,
            message: text)));
  }

  static String getIp() {
    String ip = PreferenceManager.getPreference(Preferences.serverAddress);
    if (ip == null || ip.isEmpty) {
      return defaultAddress;
    } else {
      return ip;
    }
  }

  static IconData getStatusIcon() {
    IconData data;
    switch (status) {
      case Status.connected:
        data = MaterialCommunityIcons.server_network;
        break;
      case Status.disconnected:
        data = MaterialCommunityIcons.server_network_off;
        break;
      case Status.connecting:
        data = Icons.compare_arrows;
        break;
    }
    return data;
  }

  static String getStatusText() {
    String text;
    switch (status) {
      case Status.connected:
        text = "connected";
        break;
      case Status.disconnected:
        text = "disconnected";
        break;
      case Status.connecting:
        text = "connecting";
        break;
    }
    return text;
  }

  static String getStatusActionText() {
    String text;
    switch (status) {
      case Status.connected:
        text = "disconnect";
        break;
      case Status.disconnected:
        text = "connect";
        break;
      case Status.connecting:
        text = "cancel";
        break;
    }
    return text;
  }
}

enum Status { connected, connecting, disconnected }

class ChatRoomProtectoionStatus {
  static const LOCKED = "LOCKED", UNLOCKED = "UNLOCKED";
}

class Pair<T1, T2> {
  final T1 a;
  final T2 b;

  Pair(this.a, this.b);
}
