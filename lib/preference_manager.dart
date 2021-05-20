import "package:shared_preferences/shared_preferences.dart";

class PreferenceManager {
  static SharedPreferences _preferences;

  static Future init() async {
    print("initialising prefmanager");
    _preferences = await SharedPreferences.getInstance();
  }

  static String getPreference(Preferences preference) /* async*/ {
    String prefName = _getPreferenceName(preference);
    String value = _preferences.getString(prefName);
    print("fetched value of $prefName: $value");
    return value;
  }

  static Future setPreference(Preferences preference, String value) async {
    String prefName = _getPreferenceName(preference);
    await _preferences.setString(prefName, value);
    print("set value of $prefName to $value");
  }

  static _getPreferenceName(Preferences preference) {
    String value;
    switch (preference) {
      case Preferences.anonymousName:
        value = "anonymousName";
        break;
      case Preferences.accountType:
        value = "accountType";
        break;
      case Preferences.layoutMode:
        value = "layoutMode";
        break;
      case Preferences.serverAddress:
        value = "serverAddress";
        break;
      case Preferences.autoconnect:
        value = "autoconnect";
        break;
      case Preferences.downloadsDir:
        value = "downloadsDir";
        break;
      case Preferences.screenshotsDir:
        value = "screenshotsDir";
        break;
    }
    return value;
  }
}

enum Preferences {
  anonymousName,
  accountType,
  layoutMode,
  serverAddress,
  autoconnect,
  downloadsDir,
  screenshotsDir
}
