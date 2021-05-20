import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import "package:after_layout/after_layout.dart";
import "package:collapsible/collapsible.dart";
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/gestures.dart';
import "package:flutter/material.dart" hide Actions;
import 'package:flutter/services.dart';
import "package:flutter_icons/flutter_icons.dart";
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

import "client/account.dart";
import 'client/client.dart';
import "client/message/actions.dart";
import 'client/message/auth/auth.dart';
import "client/message/core/core.dart";
import "client/message/message.dart";
import "client/message/query/chat/chat.dart";
import 'client/message/query/chat/chat_file/chat_file.dart';
import 'client/message/query/chat/chat_message/chat_message.dart';
import 'client/message/query/query.dart';
import 'extensions.dart';
import 'preference_manager.dart';

final ThemeData lightTheme = commonThemeData(ThemeData(
        fontFamily: "Designer",
        primarySwatch: Colors.deepPurple,
        accentColor: Colors.purple,
        hintColor: Colors.grey[300],
        brightness: Brightness.light)),
    darkTheme = commonThemeData(ThemeData(
        fontFamily: "Designer",
        primarySwatch: Colors.purple,
        accentColor: Colors.purple[200],
        hintColor: Colors.grey[300],
        toggleableActiveColor: Colors.purple[200],
        brightness: Brightness.dark));

ThemeData commonThemeData(ThemeData data) {
  return data.copyWith(
      textTheme: data.textTheme.copyWith(
          button: data.textTheme.button.copyWith(fontSize: 22),
          bodyText1: data.textTheme.bodyText1.copyWith(fontSize: 30),
          bodyText2: data.textTheme.bodyText2.copyWith(fontSize: 18),
          subtitle2: data.textTheme.subtitle2.copyWith(fontSize: 18)));
}

SlidableController _drawerSettingsController = SlidableController();

bool tabsFit(context) {
  /*double screenWidth = MediaQuery.of(context).size.width;
  int totalCharacters = 0;
  Client.activeChatRooms
      .forEach((chatRoom) => totalCharacters += chatRoom.chat.name.length);
  return screenWidth / totalCharacters > 2;*/
  return Client.activeChatRooms.length < 4;
}

final _discordUrl = "https://discord.gg/Y2NYhAtP",
    _telegramUrl = "https://t.me/metal6_6_6",
    _githubUrl = "https://github.com/Metal-666",
    _mailUrl = "mailto:1heavyjack@gmail.com?subject=UniChat&body=Message";

final imageExtensions = ["jpg", "jpeg", "png", "webp", "gif"],
    documentExtensions = [
      "docx",
      "doc",
      "xlsx",
      "xls",
      "pptx",
      "ppt",
      "pdf",
      "txt"
    ];

Future main() async {
  print("starting app");
  //debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  await PreferenceManager.init();
  Account.init();
  runApp(EasyDynamicThemeWidget(child: MyApp()));
}

void openLink(url, context) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Error opening url"),
    ));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "UniChat",
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: EasyDynamicTheme.of(context).themeMode,
      home: MyHomePage(),
    );
  }
}

TabController _chatTabsController;

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

bool _isGridOpen = false;

