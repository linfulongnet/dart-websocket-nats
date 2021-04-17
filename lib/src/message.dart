class Message {
  int? sid;
  String? subject;
  String? payload;
  String? replyTo;
  int? length;

  Message({this.sid, this.subject, this.payload, this.replyTo, this.length});
}
