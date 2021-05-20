import "package:uni_chat/preference_manager.dart";

class Account {
  static Types type;

  static String email, name;

  static init() {
    switch (PreferenceManager.getPreference(Preferences.accountType) ?? "0") {
      case "0":
        setAccountType(Types.anonymous);
        break;
      case "1":
        setAccountType(Types.paswordless);
        break;
    }
  }

  static setAccountType(Types type) async {
    Account.type = type;
    switch (type) {
      case Types.anonymous:
        email = "";
        name = PreferenceManager.getPreference(Preferences.anonymousName) ??
            "Anonymous";
        break;
      case Types.paswordless:
        break;
    }
  }
}

enum Types { anonymous, paswordless }