class _MyHomePageState extends State<MyHomePage>
    with AfterLayoutMixin<MyHomePage>, TickerProviderStateMixin {
  TextEditingController _settingServerAddressController = TextEditingController(
      text: PreferenceManager.getPreference(Preferences.serverAddress));
  bool _accountsDropdownOpen = false,
      _isNewChatPanelOpen = false,
      _settingAutoconnect = false;

  final List<Tab> accountTabs = <Tab>[
        Tab(icon: Icon(MaterialCommunityIcons.incognito)),
        Tab(icon: Icon(MaterialCommunityIcons.account_circle_outline)),
      ],
      chatRoomTabs = <Tab>[];

  double _settingLayoutMode = 0;

  int _currentChatRoom = 0; //, _textAnimation = 0;

  void recreateChatTabsController() {
    setState(() {
      _chatTabsController?.dispose();
      _chatTabsController =
          TabController(length: Client.activeChatRooms.length, vsync: this);
      _chatTabsController.addListener(
          () => setState(() => _currentChatRoom = _chatTabsController.index));
    });
  }

  /*Timer textAnimationTimer;

  void setupTextAnimationTimer() {
    textAnimationTimer?.cancel();
    textAnimationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        if (++_textAnimation == 4) {
          _textAnimation = 0;
        }
      });
    });
  }*/

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    recreateChatTabsController();
    var settingLayoutMode =
        PreferenceManager.getPreference(Preferences.layoutMode);
    _settingLayoutMode =
        settingLayoutMode == null ? 0 : double.parse(settingLayoutMode);
    var settingAutoconnect =
        PreferenceManager.getPreference(Preferences.autoconnect);
    _settingAutoconnect =
        settingAutoconnect == null ? false : settingAutoconnect == "true";
    //setupTextAnimationTimer();
  }

  @override
  void dispose() {
    _chatTabsController.dispose();
    _settingServerAddressController.dispose();
    Client.stop();
    super.dispose();
  }

  @override
  void afterFirstLayout(BuildContext context) async {
    Client.onDisconnected = () {
      chatRoomTabs.clear();
      recreateChatTabsController();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Disconnected from the server"),
      ));
    };
    Client.onData = (String action, data) async {
      switch (action) {
        case Actions.PONG:
          Client.send(Message(Core(Actions.LOGIN_ANONYMOUS),
              auth: Auth(username: Account.name)));
          break;
        case Actions.LOGIN_ANONYMOUS:
          Client.send(Message(Core(Actions.LIST_CHAT_ROOMS)));
          break;
        case Actions.JOIN_CHAT_ROOM:
          setState(() {
            chatRoomTabs.add(Tab(
              text: data.name,
            ));
            recreateChatTabsController();
          });
          break;
        case Actions.LEAVE_CHAT_ROOM:
          setState(() {
            chatRoomTabs.removeAt(data);
            recreateChatTabsController();
          });
          break;
        case Actions.CHANGE_ANONYMOUS_NAME:
          await PreferenceManager.setPreference(
              Preferences.anonymousName, data);
          setState(() {
            Account.name = data;
          });
          Navigator.of(context).pop();
          break;
      }
    };
    Client.start(setState, true);
  }

  @override
  Widget build(BuildContext context) {
    Color appBarTextColor = Client.activeChatRooms.length == 0 ||
            Client.activeChatRooms[_currentChatRoom].chat.banner?.background ==
                null
        ? Colors.white
        : HexColor.fromHex(Client.activeChatRooms[_currentChatRoom].chat.banner
                        ?.background)
                    .computeLuminance() >
                0.5
            ? Colors.black
            : Colors.white;
    /*if (Client.activeChatRooms.length != 0) {
      textAnimationTimer.cancel();
    } else {
      setupTextAnimationTimer();
    }*/
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
          iconTheme: IconThemeData(color: appBarTextColor),
          title: Text("UniChat",
              style: TextStyle(fontSize: 30, color: appBarTextColor)),
          elevation: 12,
          actions: [
            IconButton(
              icon: Icon(
                Client.getStatusIcon(),
                color: appBarTextColor,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Status: ${Client.getStatusText()}"),
                  action: SnackBarAction(
                    label: Client.getStatusActionText(),
                    textColor: Theme.of(context).accentColor,
                    onPressed: () => Client.reverseAction(),
                  ),
                ));
              },
            )
          ],
          flexibleSpace: AnimatedContainer(
            decoration: Client.activeChatRooms.length == 0 ||
                    Client.activeChatRooms[_currentChatRoom].chat.banner
                            ?.background ==
                        null
                ? BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Colors.deepPurple, Colors.purple]))
                : BoxDecoration(
                    color: HexColor.fromHex(Client
                        .activeChatRooms[_currentChatRoom]
                        .chat
                        .banner
                        .background)),
            duration: Duration(microseconds: 200),
          ),
          bottom: Client.activeChatRooms.length == 0
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(30),
                  child: (_settingLayoutMode == 0 ||
                          (_settingLayoutMode == 1 && tabsFit(context)))
                      ? TabBar(
                          controller: _chatTabsController,
                          tabs: chatRoomTabs
                              .map((tab) => Tab(
                                    icon: tab.icon,
                                    text: tab.text,
                                  ))
                              .toList(),
                          labelStyle: TextStyle(fontSize: 18),
                          unselectedLabelColor: appBarTextColor,
                          labelColor: appBarTextColor,
                          indicatorColor: appBarTextColor,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                Client.activeChatRooms[_currentChatRoom].chat
                                    .name,
                                style: TextStyle(
                                    fontSize: 24, color: appBarTextColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                                icon:
                                    Icon(Icons.grid_on, color: appBarTextColor),
                                onPressed: () =>
                                    setState(() => _isGridOpen = !_isGridOpen))
                          ],
                        ))),
      body: Client.activeChatRooms.length == 0
          ? Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Use drawer on the\nleft to login . . .",
                          style: TextStyle(
                              fontSize: 28,
                              color:
                                  Theme.of(context).textTheme.caption.color))),
                  Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(". . . then connect to a\nchat and have fun!",
                        style: TextStyle(
                            fontSize: 28,
                            color: Theme.of(context).textTheme.caption.color)),
                  ),
                ],
              ))
          : GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus.unfocus();
                setState(() => _isGridOpen = false);
              },
              child: Stack(
                children: [
                  Container(
                    child: (_settingLayoutMode == 0 ||
                            (_settingLayoutMode == 1 && tabsFit(context)))
                        ? TabBarView(
                            controller: _chatTabsController,
                            children: List.generate(
                                Client.activeChatRooms.length, (index) {
                              return _ChatRoomWidget(
                                  Client.activeChatRooms[index].chat);
                            }))
                        : _ChatRoomWidget(
                            Client.activeChatRooms[_currentChatRoom].chat),
                  ),
                  Collapsible(
                    maintainState: true,
                    collapsed: !_isGridOpen,
                    axis: CollapsibleAxis.vertical,
                    child: Container(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(75),
                        ),
                        BoxShadow(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            spreadRadius: -1,
                            blurRadius: 2)
                      ]),
                      child: GridView.count(
                        padding: EdgeInsets.all(6),
                        childAspectRatio: 0.75,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        crossAxisCount: 3,
                        children: List.generate(Client.activeChatRooms.length,
                            (index) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() {
                                _isGridOpen = false;
                                _currentChatRoom = index;
                                _chatTabsController.index = index;
                              }),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Text(
                                      Client.activeChatRooms[index].chat.name,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      drawer: Drawer(
        child: GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus.unfocus();
          },
          child: Slidable(
            controller: _drawerSettingsController,
            direction: Axis.vertical,
            fastThreshold: 100,
            actionExtentRatio: 1,
            secondaryActions: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Chat layout mode",
                          style: TextStyle(fontSize: 20),
                        )),
                    SliderTheme(
                      data: SliderThemeData(),
                      child: Slider(
                        max: 2,
                        min: 0,
                        divisions: 2,
                        onChanged: (newValue) {
                          _isGridOpen = false;
                          setState(() => _settingLayoutMode = newValue);
                          PreferenceManager.setPreference(
                              Preferences.layoutMode,
                              newValue.toInt().toString());
                        },
                        value: _settingLayoutMode,
                      ),
                    ),
                    Text(
                      _settingLayoutMode == 0
                          ? "Tabs"
                          : _settingLayoutMode == 1
                              ? "Adaptive"
                              : _settingLayoutMode == 2
                                  ? "Grid"
                                  : "?",
                    ),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            "Server address",
                            style: TextStyle(fontSize: 20),
                          ),
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _settingServerAddressController,
                            decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                hintText: defaultAddress),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.compare_arrows),
                          onPressed: () {
                            PreferenceManager.setPreference(
                                Preferences.serverAddress,
                                _settingServerAddressController.text);
                            Client.stop();
                            Client.start(setState, false);
                            FocusManager.instance.primaryFocus.unfocus();
                          },
                        )
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "Autoconnect on startup",
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        Switch(
                          onChanged: (bool value) {
                            PreferenceManager.setPreference(
                                Preferences.autoconnect, value.toString());
                            setState(() => _settingAutoconnect = value);
                          },
                          value: _settingAutoconnect,
                        )
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text("Files folder"),
                        ),
                        IconButton(
                            icon: Icon(Icons.folder_outlined),
                            onPressed: () async => FilesystemPicker.open(
                                    title: 'Save files to',
                                    context: context,
                                    fsType: FilesystemType.folder,
                                    folderIconColor: Colors.deepPurple,
                                    rootName: "Downloads",
                                    fileTileSelectMode:
                                        FileTileSelectMode.wholeTile,
                                    rootDirectory: Directory(await ExtStorage
                                        .getExternalStoragePublicDirectory(
                                            ExtStorage.DIRECTORY_DOWNLOADS)),
                                    requestPermission: () async =>
                                        await Permission.storage
                                            .request()
                                            .isGranted).then((path) {
                                  if (path != null)
                                    PreferenceManager.setPreference(
                                        Preferences.downloadsDir, path);
                                }))
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text("Screenshots folder"),
                        ),
                        IconButton(
                            icon: Icon(Icons.folder_outlined),
                            onPressed: () async => FilesystemPicker.open(
                                    title: 'Save screenshots to',
                                    context: context,
                                    fsType: FilesystemType.folder,
                                    folderIconColor: Colors.deepPurple,
                                    rootName: "Downloads",
                                    fileTileSelectMode:
                                        FileTileSelectMode.wholeTile,
                                    rootDirectory: Directory(await ExtStorage
                                        .getExternalStoragePublicDirectory(
                                            ExtStorage.DIRECTORY_DOWNLOADS)),
                                    requestPermission: () async =>
                                        await Permission.storage
                                            .request()
                                            .isGranted).then((path) {
                                  if (path != null)
                                    PreferenceManager.setPreference(
                                        Preferences.screenshotsDir, path);
                                }))
                      ],
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          children: [
                            Expanded(
                                child: IconButton(
                              icon: Icon(
                                MaterialCommunityIcons.discord,
                                color:
                                    Theme.of(context).textTheme.caption.color,
                              ),
                              iconSize: 30,
                              onPressed: () => openLink(_discordUrl, context),
                            )),
                            Expanded(
                                child: IconButton(
                              icon: Icon(
                                MaterialCommunityIcons.telegram,
                                color:
                                    Theme.of(context).textTheme.caption.color,
                              ),
                              iconSize: 30,
                              onPressed: () => openLink(_telegramUrl, context),
                            )),
                            Expanded(
                                child: IconButton(
                              icon: Icon(
                                Feather.github,
                                color:
                                    Theme.of(context).textTheme.caption.color,
                              ),
                              iconSize: 30,
                              onPressed: () => openLink(_githubUrl, context),
                            )),
                            Expanded(
                                child: IconButton(
                              icon: Icon(
                                MaterialCommunityIcons.gmail,
                                color:
                                    Theme.of(context).textTheme.caption.color,
                              ),
                              iconSize: 30,
                              onPressed: () => openLink(_mailUrl, context),
                            ))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
            actionPane: SlidableDrawerActionPane(),
            child: DefaultTabController(
              length: accountTabs.length,
              child: Container(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                      offset: Offset(0, 2),
                      color: Colors.black.withAlpha(75),
                      blurRadius: 2)
                ], color: Theme.of(context).scaffoldBackgroundColor),
                child: Column(
                  children: [
                    UserAccountsDrawerHeader(
                      margin: EdgeInsets.zero,
                      accountEmail: Text(Account.email),
                      accountName: Text(Account.name),
                      currentAccountPicture: CircleAvatar(),
                      onDetailsPressed: () {
                        setState(() {
                          _accountsDropdownOpen = !_accountsDropdownOpen;
                        });
                      },
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.purple, Colors.deepPurple],
                              end: Alignment.bottomCenter,
                              begin: Alignment.topCenter)),
                    ),
                    Container(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                            offset: Offset(0, 2),
                            color: Colors.black.withAlpha(75),
                            blurRadius: 2)
                      ], color: Theme.of(context).scaffoldBackgroundColor),
                      child: Collapsible(
                        collapsed: !_accountsDropdownOpen,
                        axis: CollapsibleAxis.vertical,
                        child: TabBar(
                          tabs: accountTabs,
                          labelStyle: TextStyle(fontSize: 18),
                          labelColor: Theme.of(context).accentColor,
                          unselectedLabelColor: Theme.of(context).hintColor,
                        ),
                        maintainState: true,
                      ),
                    ),
                    Expanded(
                      child: Stack(children: [
                        TabBarView(
                            physics: _accountsDropdownOpen
                                ? ClampingScrollPhysics()
                                : NeverScrollableScrollPhysics(),
                            children: [
                              Column(
                                children: [
                                  Collapsible(
                                    collapsed: !_accountsDropdownOpen,
                                    axis: CollapsibleAxis.vertical,
                                    maintainState: true,
                                    child: Column(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            if (Client.activeChatRooms.length >
                                                0) {
                                              Navigator.of(context).pop();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    "You can't change your name while connected to a chat room"),
                                              ));
                                            } else {
                                              showDialog(
                                                  context: context,
                                                  builder: (builder) {
                                                    TextEditingController
                                                        controller =
                                                        TextEditingController(
                                                            text: Account.name);
                                                    return AlertDialog(
                                                      title:
                                                          Text("Pick a name"),
                                                      content: TextField(
                                                        controller: controller,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              OutlineInputBorder(),
                                                          labelText:
                                                              Account.name,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: Text("Cancel"),
                                                          style: TextButton.styleFrom(
                                                              primary: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                        ),
                                                        TextButton(
                                                            onPressed: () => Client.send(Message(
                                                                Core(Actions
                                                                    .CHANGE_ANONYMOUS_NAME),
                                                                auth: Auth(
                                                                    username:
                                                                        controller
                                                                            .text))),
                                                            style: TextButton.styleFrom(
                                                                backgroundColor:
                                                                    Theme.of(
                                                                            context)
                                                                        .accentColor,
                                                                primary: Theme.of(
                                                                        context)
                                                                    .dialogBackgroundColor),
                                                            child: Text("Done"))
                                                      ],
                                                    );
                                                  });
                                            }
                                          },
                                          label: Text("Change name"),
                                          icon: Icon(Icons.edit),
                                          style: ElevatedButton.styleFrom(
                                              primary: Client.activeChatRooms
                                                          .length >
                                                      0
                                                  ? Theme.of(context)
                                                      .disabledColor
                                                  : Theme.of(context)
                                                      .buttonColor),
                                        ),
                                        Divider()
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.all(0),
                                      itemCount:
                                          Client.anonymousChatList.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final Chat chat =
                                            Client.anonymousChatList[index];
                                        SlidableController itemController =
                                            SlidableController();
                                        return Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: Slidable(
                                            closeOnScroll: true,
                                            controller: itemController,
                                            actions: chat.password ==
                                                    ChatRoomProtectoionStatus
                                                        .LOCKED
                                                ? [
                                                    IconSlideAction(
                                                      icon: Icons.lock,
                                                      color: Theme.of(context)
                                                          .errorColor,
                                                      onTap: () => showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            TextEditingController
                                                                passwordController =
                                                                TextEditingController();
                                                            return AlertDialog(
                                                              title: Text(
                                                                  "Unlock chat"),
                                                              content:
                                                                  TextField(
                                                                controller:
                                                                    passwordController,
                                                                decoration:
                                                                    InputDecoration(
                                                                        hintText:
                                                                            "Password"),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop(),
                                                                  child: Text(
                                                                      "Cancel"),
                                                                ),
                                                                ElevatedButton(
                                                                    onPressed:
                                                                        () {
                                                                      Client.send(Message(
                                                                          Core(Actions
                                                                              .UNLOCK_CHAT_ROOM),
                                                                          query:
                                                                              Query(chat: Chat(key: chat.key, password: passwordController.text))));
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                    },
                                                                    child: Text(
                                                                        "Connect"))
                                                              ],
                                                            );
                                                          }),
                                                    )
                                                  ]
                                                : [],
                                            secondaryActions: (Client
                                                            .activeChatRooms
                                                            .length >
                                                        0 &&
                                                    Client.activeChatRooms
                                                            .indexWhere(
                                                                (chatRoom) =>
                                                                    chatRoom
                                                                        .chat
                                                                        .key ==
                                                                    chat.key) >=
                                                        0)
                                                ? [
                                                    IconSlideAction(
                                                      onTap: () {
                                                        Client.send(Message(
                                                            Core(Actions
                                                                .LEAVE_CHAT_ROOM),
                                                            query: Query(
                                                                chat: Chat(
                                                                    key: chat
                                                                        .key))));
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      icon: Icons.link_off,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                    )
                                                  ]
                                                : [],
                                            actionPane:
                                                SlidableBehindActionPane(),
                                            child: Container(
                                              color:
                                                  Theme.of(context).cardColor,
                                              child: IntrinsicHeight(
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Container(
                                                        width: 4,
                                                        color: chat.password ==
                                                                ChatRoomProtectoionStatus
                                                                    .UNLOCKED
                                                            ? Colors.transparent
                                                            : Theme.of(context)
                                                                .errorColor),
                                                    Expanded(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                vertical: 8,
                                                                horizontal: 6),
                                                        child: InkWell(
                                                          onTap: () {
                                                            if (Client.activeChatRooms
                                                                        .length ==
                                                                    0 ||
                                                                Client.activeChatRooms.indexWhere((chatRoom) =>
                                                                        chatRoom
                                                                            .chat
                                                                            .key ==
                                                                        chat.key) <
                                                                    0) {
                                                              if (chat.password ==
                                                                  ChatRoomProtectoionStatus
                                                                      .LOCKED) {
                                                                Navigator.of(
                                                                        context)
                                                                    .pop();
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                        SnackBar(
                                                                  content: Text(
                                                                      "You do not have access to this chat room!"),
                                                                ));
                                                              } else {
                                                                Client.send(Message(
                                                                    Core(Actions
                                                                        .JOIN_CHAT_ROOM),
                                                                    query: Query(
                                                                        chat: Chat(
                                                                            key:
                                                                                chat.key))));
                                                                Navigator.of(
                                                                        context)
                                                                    .pop();
                                                              }
                                                            }
                                                          },
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Padding(
                                                                padding: const EdgeInsets
                                                                        .symmetric(
                                                                    vertical: 2,
                                                                    horizontal:
                                                                        0),
                                                                child: Text(
                                                                  chat.name ??
                                                                      "",
                                                                ),
                                                              ),
                                                              Text(
                                                                (chat.description ??
                                                                        "") +
                                                                    "\n",
                                                                maxLines: 2,
                                                                style: TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .caption
                                                                        .color),
                                                              )
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                        width: 4,
                                                        color: (Client.activeChatRooms
                                                                        .length ==
                                                                    0 ||
                                                                Client.activeChatRooms.indexWhere((chatRoom) =>
                                                                        chatRoom
                                                                            .chat
                                                                            .key ==
                                                                        chat
                                                                            .key) <
                                                                    0)
                                                            ? Colors.transparent
                                                            : Theme.of(context)
                                                                .accentColor),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                ],
                              ),
                              Column(
                                children: [
                                  Collapsible(
                                    collapsed: !_accountsDropdownOpen,
                                    axis: CollapsibleAxis.vertical,
                                    maintainState: true,
                                    child: ElevatedButton(
                                        onPressed: null,
                                        child: Text("Setup an Account")),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Transform.rotate(
                                        angle: -1,
                                        child: Text("WORK IN PROGRESS",
                                            style: TextStyle(
                                                fontSize: 30,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .caption
                                                    .color)),
                                      ),
                                    ),
                                  )
                                ],
                              )
                            ]),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: SizedBox(
                            height: 35,
                            width: 35,
                            child: ClipPath(
                              clipper: ShapeBorderClipper(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(50)))),
                              child: Container(
                                color: Theme.of(context).accentColor,
                                child: IconButton(
                                  onPressed: () => setState(() =>
                                      _isNewChatPanelOpen =
                                          !_isNewChatPanelOpen),
                                  icon: Icon(Icons.add,
                                      color: Theme.of(context)
                                          .buttonTheme
                                          .colorScheme
                                          .onBackground),
                                  alignment: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                        )
                      ]),
                    ),
                    Collapsible(
                        child: Container(
                          decoration: BoxDecoration(boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(75),
                            ),
                            BoxShadow(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                spreadRadius: -1,
                                blurRadius: 2)
                          ]),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                              bottom: Radius.zero),
                                        ),
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (context) {
                                          TextEditingController
                                              chatNameController =
                                                  TextEditingController(),
                                              chatDescriptionController =
                                                  TextEditingController(),
                                              chatPasswordController =
                                                  TextEditingController();
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: new EdgeInsets.only(
                                                    top: 10),
                                                child: Text(
                                                  "New chat",
                                                  style:
                                                      TextStyle(fontSize: 22),
                                                ),
                                              ),
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: Column(
                                                    children: [
                                                      TextField(
                                                        controller:
                                                            chatNameController,
                                                        decoration: InputDecoration(
                                                            hintText:
                                                                "Chat name",
                                                            filled: true,
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .all(8),
                                                            isDense: true),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                horizontal: 0,
                                                                vertical: 10),
                                                        child: TextField(
                                                          minLines: 3,
                                                          maxLines: 3,
                                                          controller:
                                                              chatDescriptionController,
                                                          decoration: InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              hintText:
                                                                  "Chat description",
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              isDense: true),
                                                        ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            chatPasswordController,
                                                        decoration: InputDecoration(
                                                            hintText:
                                                                "Chat password",
                                                            filled: true,
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .all(8),
                                                            isDense: true),
                                                      ),
                                                    ],
                                                  )),
                                              ElevatedButton(
                                                  onPressed: () {
                                                    Client.send(Message(
                                                        Core(Actions
                                                            .CREATE_CHAT_ROOM),
                                                        query: Query(
                                                            chat: Chat(
                                                                name:
                                                                    chatNameController
                                                                        .text,
                                                                description:
                                                                    chatDescriptionController
                                                                        .text,
                                                                password:
                                                                    chatPasswordController
                                                                        .text))));
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text("Create"))
                                            ],
                                          );
                                        });
                                    setState(() => _isNewChatPanelOpen =
                                        !_isNewChatPanelOpen);
                                  },
                                  label: Text("New chat"),
                                  icon: Icon(Icons.people),
                                )
                              ],
                            ),
                          ),
                        ),
                        collapsed: !_isNewChatPanelOpen,
                        maintainState: true,
                        axis: CollapsibleAxis.vertical),
                    Padding(
                      padding: EdgeInsets.all(5),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                EasyDynamicTheme.of(context).changeTheme();
                              },
                              icon: Icon(EasyDynamicTheme.of(context)
                                          .themeMode ==
                                      ThemeMode.dark
                                  ? Icons.brightness_5
                                  : EasyDynamicTheme.of(context).themeMode ==
                                          ThemeMode.light
                                      ? Icons.brightness_2
                                      : Icons.brightness_auto),
                              label: Text(EasyDynamicTheme.of(context)
                                          .themeMode ==
                                      ThemeMode.dark
                                  ? "Dark mode"
                                  : EasyDynamicTheme.of(context).themeMode ==
                                          ThemeMode.light
                                      ? "Light mode"
                                      : "Auto"),
                              style: TextButton.styleFrom(
                                primary:
                                    Theme.of(context).textTheme.button.color,
                              ),
                            ),
                          ),
                          _SettingsButton()
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/*class _IntroText extends StatefulWidget {
  static final Random _random = Random();

  final List<String> texts = [];

  _IntroText(List<String> texts, {Key key}) : super(key: key) {
    texts.forEach((text) {
      this.texts.add(text);
      this.texts.add(text);
    });
  }
  static randomDuration() {
    return _random.nextInt(1000) + 2000;
  }

  @override
  __IntroTextState createState() => __IntroTextState();
}

class __IntroTextState extends State<_IntroText> {
  static int index = 0;
  int _duration;
  //Map<int,  > _indeces;
  bool state = false;

  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(seconds: 3), (timer) {
      setState(() {
        state = !state;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _duration = _IntroText.randomDuration();
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Column(
        children: List.generate(widget.texts.length, (index) {
          return Text(widget.texts[index],
              style: TextStyle(
                  height: 1.3,
                  fontSize: 28,
                  color: index % 2 == 0
                      ? Theme.of(context).hintColor
                      : Theme.of(context).accentColor));
        }),
      ),
    );
  }
}*/

