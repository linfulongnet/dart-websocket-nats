import "package:test/test.dart";
import "package:nats/nats.dart";

void main() async {
  test("pub-sub works", () async {
    var client1 = NatsClient('ws://t2.bfdx.net:2235/nats');
    await client1.connect();
    client1.log.v("client1 connected: ${client1.serverinfo.toJson()}\n");

    await Future.delayed(Duration(seconds: 1));

    var client2 = NatsClient('ws://t2.bfdx.net:2235/nats');
    await client2.connect();
    client2.log.v("client2 connected: ${client2.serverinfo.toJson()}\n");

    await Future.delayed(Duration(seconds: 1));

    client1.subscribe("sub-1", queueGroup: "foo.*").listen((msg) {
      client1.log.v("client1 Got message: ${msg.payload}");
      if (msg.replyTo != null)
        client1.publish(msg.replyTo!, "reply for:${msg.subject}");
    });

    client2.subscribe("sub-1-reply", queueGroup: "foo.*").listen((msg) {
      client2.log.v("client2 Got sub-1-reply message: ${msg.payload}");
    });

    client2.publish("sub-1", "foo", replyTo: 'sub-1-reply');

    await Future.delayed(Duration(seconds: 5));
  });
}
