class Config {
  // NATS commands
  static const MSG = "MSG ";
  static const PUB = "PUB ";
  static const SUB = "SUB ";
  static const UNSUB = "UNSUB ";
  static const INFO = "INFO ";
  static const PING = "PING";
  static const PONG = "PONG";
  static const CONNECT = "CONNECT ";
  static const OK = "+OK";
  static const ERR = "-ERR";

  // NATS PUB/SUB/UNSUB commonands structure helper
  static const CR_LF = '\r\n';
  static const CR_LF_LEN = CR_LF.length;
  static const EMPTY = '';

  // Reconnect Parameters, 2 sec wait, 10 tries
  static const DEFAULT_RECONNECT_TIME_WAIT = 2 * 1000;
  static const DEFAULT_MAX_RECONNECT_ATTEMPTS = 10;

  // Ping interval
  static const DEFAULT_PING_INTERVAL = 2 * 60 * 1000; // 2 minutes
  static const DEFAULT_MAX_PING_OUT = 2;
}
