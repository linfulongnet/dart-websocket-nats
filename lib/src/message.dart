import 'dart:convert';

import 'util.dart';

class Message {
  int? sid;
  String? subject;
  String? payload;
  String? replyTo;
  int? length;

  Message({this.sid, this.subject, this.payload, this.replyTo, this.length});

  String toJson() {
    Map<String, dynamic> map = {};
    map["sid"] = sid;
    map["subject"] = subject;
    map["payload"] = payload;
    map["replyTo"] = replyTo;
    map["length"] = length;

    return jsonEncode(removeJsonNull(map));
  }
}
