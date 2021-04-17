import 'package:nats/nats.dart';

void main() async {
  var client = NatsClient('ws://localhost:9876/nats');

  await client.connect();

  client.log.v("[sub.dart] connected: ${client.serverinfo.toJson()}");

  client.subscribe("sub-1", queueGroup: "foo.*").listen((msg) {
    client.log.v("Got message: ${msg.payload}");
    if (msg.replyTo != null)
      client.publish(msg.replyTo!, "reply for:${msg.subject}");
  });
}
