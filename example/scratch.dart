import 'dart:io';

void main() async {
  InternetAddress.lookup("localhost").then((addresses) {
    print(addresses);
  });
}
