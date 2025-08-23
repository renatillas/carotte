import carotte
import carotte/channel
import gleam/dynamic
import gleam/erlang/atom
import gleam/list

// In amqp_client, headers are represented as a proplist of
// {Name, Type, Data}.
// Name is a binary representation of the header name.
// Type is one of a number of type atoms, but in our case, we only care about:
// - bool - Bool
// - long - Int
// - float - Float
// - longstr - String
// - array - List

pub opaque type HeaderList {
  HeaderList(List(#(String, atom.Atom, dynamic.Dynamic)))
}

pub type HeaderValue {
  BoolHeader(Bool)
  FloatHeader(Float)
  IntHeader(Int)
  StringHeader(String)
  ListHeader(List(HeaderValue))
}

@external(erlang, "carotte_ffi", "header_value_to_header_tuple")
fn header_value_to_header_tuple(
  value: HeaderValue,
) -> #(atom.Atom, dynamic.Dynamic)

/// Create a HeaderList from a list of name-value pairs.
/// Use this to construct headers for messages.
/// 
/// ## Example
/// ```gleam
/// let headers = headers_from_list([
///   #("user_id", StringHeader("123")),
///   #("retry_count", IntHeader(3)),
///   #("is_test", BoolHeader(True)),
/// ])
/// ```
pub fn headers_from_list(list: List(#(String, HeaderValue))) -> HeaderList {
  list
  |> list.map(fn(item) {
    let #(name, value) = item
    let #(type_atom, value) = header_value_to_header_tuple(value)
    #(name, type_atom, value)
  })
  |> HeaderList
}

pub type PublishOption {
  /// If set, returns an error if the broker can't route the message to a queue
  Mandatory(Bool)
  // Immediate(Bool) not supported
  /// MIME Content type
  ContentType(String)
  /// MIME Content encoding
  ContentEncoding(String)
  /// Headers to attach to the message. Note: headers can currently only be sent,
  /// not received.
  Headers(HeaderList)
  /// If set, uses persistent delivery mode.
  /// Messages marked as persistent that are delivered to durable queues will be logged to disk
  Persistent(Bool)
  /// Arbitrary application-specific message identifier
  CorrelationId(String)
  /// Message priority, ranging from 0 to 9
  Priority(Int)
  /// Name of the reply queue
  ReplyTo(String)
  /// How long the message is valid (in milliseconds)
  Expiration(String)
  /// Message identifier
  MessageId(String)
  /// timestamp associated with this message (epoch time)
  Timestamp(Int)
  /// Message type
  Type(String)
  /// Creating user ID. RabbitMQ will validate this against the active connection user
  UserId(String)
  /// Application ID
  AppId(String)
}

/// Publish a message 'payload' to an exchange
/// The `routing_key` is used to filter messages from the exchange
/// The `options` are used to set message properties
pub fn publish(
  channel channel: channel.Channel,
  exchange exchange: String,
  routing_key routing_key: String,
  payload payload: String,
  options options: List(PublishOption),
) -> Result(Nil, carotte.CarotteError) {
  do_publish(channel, exchange, routing_key, payload, options)
}

@external(erlang, "carotte_ffi", "publish")
fn do_publish(
  channel: channel.Channel,
  exchange: String,
  routing_key: String,
  payload: String,
  publish_options: List(PublishOption),
) -> Result(Nil, carotte.CarotteError)
