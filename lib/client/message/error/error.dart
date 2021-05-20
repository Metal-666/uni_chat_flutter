class Error {
  String type, message;

  Error({this.type, this.message});

  Map toJson() =>
      {if (type != null) "type": type, if (message != null) "message": message};

  factory Error.fromJson(dynamic json) {
    return Error(type: json["type"], message: json["message"]);
  }
}

class ErrorTypes {
  static const CLIENT = "CLIENT", SERVER = "SERVER";
}
