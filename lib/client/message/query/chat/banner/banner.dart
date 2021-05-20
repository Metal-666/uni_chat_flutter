class Banner {
  String background, imageId;
  Banner({this.background, this.imageId});

  Map toJson() => {
        if (background != null) "background": background,
        if (imageId != null) "imageId": imageId,
      };

  factory Banner.fromJson(dynamic json) {
    return Banner(background: json["background"], imageId: json["imageId"]);
  }
}
