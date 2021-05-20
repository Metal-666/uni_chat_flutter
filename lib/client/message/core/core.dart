class Core {
  String action;
  String key;

  Core(this.action, {this.key});

  Map toJson() => {"action": action, "key": key};

  factory Core.fromJson(dynamic json) {
    return Core(json["action"], key: json["key"]);
  }
}
