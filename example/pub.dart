import 'package:nats/nats.dart';

void main() async {
  var client = NatsClient('ws://localhost:9876/nats');

  await client.connect();

  client.log.v("[pub.dart] connected: ${client.serverinfo.toJson()}");

  client.subscribe("sub-1-reply", queueGroup: "foo.*").listen((msg) {
    client.log.v("Got sub-1-reply message: ${msg.payload}");
  });

  client.publish("Hello world", "foo", replyTo: 'sub-1-reply');
}