class _SettingsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          if (_drawerSettingsController?.activeState == null)
            Slidable.of(context).open(actionType: SlideActionType.secondary);
          else
            Slidable.of(context).close();
        },
        child: Text("Settings", style: TextStyle(fontSize: 22)),
        style: TextButton.styleFrom(
          primary: Theme.of(context).textTheme.button.color,
        ),
      ),
    );
  }
}

class _ChatRoomWidget extends StatefulWidget {
  final Chat chat;

  const _ChatRoomWidget(this.chat, {Key key}) : super(key: key);

  @override
  _ChatRoomState createState() => _ChatRoomState();
}

class _ChatRoomState extends State<_ChatRoomWidget> {
  List<ChatFile> uploadingFiles = [], attachedFiles = [];
  String enlargedFile, enlargedMessage;
  Chat openAccessibleChat;
  int openState = 0;
  TextEditingController chatMessageTextController = TextEditingController();
  double swipeProgress = 0;
  Offset swipeStart = Offset.zero, panelSwipeStart = Offset.zero;
  AxisDirection swipeDirection;
  Timer releaseTimer;
  Function textListener;
  FocusNode inputFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Collapsible(
              axis: CollapsibleAxis.vertical,
              collapsed: openState != 1,
              child: Column(children: [
                Stack(children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        icon: Icon(Icons.expand_less),
                        onPressed: () => setState(() => openState = 0)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        child: Text(
                          "Upload",
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyText1.color),
                        ),
                        onPressed: () {
                          if (openState == 1)
                            FilePicker.platform
                                .pickFiles(
                                    allowMultiple: true,
                                    withData: false,
                                    withReadStream: false)
                                .then((result) => setState(() {
                                      if (result != null) {
                                        uploadingFiles.addAll(result.files.map(
                                            (file) => ChatFile(
                                                name: file.path,
                                                extension: file.extension)));
                                        result.files.forEach((file) {
                                          Client.filesToUpload[file.path] =
                                              Pair(file.name, file.extension);
                                          Client.send(Message(
                                              Core(Actions.START_FILE_UPLOAD),
                                              query: Query(
                                                  chat: Chat(
                                                      key: widget.chat.key),
                                                  file: uploadingFiles
                                                      .firstWhere((chatFile) =>
                                                          file.path ==
                                                          chatFile.name))));
                                        });
                                      }
                                    }));
                        }),
                  ),
                ]),
                Container(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                      minHeight: 0),
                  child: StaggeredGridView.countBuilder(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      itemCount: widget.chat.files.length,
                      staggeredTileBuilder: (int index) =>
                          new StaggeredTile.fit(1),
                      itemBuilder: (BuildContext context, int index) {
                        ChatFile file = widget.chat.files[index];
                        if (imageExtensions.contains(file.extension) &&
                            file.bytes == null) {
                          Client.send(Message(Core(Actions.GET_FILE),
                              query: Query(
                                  file: ChatFile(
                                      key: file.key,
                                      chatKey: widget.chat.key,
                                      destination:
                                          ChatFileDestination.CHAT_STORAGE))));
                        }
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Stack(clipBehavior: Clip.none, children: [
                            if (imageExtensions.contains(file.extension) &&
                                file.bytes != null)
                              Image.memory(file.bytes),
                            Container(
                                height: 40,
                                child: Center(
                                  child: RichText(
                                      text: TextSpan(
                                          text: file.name ?? "[error]",
                                          children: [
                                        TextSpan(
                                            text: " " + (file.extension ?? ""),
                                            style:
                                                TextStyle(color: Colors.grey))
                                      ])),
                                )),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    if (PreferenceManager.getPreference(
                                            Preferences.downloadsDir) ==
                                        null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            "Please choose where to download files (Settings -> Files Folder)"),
                                      ));
                                    } else {
                                      print("permission:" +
                                          (await Permission.storage.isGranted)
                                              .toString());
                                      if ((await Permission.storage.request())
                                          .isGranted) {
                                        Client.send(Message(
                                            Core(Actions.GET_FILE),
                                            query: Query(
                                                file: ChatFile(
                                                    key: file.key,
                                                    chatKey: widget.chat.key,
                                                    destination:
                                                        ChatFileDestination
                                                            .DOWNLOAD))));
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ]),
                        );
                      }),
                ),
              ]),
            ),
            Expanded(
              child: Stack(clipBehavior: Clip.none, children: [
                AnimatedContainer(
                  clipBehavior: Clip.antiAlias,
                  duration: Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 4, color: Colors.black.withAlpha(125))
                      ],
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(
                              openState == -1 || openState == 2 ? 25 : 0),
                          top: Radius.circular(openState == 1 ? 25 : 0))),
                  child: ScrollablePositionedList.builder(
                    initialScrollIndex: widget.chat.messages.length - 1,
                    padding: const EdgeInsets.only(
                        right: 8, left: 8, top: 8, bottom: 50),
                    itemCount: widget.chat.messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      ChatMessage message = widget.chat.messages[index];
                      Widget child;
                      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                          message.timestamp * 1000);
                      switch (message.type) {
                        case ChatMessageTypes.BASIC:
                          child = Align(
                            alignment: message.creator == Client.key
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75),
                                  child: Stack(children: [
                                    IntrinsicWidth(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Text("${message.creator}"),
                                          ),
                                          Container(
                                            height: 1,
                                            color:
                                                Theme.of(context).accentColor,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Text(
                                              "${message.text}",
                                              textAlign: TextAlign.start,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(onTap: () {
                                          message.files?.forEach((file) {
                                            Client.enlargedMessageFiles.firstWhere(
                                                (chatFile) =>
                                                    file.key == chatFile.key &&
                                                    file.chatKey ==
                                                        chatFile.chatKey,
                                                orElse: () => Client.send(Message(
                                                    Core(Actions.GET_FILE_META),
                                                    query: Query(
                                                        file: ChatFile(
                                                            key: file.key,
                                                            chatKey:
                                                                file.chatKey,
                                                            destination:
                                                                ChatFileDestination
                                                                    .ENLARGED_MESSAGE)))));
                                          });
                                          ScreenshotController
                                              screenshotController =
                                              ScreenshotController();
                                          bool flash = false;
                                          showModalBottomSheet(
                                              backgroundColor:
                                                  Colors.transparent,
                                              context: context,
                                              builder:
                                                  (builder) =>
                                                      StatefulBuilder(builder:
                                                          (context, setState) {
                                                        Client.enlargedMessageStateSetter =
                                                            setState;
                                                        return Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Padding(
                                                                padding: const EdgeInsets
                                                                        .symmetric(
                                                                    horizontal:
                                                                        30,
                                                                    vertical:
                                                                        5),
                                                                child: Row(
                                                                  children: [
                                                                    Card(
                                                                      clipBehavior:
                                                                          Clip.antiAlias,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .scaffoldBackgroundColor,
                                                                      child: IconButton(
                                                                          icon: Icon(
                                                                            Icons.fullscreen,
                                                                            size:
                                                                                28,
                                                                          ),
                                                                          onPressed: () {
                                                                            String
                                                                                directory =
                                                                                PreferenceManager.getPreference(Preferences.screenshotsDir);
                                                                            if (directory ==
                                                                                null) {
                                                                              Navigator.of(context).pop();
                                                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                                content: Text("Please choose where to save screenshots (Settings -> Screenshots Folder)"),
                                                                              ));
                                                                            } else {
                                                                              screenshotController.captureAndSave(directory);
                                                                              Timer(
                                                                                  Duration(milliseconds: 100),
                                                                                  () => setState(() {
                                                                                        flash = true;
                                                                                        Timer(
                                                                                            Duration(milliseconds: 100),
                                                                                            () => setState(() {
                                                                                                  flash = false;
                                                                                                }));
                                                                                      }));
                                                                            }
                                                                          }),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                              Screenshot(
                                                                controller:
                                                                    screenshotController,
                                                                child:
                                                                    Container(
                                                                  clipBehavior:
                                                                      Clip.antiAlias,
                                                                  margin: const EdgeInsets
                                                                          .symmetric(
                                                                      horizontal:
                                                                          20,
                                                                      vertical:
                                                                          5),
                                                                  decoration: BoxDecoration(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .scaffoldBackgroundColor,
                                                                      borderRadius:
                                                                          BorderRadius.all(
                                                                              Radius.circular(15))),
                                                                  child: Stack(
                                                                      children: [
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.stretch,
                                                                          children: [
                                                                            Padding(
                                                                              padding: EdgeInsets.all(8),
                                                                              child: Row(children: [
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    "${message.creator}",
                                                                                    style: TextStyle(fontSize: 24),
                                                                                  ),
                                                                                ),
                                                                                Text("${dateTime.hour}:${dateTime.minute}", style: TextStyle(color: Colors.grey, fontSize: 22))
                                                                              ]),
                                                                            ),
                                                                            Container(
                                                                              height: 2,
                                                                              color: Theme.of(context).accentColor,
                                                                            ),
                                                                            Padding(
                                                                              padding: EdgeInsets.all(8),
                                                                              child: Text(
                                                                                "${message.text}",
                                                                                style: TextStyle(fontSize: 22),
                                                                                textAlign: TextAlign.start,
                                                                              ),
                                                                            ),
                                                                            Container(
                                                                              child: Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                                children: [
                                                                                  Container(
                                                                                    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [
                                                                                      BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Colors.black.withAlpha(125))
                                                                                    ]),
                                                                                    child: Padding(
                                                                                      padding: const EdgeInsets.all(4),
                                                                                      child: Text(
                                                                                        "Attachments",
                                                                                        style: TextStyle(color: Theme.of(context).textTheme.caption.color),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  StaggeredGridView.countBuilder(
                                                                                      shrinkWrap: true,
                                                                                      crossAxisCount: 2,
                                                                                      crossAxisSpacing: 2,
                                                                                      mainAxisSpacing: 2,
                                                                                      padding: const EdgeInsets.all(4),
                                                                                      itemCount: Client.enlargedMessageFiles?.length ?? 0,
                                                                                      staggeredTileBuilder: (int index) => new StaggeredTile.fit(1),
                                                                                      itemBuilder: (BuildContext context, int index) {
                                                                                        ChatFile file = Client.enlargedMessageFiles[index];
                                                                                        if (imageExtensions.contains(file.extension) && file.bytes == null && !file.isDownloading) {
                                                                                          Client.send(Message(Core(Actions.GET_FILE), query: Query(file: ChatFile(key: file.key, chatKey: file.chatKey, destination: ChatFileDestination.ENLARGED_MESSAGE))));
                                                                                          file.isDownloading = true;
                                                                                        }
                                                                                        return Card(
                                                                                          clipBehavior: Clip.antiAlias,
                                                                                          child: Stack(clipBehavior: Clip.none, children: [
                                                                                            if (imageExtensions.contains(file.extension) && file.bytes != null) Image.memory(file.bytes),
                                                                                            Container(
                                                                                                height: 40,
                                                                                                child: Center(
                                                                                                  child: RichText(
                                                                                                      text: TextSpan(text: file.name ?? "[error]", children: [
                                                                                                    TextSpan(text: " " + (file.extension ?? ""), style: TextStyle(color: Colors.grey))
                                                                                                  ])),
                                                                                                )),
                                                                                            Positioned.fill(
                                                                                              child: Material(
                                                                                                color: Colors.transparent,
                                                                                                child: InkWell(
                                                                                                  onTap: () async {
                                                                                                    if (PreferenceManager.getPreference(Preferences.downloadsDir) == null) {
                                                                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                                                        content: Text("Please choose where to download files (Settings -> Downloads Folder)"),
                                                                                                      ));
                                                                                                    } else {
                                                                                                      print("permission:" + (await Permission.storage.isGranted).toString());
                                                                                                      if ((await Permission.storage.request()).isGranted) {
                                                                                                        Client.send(Message(Core(Actions.GET_FILE), query: Query(file: ChatFile(key: file.key, chatKey: file.chatKey, destination: ChatFileDestination.DOWNLOAD))));
                                                                                                      }
                                                                                                    }
                                                                                                  },
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ]),
                                                                                        );
                                                                                      }),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        Positioned.fill(
                                                                            child: AnimatedContainer(
                                                                          duration:
                                                                              Duration(milliseconds: 100),
                                                                          color: Colors.white.withOpacity(flash
                                                                              ? 1
                                                                              : 0),
                                                                        ))
                                                                      ]),
                                                                ),
                                                              ),
                                                            ]);
                                                      })).then((value) {
                                            Client.enlargedMessageStateSetter =
                                                null;
                                            Client.enlargedMessageFiles.clear();
                                          });
                                        }),
                                      ),
                                    )
                                  ]),
                                )),
                          );
                          break;
                        case ChatMessageTypes.META:
                          child = Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                "${message.text}",
                                style: TextStyle(
                                    color: Theme.of(context).accentColor),
                              ),
                            ),
                          );
                          break;
                      }
                      return Stack(
                        children: [
                          child,
                          Positioned.fill(
                              child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text("${dateTime.hour}:${dateTime.minute}",
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ))
                        ],
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    /*behavior: HitTestBehavior.opaque,
                    gestures: <Type, GestureRecognizerFactory>{
                      CustomPanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                                  CustomPanGestureRecognizer>(
                              () => CustomPanGestureRecognizer(
                                      onPanDown: (dragStartDetails) {
                                    setState(() {
                                      swipeProgress = 0;
                                      swipeStart = Offset(
                                          MediaQuery.of(context).size.width / 2,
                                          25);
                                      releaseTimer?.cancel();
                                    });
                                  }, onPanEnd: (dragEndDetails) {
                                    setState(() {
                                      swipeStart = Offset.zero;
                                    });
                                    releaseTimer = Timer.periodic(
                                        Duration(milliseconds: 10), (timer) {
                                      setState(() {
                                        if ((swipeProgress -= 0.1) <= 0) {
                                          swipeProgress = 0;
                                          timer.cancel();
                                          print("send button timer stopped");
                                        }
                                      });
                                    });
                                  }, onPanUpdate: (dragUpdateDetails) {
                                    double distance = ((swipeStart -
                                                dragUpdateDetails.localPosition)
                                            .distance)
                                        .clamp(0, 35)
                                        .toDouble();
                                    setState(() {
                                      swipeProgress = distance / 35;
                                      var direction =
                                          (dragUpdateDetails.localPosition -
                                                  swipeStart)
                                              .direction;
                                      var newDirecion;
                                      if (direction > 0) {
                                        if (direction <= pi / 4) {
                                          newDirecion = AxisDirection.right;
                                        } else {
                                          if (direction <= pi * 3 / 4) {
                                            newDirecion = AxisDirection.down;
                                          } else {
                                            newDirecion = AxisDirection.left;
                                          }
                                        }
                                      } else {
                                        if (direction >= pi / -4) {
                                          newDirecion = AxisDirection.right;
                                        } else {
                                          if (direction >= pi * 3 / -4) {
                                            newDirecion = AxisDirection.up;
                                          } else {
                                            newDirecion = AxisDirection.left;
                                          }
                                        }
                                      }
                                      if (swipeDirection != newDirecion) {
                                        print(newDirecion);
                                      }
                                      swipeDirection = newDirecion;
                                    });
                                  }),
                              (panGestureRecognizer) {})
                    },*/
                    onPanUpdate: (details) {
                      double distance =
                          ((swipeStart - details.localPosition).distance)
                              .clamp(0, 35)
                              .toDouble();
                      setState(() {
                        swipeProgress = distance / 35;
                        var direction =
                            (details.localPosition - swipeStart).direction;
                        var newDirecion;
                        if (direction > 0) {
                          if (direction <= pi / 4) {
                            newDirecion = AxisDirection.right;
                          } else {
                            if (direction <= pi * 3 / 4) {
                              newDirecion = AxisDirection.down;
                            } else {
                              newDirecion = AxisDirection.left;
                            }
                          }
                        } else {
                          if (direction >= pi / -4) {
                            newDirecion = AxisDirection.right;
                          } else {
                            if (direction >= pi * 3 / -4) {
                              newDirecion = AxisDirection.up;
                            } else {
                              newDirecion = AxisDirection.left;
                            }
                          }
                        }
                        if (swipeDirection != newDirecion) {
                          print(newDirecion);
                        }
                        swipeDirection = newDirecion;
                      });
                    },
                    onPanStart: (details) {
                      setState(() {
                        swipeProgress = 0;
                        swipeStart =
                            Offset(MediaQuery.of(context).size.width / 2, 25);
                        releaseTimer?.cancel();
                      });
                    },
                    onPanEnd: (details) async {
                      setState(() {
                        swipeStart = Offset.zero;
                      });
                      releaseTimer =
                          Timer.periodic(Duration(milliseconds: 10), (timer) {
                        setState(() {
                          if ((swipeProgress -= 0.1) <= 0) {
                            swipeProgress = 0;
                            timer.cancel();
                          }
                        });
                      });
                      if (swipeProgress == 1) {
                        switch (swipeDirection) {
                          case AxisDirection.up:
                            if (chatMessageTextController.text.isNotEmpty) {
                              Client.send(Message(
                                  Core(Actions.ADD_CHAT_MESSAGE),
                                  query: Query(
                                      chat: Chat(
                                          key: Client
                                              .activeChatRooms[
                                                  _chatTabsController.index]
                                              .chat
                                              .key),
                                      chatMesage: ChatMessage(
                                          text: chatMessageTextController.text,
                                          files: attachedFiles))));
                              chatMessageTextController.clear();
                              attachedFiles.clear();
                              setState(() => openState = -1);
                            }
                            break;
                          case AxisDirection.right:
                            setState(() {
                              inputFocusNode.unfocus();
                              Client.send(Message(
                                  Core(Actions.LIST_ACCESSIBLE_CHAT_ROOMS)));
                              openState = (openState == 2 ? -1 : 2);
                              openAccessibleChat = null;
                            });
                            break;
                          case AxisDirection.down:
                            break;
                          case AxisDirection.left:
                            break;
                        }
                      }
                    },
                    child: Container(
                      height: 50,
                      color: Colors.black.withOpacity(0),
                      child: Stack(clipBehavior: Clip.none, children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                              height: (swipeProgress == 0 ? 4 : 24).toDouble() +
                                  (swipeProgress == 1 &&
                                          swipeDirection != AxisDirection.down
                                      ? 24
                                      : 0),
                              width: (swipeProgress == 0
                                          ? MediaQuery.of(context).size.width *
                                              0.4
                                          : 36)
                                      .toDouble() +
                                  (swipeProgress == 1 &&
                                          swipeDirection != AxisDirection.down
                                      ? 8
                                      : 0),
                              decoration: BoxDecoration(
                                color: swipeProgress == 0
                                    ? Colors.grey
                                    : swipeProgress == 1 &&
                                            swipeDirection != AxisDirection.down
                                        ? Colors.purple
                                        : Theme.of(context).accentColor,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(50),
                                ),
                              ),
                              curve: Curves.bounceOut,
                              duration: Duration(milliseconds: 300)),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 50,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _SwipeButton(
                                  swipeProgress,
                                  AxisDirection.up,
                                  swipeDirection,
                                  Transform.rotate(
                                      angle: (-pi / 2) * swipeProgress,
                                      child: Icon(Icons.send)),
                                ),
                                _SwipeButton(
                                  swipeProgress,
                                  AxisDirection.left,
                                  swipeDirection,
                                  Icon(Icons.block),
                                ),
                                _SwipeButton(
                                  swipeProgress,
                                  AxisDirection.right,
                                  swipeDirection,
                                  Transform.rotate(
                                      angle: (pi / 2) * swipeProgress,
                                      child: Icon(Icons.attachment)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            Collapsible(
              collapsed: openState >= 0 && openState < 2,
              axis: CollapsibleAxis.vertical,
              clipBehavior: Clip.hardEdge,
              child: Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: GestureDetector(
                          onVerticalDragEnd: (details) => setState(() {
                            openState = details.primaryVelocity > 0 ? 0 : -1;
                            openAccessibleChat = null;
                          }),
                          child: Card(
                              child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: TextField(
                              controller: chatMessageTextController,
                              focusNode: inputFocusNode,
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.all(10),
                                  isDense: true),
                            ),
                          )),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.3,
                            minHeight: 0),
                        child: StaggeredGridView.countBuilder(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            itemCount:
                                MediaQuery.of(context).viewInsets.bottom > 100
                                    ? 0
                                    : attachedFiles.length,
                            staggeredTileBuilder: (int index) =>
                                new StaggeredTile.fit(1),
                            itemBuilder: (BuildContext context, int index) {
                              ChatFile file = widget.chat.files.singleWhere(
                                  (chatFile) =>
                                      chatFile.key == attachedFiles[index].key);
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child:
                                    Stack(clipBehavior: Clip.none, children: [
                                  Container(
                                      height: 50,
                                      child: Center(
                                          child: Text(file.name ?? "[error]"))),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => setState(() =>
                                            attachedFiles.remove(file.key)),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                      ),
                      Collapsible(
                        axis: CollapsibleAxis.vertical,
                        collapsed: openState != 2 ||
                            MediaQuery.of(context).viewInsets.bottom > 100,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Stack(alignment: Alignment.center, children: [
                            Positioned(
                                top: 0, left: 0, child: Text("Attached files")),
                            Positioned(
                                bottom: 0,
                                right: 0,
                                child: Text("Available files")),
                            Container(
                              alignment: Alignment.center,
                              height: 2,
                              color: Theme.of(context).accentColor,
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  border: Border.all(
                                      color: Theme.of(context).accentColor,
                                      width: 2),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 4,
                                        color: Colors.black.withAlpha(125))
                                  ]),
                              child: Icon(Icons.swap_vert,
                                  color: Theme.of(context)
                                      .textTheme
                                      .headline6
                                      .color),
                            ),
                          ]),
                        ),
                      ),
                      Collapsible(
                        collapsed: openState != 2 ||
                            openAccessibleChat != null ||
                            MediaQuery.of(context).viewInsets.bottom > 100,
                        axis: CollapsibleAxis.vertical,
                        duration: Duration(milliseconds: 500),
                        maintainState: true,
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.3,
                              minHeight: 0),
                          child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              childAspectRatio: 3,
                              children: List.generate(
                                  Client.accessibleChatList.length,
                                  (index) => Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Center(
                                                  child: Text(
                                                Client.accessibleChatList[index]
                                                        .name ??
                                                    "[error]",
                                                style: TextStyle(fontSize: 22),
                                              )),
                                              Container(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => setState(() {
                                                    openAccessibleChat = Client
                                                            .accessibleChatList[
                                                        index];
                                                    Client.send(Message(
                                                        Core(Actions
                                                            .GET_CHAT_FILES),
                                                        query: Query(
                                                            chat: Chat(
                                                                key: openAccessibleChat
                                                                    .key))));
                                                  }),
                                                ),
                                              ),
                                            ]),
                                      ))),
                        ),
                      ),
                      /*Container(
                        child: Collapsible(
                            maintainState: true,
                            duration: Duration(milliseconds: 100),
                            collapsed: enlargedFile == null ||
                                MediaQuery.of(context).viewInsets.bottom > 100,
                            axis: CollapsibleAxis.vertical,
                            child: enlargedFile != null
                                ? Stack(children: [
                                    Container(
                                      foregroundDecoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment(0, -0.25),
                                              colors: [
                                            Colors.black.withOpacity(0.75),
                                            Colors.black.withOpacity(0)
                                          ])),
                                      child: imageExtensions
                                              .any(enlargedFile.endsWith)
                                          ? Image.file(
                                              File.fromUri(
                                                  Uri.file(enlargedFile)),
                                              fit: BoxFit.fitWidth,
                                            )
                                          : Container(
                                              height: 150,
                                              child: Center(
                                                child: Text(
                                                    "Unable to generate preview"),
                                              ),
                                            ),
                                    ),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Material(
                                        color: Colors.transparent,
                                        clipBehavior: Clip.none,
                                        child: IconButton(
                                            icon: Icon(Icons.expand_more,
                                                color: Colors.white),
                                            onPressed: () => setState(
                                                () => enlargedFile = null)),
                                      ),
                                    ),
                                    Align(
                                        alignment: Alignment.topLeft,
                                        child: InkWell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              "Remove",
                                              style: TextStyle(
                                                  fontSize: 24,
                                                  color: Colors.white),
                                            ),
                                          ),
                                          onTap: () => setState(() {
                                            attachedFiles.remove(enlargedFile);
                                            enlargedFile = null;
                                          }),
                                        )),
                                  ])
                                : null),*/
                      Collapsible(
                          collapsed:
                              openState != 2 || openAccessibleChat == null,
                          axis: CollapsibleAxis.vertical,
                          duration: Duration(milliseconds: 500),
                          maintainState: true,
                          child: Container(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.3,
                                minHeight: 0),
                            child: Column(children: [
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 4,
                                        color: Colors.black.withAlpha(125))
                                  ],
                                ),
                                child: Row(children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Text(
                                        openAccessibleChat?.name ?? "[error]",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.expand_more),
                                    onPressed: () => setState(
                                        () => openAccessibleChat = null),
                                  ),
                                ]),
                              ),
                              Expanded(
                                child: StaggeredGridView.countBuilder(
                                    shrinkWrap: true,
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                    itemCount:
                                        openAccessibleChat?.files?.length ?? 0,
                                    staggeredTileBuilder: (int index) =>
                                        new StaggeredTile.fit(1),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      ChatFile file = openAccessibleChat?.files
                                          ?.elementAt(index);
                                      return Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                  height: 50,
                                                  child: Center(
                                                      child: Text(file?.name ??
                                                          "[error]"))),
                                              Positioned.fill(
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                      onTap: () => setState(
                                                            () {
                                                              file.chatKey =
                                                                  openAccessibleChat
                                                                      .key;
                                                              attachedFiles.add(
                                                                  ChatFile(
                                                                      key: file
                                                                          .key,
                                                                      chatKey: file
                                                                          .chatKey));
                                                            },
                                                          )),
                                                ),
                                              ),
                                            ]),
                                      );
                                    }),
                              ),
                            ]),
                          ))
                    ]),
              ),
            )
          ],
        ),
        if (openState > -1 && openState < 2)
          Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                  onVerticalDragEnd: (details) => setState(() {
                        _isGridOpen = false;
                        if (openState == 1 && details.primaryVelocity < 0) {
                          openState = 0;
                        } else {
                          openState =
                              details.primaryVelocity.round().clamp(-1, 1);
                        }
                        inputFocusNode.requestFocus();
                      }),
                  child: Container(
                    color: Colors.black.withOpacity(0),
                    height: 50,
                  ))),
      ],
    );
  }
}

