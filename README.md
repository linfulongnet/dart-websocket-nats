
# nats-dart
NATS client to usage in Dart CLI, Web and Flutter projects

### Setting up a client
Setting up a client and firing up a connection
```dart
var client = NatsClient('ws://demo.host:port/path');
await client.connect();
```

### Publishing a message
Publishing a message can be done with or without a `reply-to` topic
```dart
// No reply-to topic set
client.publish("sub-id", "foo");

// If server replies to this request, send it to `bar`
client.publish("sub-id", "foo", replyTo: "bar");
```

### Subscribing to messages
To subscribe to a topic, specify the topic and optionally, a queue group
```dart
var messageStream = client.subscribe("sub-id", "foo");

// If more than one subscriber uses the same queue group,
// only one will receive the message
var messageStream = client.subscribe("sub-id", "foo", queueGroup: "group-1");

messageStream.listen((message) {
    // Do something awesome
});
```
