import carotte
import carotte/channel
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/list
import gleam/result

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

/// Create an empty HeaderList.
/// Useful for pattern matching or when no headers are needed.
pub fn empty_headers() -> HeaderList {
  HeaderList([])
}

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

/// Convert a HeaderList back to a list of name-value pairs.
/// Use this to read headers from received messages.
///
/// ## Example
/// ```gleam
/// case queue.subscribe(channel, "my_queue", fn(payload, _deliver) {
///   let headers = publisher.headers_to_list(payload.headers)
///   // headers: List(#(String, HeaderValue))
/// })
/// ```
pub fn headers_to_list(headers: HeaderList) -> List(#(String, HeaderValue)) {
  let HeaderList(raw_headers) = headers
  raw_headers
  |> list.filter_map(fn(header) {
    let #(name, type_atom, value) = header
    let type_name = atom.to_string(type_atom)
    case type_name {
      "bool" -> {
        case decode.run(value, decode.bool) {
          Ok(bool_val) -> Ok(#(name, BoolHeader(bool_val)))
          Error(_) -> Error(Nil)
        }
      }
      "long" -> {
        case decode.run(value, decode.int) {
          Ok(int_val) -> Ok(#(name, IntHeader(int_val)))
          Error(_) -> Error(Nil)
        }
      }
      "float" -> {
        case decode.run(value, decode.float) {
          Ok(float_val) -> Ok(#(name, FloatHeader(float_val)))
          Error(_) -> Error(Nil)
        }
      }
      "longstr" -> {
        case decode.run(value, decode.string) {
          Ok(str_val) -> Ok(#(name, StringHeader(str_val)))
          Error(_) -> Error(Nil)
        }
      }
      "array" -> {
        case parse_header_array(value) {
          Ok(list_val) -> Ok(#(name, ListHeader(list_val)))
          Error(_) -> Error(Nil)
        }
      }
      _ -> Error(Nil)
    }
  })
}

fn parse_header_array(value: dynamic.Dynamic) -> Result(List(HeaderValue), Nil) {
  // Array elements in AMQP are wrapped as {Type, Value} tuples
  let array_decoder = decode.list(decode.dynamic)

  use items <- result.try(
    decode.run(value, array_decoder)
    |> result.replace_error(Nil),
  )

  items
  |> list.try_map(fn(item) {
    // Each item is a tuple {Type, Value}
    let type_decoder = decode.at([0], decode.dynamic)
    let value_decoder = decode.at([1], decode.dynamic)

    use type_dyn <- result.try(
      decode.run(item, type_decoder)
      |> result.replace_error(Nil),
    )
    use val <- result.try(
      decode.run(item, value_decoder)
      |> result.replace_error(Nil),
    )

    // Try to decode the type atom
    case decode.run(type_dyn, atom.decoder()) {
      Ok(type_atom) -> {
        let type_name = atom.to_string(type_atom)
        case type_name {
          "bool" -> {
            use b <- result.map(
              decode.run(val, decode.bool)
              |> result.replace_error(Nil),
            )
            BoolHeader(b)
          }
          "long" -> {
            use i <- result.map(
              decode.run(val, decode.int)
              |> result.replace_error(Nil),
            )
            IntHeader(i)
          }
          "float" -> {
            use f <- result.map(
              decode.run(val, decode.float)
              |> result.replace_error(Nil),
            )
            FloatHeader(f)
          }
          "longstr" -> {
            use s <- result.map(
              decode.run(val, decode.string)
              |> result.replace_error(Nil),
            )
            StringHeader(s)
          }
          "array" -> {
            use nested <- result.map(parse_header_array(val))
            ListHeader(nested)
          }
          _ -> Error(Nil)
        }
      }
      Error(_) -> Error(Nil)
    }
  })
}

pub type PublishOption {
  /// If set, returns an error if the broker can't route the message to a queue
  Mandatory(Bool)
  // Immediate(Bool) not supported
  /// MIME Content type
  ContentType(String)
  /// MIME Content encoding
  ContentEncoding(String)
  /// Headers to attach to the message. Use `headers_from_list` to create headers
  /// for sending, and `headers_to_list` to read headers from received messages.
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
