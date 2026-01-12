# Carotte 🥕

[![Package Version](https://img.shields.io/hexpm/v/carotte)](https://hex.pm/packages/carotte)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/carotte/)

A type-safe RabbitMQ client for Gleam that provides a clean, idiomatic interface for message queue operations on the Erlang VM.

## Features

- **Type-safe API** - Leverage Gleam's type system for safe message handling
- **High Performance** - Built on top of the battle-tested `amqp_client` Erlang library
- **Idiomatic Gleam** - Clean, functional API with everything in a single module
- **Complete Feature Set** - Support for exchanges, queues, publishing, consuming, and more
- **Supervised Consumers** - OTP-based consumer supervision with automatic restarts
- **Connection Helpers** - Built-in reconnection support and connection monitoring
- **Async Operations** - Non-blocking operations with `_async` variants
- **Flexible Message Acknowledgment** - Manual acknowledgment support for reliable message processing
- **Full Headers Support** - Send and receive message headers with type-safe accessors
- **Operation-Specific Error Types** - Granular error types for precise error handling

## Installation

```sh
gleam add carotte
```

## Quick Start

```gleam
import carotte
import gleam/erlang/process
import gleam/io

pub fn main() {
  // Connect to RabbitMQ
  let assert Ok(client) =
    carotte.ClientConfig(
      ..carotte.default_client(),
      host: "localhost",
      port: 5672,
    )
    |> carotte.start()

  // Open a channel
  let assert Ok(ch) = carotte.open_channel(client)

  // Declare an exchange
  let assert Ok(_) =
    carotte.Exchange(..carotte.exchange("my_exchange"), exchange_type: carotte.Direct)
    |> carotte.declare_exchange(ch)

  // Declare a durable queue
  let assert Ok(_) =
    carotte.QueueConfig(..carotte.default_queue("my_queue"), durable: True)
    |> carotte.declare_queue(ch)

  // Bind queue to exchange
  let assert Ok(_) =
    carotte.bind_queue(
      channel: ch,
      queue: "my_queue",
      exchange: "my_exchange",
      routing_key: "my_routing_key",
    )

  // Publish a message (payload is BitArray)
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "my_exchange",
      routing_key: "my_routing_key",
      payload: <<"Hello, RabbitMQ!">>,
      options: [],
    )

  // Start a consumer supervisor
  let consumers = process.new_name("consumers")
  let assert Ok(consumer) = carotte.start_consumer(consumers)

  // Subscribe to messages (supervised) - returns consumer_tag string
  let assert Ok(consumer_tag) =
    carotte.subscribe(
      consumer,
      channel: ch,
      queue: "my_queue",
      callback: fn(msg, _deliver) {
        // msg.payload is BitArray - convert to string if needed
        let assert Ok(text) = bit_array.to_string(msg.payload)
        io.println("Received: " <> text)
        // Messages are auto-acknowledged by default
      },
    )

  // Clean up
  let assert Ok(_) = carotte.unsubscribe(channel: ch, consumer_tag:)
  let assert Ok(_) = carotte.close(client)
}
```

## Core Concepts

### Connection Management

Create and configure a RabbitMQ connection:

```gleam
import gleam/time/duration

let assert Ok(client) =
  carotte.ClientConfig(
    ..carotte.default_client(),
    username: "admin",
    password: "secret",
    host: "rabbitmq.example.com",
    virtual_host: "/production",
    heartbeat: duration.seconds(30),
    connection_timeout: duration.seconds(60),
  )
  |> carotte.start()

// Check connection status
assert carotte.is_connected(client) == True

// Reconnect if needed
case carotte.is_connected(client) {
  True -> client
  False -> {
    let assert Ok(new_client) = carotte.reconnect(client)
    new_client
  }
}
```

### Exchanges

Carotte supports all RabbitMQ exchange types:

```gleam
// Create a durable topic exchange
carotte.Exchange(
  ..carotte.exchange("logs"),
  exchange_type: carotte.Topic,
  durable: True,
)
|> carotte.declare_exchange(channel)

// Available exchange types:
// - Direct: Route based on exact routing key match
// - Topic: Route based on routing key patterns
// - Fanout: Route to all bound queues
// - Headers: Route based on message headers
```

### Queues

Declare and configure queues using record update syntax:

```gleam
carotte.QueueConfig(
  ..carotte.default_queue("task_queue"),
  durable: True,       // Survive broker restart
  exclusive: True,     // Only one consumer allowed
  auto_delete: True,   // Delete when last consumer disconnects
)
|> carotte.declare_queue(channel)
```

### Publishing Messages

Publish messages with various options. The payload is a `BitArray`, which allows sending any binary data:

```gleam
import gleam/bit_array
import gleam/time/duration

// For text/JSON, convert string to BitArray
let json_payload = bit_array.from_string(json.to_string(user_data))

carotte.publish(
  channel: ch,
  exchange: "notifications",
  routing_key: "user.signup",
  payload: json_payload,
  options: [
    carotte.Persistent(True),
    carotte.ContentType("application/json"),
    carotte.MessageHeaders(
      carotte.headers_from_list([
        #("user_id", carotte.StringHeader("123")),
        #("retry_count", carotte.IntHeader(0)),
      ])
    ),
    carotte.Expiration(duration.seconds(60)), // Message expires in 60 seconds
  ]
)
```

### Supervised Consumers

Carotte integrates with gleam_otp for proper OTP supervision of consumers. The recommended approach is to add the consumer supervisor to your application's supervision tree using `consumer_supervised`:

```gleam
import gleam/erlang/process
import gleam/otp/static_supervisor

pub fn start_app() {
  // Create a name for the consumer supervisor at program startup
  let consumers_name = process.new_name("consumers")

  // Create the child specification
  let consumer_spec = carotte.consumer_supervised(consumers_name)

  // Add to your application's supervision tree
  let assert Ok(_) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(consumer_spec)
    |> static_supervisor.start()

  // Later, get the consumer reference to subscribe
  let consumer = carotte.named_consumer(consumers_name)

  // Subscribe to queues (consumers are supervised) - returns consumer_tag
  let assert Ok(consumer_tag) =
    carotte.subscribe(
      consumer,
      channel: ch,
      queue: "work_queue",
      callback: fn(payload, deliver) {
        // payload.payload is BitArray - convert to string for text messages
        let assert Ok(text) = bit_array.to_string(payload.payload)
        io.println("Processing: " <> text)
        io.println("Exchange: " <> deliver.exchange)
        io.println("Routing key: " <> deliver.routing_key)
        // If callback crashes, consumer will be restarted by supervisor
      }
    )
}
```

**Standalone mode** (for simpler use cases without a supervision tree):

```gleam
// Start supervisor directly (linked to calling process)
let consumers = process.new_name("consumers")
let assert Ok(consumer) = carotte.start_consumer(consumers)

let assert Ok(consumer_tag) = carotte.subscribe(consumer, channel: ch, queue: "my_queue", callback: handler)
```

### Manual Acknowledgment

For more control over message acknowledgment:

```gleam
let assert Ok(consumer_tag) =
  carotte.subscribe_with_options(
    consumer,
    channel: ch,
    queue: "work_queue",
    callback: fn(msg, deliver) {
      // Process the message
      case process_message(msg) {
        Ok(_) -> {
          // Acknowledge on success
          let assert Ok(_) = carotte.ack_single(ch, deliver.delivery_tag)
        }
        Error(_) -> {
          // Don't ack - message will be redelivered
        }
      }
      Nil
    },
    options: [carotte.AutoAck(False)],
  )

// Acknowledge multiple messages at once
let assert Ok(_) = carotte.ack(ch, deliver.delivery_tag, True)
```

### Message Headers

Carotte supports reading and writing message headers. Headers can contain various types of values:

```gleam
// Available header types
carotte.BoolHeader(True)
carotte.IntHeader(42)
carotte.FloatHeader(3.14)
carotte.StringHeader("hello")
carotte.ListHeader([carotte.IntHeader(1), carotte.IntHeader(2)])
```

**Sending headers:**

```gleam
carotte.publish(
  channel: ch,
  exchange: "my_exchange",
  routing_key: "my_key",
  payload: <<"Hello!">>,
  options: [
    carotte.MessageHeaders(
      carotte.headers_from_list([
        #("user_id", carotte.StringHeader("123")),
        #("priority", carotte.IntHeader(1)),
      ])
    ),
  ],
)
```

**Reading headers from received messages:**

```gleam
carotte.subscribe(
  consumer,
  channel: ch,
  queue: "my_queue",
  callback: fn(payload, _deliver) {
    // Convert headers to a list of name-value pairs
    let headers = carotte.headers_to_list(payload.headers)

    // Find a specific header
    let user_id = list.find(headers, fn(h) { h.0 == "user_id" })

    case user_id {
      Ok(#(_, carotte.StringHeader(id))) -> io.println("User: " <> id)
      _ -> io.println("No user_id header found")
    }
  },
)
```

## Error Handling

Carotte provides operation-specific error types for precise error handling. Each operation category has its own error type, making it easy to handle errors appropriately.

### Error Types

| Error Type | Used By | Variants |
|------------|---------|----------|
| `ConnectionError` | `start`, `close`, `reconnect` | `ConnectionBlocked`, `ConnectionClosed`, `ConnectionAuthFailure`, `ConnectionRefused`, `ConnectionTimeout`, `NotConnected`, `AlreadyConnected`, `ReconnectionFailed`, `ConnectionUnknownError` |
| `ChannelError` | `open_channel` | `ChannelClosed`, `ChannelProcessNotFound`, `ChannelConnectionClosed`, `ChannelUnknownError` |
| `ExchangeError` | `declare_exchange`, `delete_exchange`, `bind_exchange`, `unbind_exchange` | `ExchangeNotFound`, `ExchangeAccessRefused`, `ExchangePreconditionFailed`, `ExchangeChannelClosed`, `ExchangeUnknownError` |
| `QueueError` | `declare_queue`, `delete_queue`, `bind_queue`, `unbind_queue`, `purge_queue`, `queue_status` | `QueueNotFound`, `QueueAccessRefused`, `QueuePreconditionFailed`, `QueueResourceLocked`, `QueueChannelClosed`, `QueueUnknownError` |
| `PublishError` | `publish` | `PublishNoRoute`, `PublishChannelClosed`, `PublishUnknownError` |
| `ConsumeError` | `subscribe`, `unsubscribe`, `ack` | `ConsumeInitTimeout`, `ConsumeInitFailed`, `ConsumeProcessNotFound`, `ConsumeChannelClosed`, `ConsumeUnknownError` |

### Handling Errors

```gleam
// Connection errors
case carotte.start(client_config) {
  Ok(client) -> process_messages(client)
  Error(carotte.ConnectionAuthFailure(msg)) -> {
    io.println("Authentication failed: " <> msg)
  }
  Error(carotte.ConnectionTimeout(msg)) -> {
    io.println("Connection timeout: " <> msg)
  }
  Error(other) -> {
    io.println("Connection error: " <> carotte.describe_connection_error(other))
  }
}

// Queue errors
case carotte.declare_queue(my_queue, channel) {
  Ok(queue) -> use_queue(queue)
  Error(carotte.QueueAccessRefused(msg)) -> {
    io.println("Access refused: " <> msg)
  }
  Error(carotte.QueuePreconditionFailed(msg)) -> {
    io.println("Queue configuration mismatch: " <> msg)
  }
  Error(other) -> {
    io.println("Queue error: " <> carotte.describe_queue_error(other))
  }
}

// Publish errors
case carotte.publish(channel:, exchange:, routing_key:, payload:, options: [carotte.Mandatory(True)]) {
  Ok(_) -> io.println("Message published")
  Error(carotte.PublishNoRoute(msg)) -> {
    io.println("No route for message: " <> msg)
  }
  Error(other) -> {
    io.println("Publish error: " <> carotte.describe_publish_error(other))
  }
}
```

### Error Description Functions

Each error type has a corresponding `describe_*_error` function that converts the error to a human-readable string:

```gleam
carotte.describe_connection_error(err)  // ConnectionError -> String
carotte.describe_channel_error(err)     // ChannelError -> String
carotte.describe_exchange_error(err)    // ExchangeError -> String
carotte.describe_queue_error(err)       // QueueError -> String
carotte.describe_publish_error(err)     // PublishError -> String
carotte.describe_consume_error(err)     // ConsumeError -> String
```

## Advanced Features

### Asynchronous Operations

Most operations have async variants for non-blocking execution:

```gleam
// Async queue declaration
carotte.declare_queue_async(my_queue, channel)

// Async exchange deletion
carotte.delete_exchange_async(channel:, exchange: "old_exchange", if_unused: True)

// Async queue binding
carotte.bind_queue_async(
  channel:,
  queue: "my_queue",
  exchange: "my_exchange",
  routing_key: "key"
)
```

### Queue Management

Perform administrative operations on queues:

```gleam
// Get queue status
let assert Ok(status) = carotte.queue_status(channel:, queue: "my_queue")
io.println("Messages: " <> int.to_string(status.message_count))
io.println("Consumers: " <> int.to_string(status.consumer_count))

// Purge all messages from a queue
let assert Ok(message_count) = carotte.purge_queue(channel:, queue: "my_queue")

// Delete a queue
let assert Ok(_) = carotte.delete_queue(
  channel:,
  queue: "my_queue",
  if_unused: True,  // Only delete if no consumers
  if_empty: True    // Only delete if empty
)
```

### Exchange Bindings

Create complex routing topologies:

```gleam
// Bind exchange to exchange
carotte.bind_exchange(
  channel:,
  source: "raw_logs",
  destination: "processed_logs",
  routing_key: "*.error"
)

// Unbind when no longer needed
carotte.unbind_exchange(
  channel:,
  source: "raw_logs",
  destination: "processed_logs",
  routing_key: "*.error"
)
```

## Development

```bash
# Run tests (requires local RabbitMQ on localhost:5672)
gleam test

# Build documentation
gleam docs build

# Format code
gleam format
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built on top of the robust [amqp_client](https://github.com/rabbitmq/rabbitmq-server/tree/main/deps/amqp_client) Erlang library
- Inspired by RabbitMQ clients in other languages
- Thanks to the Gleam community for their support and feedback

## Support

- [Documentation](https://hexdocs.pm/carotte)
- [Issue Tracker](https://github.com/renatillas/carotte/issues)
- [Discussions](https://github.com/renatillas/carotte/discussions)