class _SwipeButton extends StatelessWidget {
  double swipeProgress;
  AxisDirection preferredAxis, swipeDirection;

  Widget child;

  _SwipeButton(
      this.swipeProgress, this.preferredAxis, this.swipeDirection, this.child,
      {Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var distance = swipeProgress.clamp(0, 0.75) * 25 +
        (swipeDirection == preferredAxis && swipeProgress == 1 ? 30 : 0) +
        30;
    return AnimatedPositioned(
      bottom: preferredAxis == AxisDirection.up ? distance : null,
      left: preferredAxis == AxisDirection.right ? distance : null,
      top: preferredAxis == AxisDirection.down ? distance : null,
      right: preferredAxis == AxisDirection.left ? distance : null,
      duration: Duration(milliseconds: 100),
      child: Transform.scale(
        scale: swipeProgress,
        child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
                color: swipeProgress == 1 && swipeDirection == preferredAxis
                    ? Theme.of(context).accentColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
            child: IconTheme(
                data: IconThemeData(
                    color: swipeProgress == 1 && swipeDirection == preferredAxis
                        ? Theme.of(context).textTheme.bodyText1.color
                        : Theme.of(context).accentColor),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: child,
                ))),
      ),
    );
  }
}

/*class CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function onPanDown;
  final Function onPanUpdate;
  final Function onPanEnd;

  CustomPanGestureRecognizer(
      {@required this.onPanDown,
      @required this.onPanUpdate,
      @required this.onPanEnd});

  @override
  void addPointer(PointerEvent event) {
    if (onPanDown(event.position)) {
      startTrackingPointer(event.pointer);
      resolve(GestureDisposition.accepted);
    } else {
      stopTrackingPointer(event.pointer);
    }
    //startTrackingPointer(event.pointer);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onPanUpdate(event.position);
    }
    if (event is PointerUpEvent) {
      onPanEnd(event.position);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'customPan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}*/
