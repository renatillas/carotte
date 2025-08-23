# Carotte 🥕

[![Package Version](https://img.shields.io/hexpm/v/carotte)](https://hex.pm/packages/carotte)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/carotte/)

A type-safe RabbitMQ client for Gleam that provides a clean, idiomatic interface for message queue operations on the Erlang VM.

## Features

- 🔒 **Type-safe API** - Leverage Gleam's type system for safe message handling
- 🚀 **High Performance** - Built on top of the battle-tested `amqp_client` Erlang library  
- 🎯 **Idiomatic Gleam** - Clean, functional API that feels natural in Gleam
- 📦 **Complete Feature Set** - Support for exchanges, queues, publishing, consuming, and more
- ⚡ **Async Operations** - Non-blocking operations with `_async` variants
- 🔄 **Flexible Message Acknowledgment** - Manual acknowledgment support for reliable message processing

## Installation

```sh
gleam add carotte
```

## Quick Start

```gleam
import carotte
import carotte/channel
import carotte/exchange
import carotte/queue
import carotte/publisher
import gleam/io

pub fn main() {
  // Connect to RabbitMQ
  let assert Ok(client) = 
    carotte.default_client()
    |> carotte.with_host("localhost")
    |> carotte.with_port(5672)
    |> carotte.start()

  // Open a channel
  let assert Ok(ch) = channel.open_channel(client)

  // Declare an exchange
  let assert Ok(_) = 
    exchange.new("my_exchange")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(ch)

  // Declare a queue
  let assert Ok(_) = 
    queue.new("my_queue")
    |> queue.as_durable()
    |> queue.declare(ch)

  // Bind queue to exchange
  let assert Ok(_) = 
    queue.bind(
      channel: ch,
      queue: "my_queue",
      exchange: "my_exchange",
      routing_key: "my_routing_key",
    )

  // Publish a message
  let assert Ok(_) = 
    publisher.publish(
      channel: ch,
      exchange: "my_exchange",
      routing_key: "my_routing_key",
      payload: "Hello, RabbitMQ!",
      options: [],
    )

  // Subscribe to messages
  let assert Ok(consumer_tag) = 
    queue.subscribe(
      channel: ch,
      queue: "my_queue",
      callback: fn(msg, deliver) {
        io.println("Received: " <> msg.payload)
        // Messages are auto-acknowledged by default
      },
    )

  // Clean up
  let assert Ok(_) = carotte.close(client)
}
```

## Core Concepts

### Connection Management

Create and configure a RabbitMQ connection:

```gleam
let client = 
  carotte.default_client()
  |> carotte.with_username("admin")
  |> carotte.with_password("secret")
  |> carotte.with_host("rabbitmq.example.com")
  |> carotte.with_virtual_host("/production")
  |> carotte.with_heartbeat(30)
  |> carotte.start()
```

### Exchanges

Carotte supports all RabbitMQ exchange types:

```gleam
// Create a topic exchange
exchange.new("logs")
|> exchange.with_type(exchange.Topic)
|> exchange.as_durable()
|> exchange.declare(channel)

// Available exchange types:
// - Direct: Route based on exact routing key match
// - Topic: Route based on routing key patterns
// - Fanout: Route to all bound queues
// - Headers: Route based on message headers
```

### Queues

Declare and configure queues:

```gleam
queue.new("task_queue")
|> queue.as_durable()        // Survive broker restart
|> queue.as_exclusive()      // Only one consumer allowed
|> queue.with_auto_delete()  // Delete when last consumer disconnects
|> queue.declare(channel)
```

### Publishing Messages

Publish messages with various options:

```gleam
publisher.publish(
  channel: ch,
  exchange: "notifications",
  routing_key: "user.signup",
  payload: json.to_string(user_data),
  options: [
    publisher.Persistent(True),
    publisher.ContentType("application/json"),
    publisher.Headers(
      publisher.headers_from_list([
        #("user_id", publisher.StringHeader("123")),
        #("retry_count", publisher.IntHeader(0)),
      ])
    ),
    publisher.Expiration("60000"), // Message expires in 60 seconds
  ]
)
```

### Consuming Messages

Subscribe to queues and handle messages:

```gleam
queue.subscribe(
  channel: ch,
  queue: "work_queue",
  callback: fn(payload, deliver) {
    // Process the message
    io.println("Processing: " <> payload.payload)
    
    // Access delivery metadata
    io.println("Exchange: " <> deliver.exchange)
    io.println("Routing key: " <> deliver.routing_key)
    
    // Message is automatically acknowledged on success
  }
)
```

### Manual Acknowledgment

For more control over message acknowledgment:

```gleam
// Acknowledge a single message
let assert Ok(_) = queue.ack_single(ch, deliver.delivery_tag)

// Acknowledge multiple messages
let assert Ok(_) = queue.ack(ch, deliver.delivery_tag, True)
```

## Error Handling

Carotte provides detailed error types for robust error handling:

### Error Types

```gleam
pub type CarotteError {
  // Connection errors
  Blocked                        // Connection blocked by broker
  Closed                         // Connection closed
  ConnectionRefused(String)      // Connection refused by server
  ConnectionTimeout(String)      // Connection or operation timed out
  
  // Authentication/Authorization
  AuthFailure(String)           // Authentication failed
  AccessRefused(String)         // Access denied to resource
  NotAllowed(String)            // Operation not allowed
  
  // Resource errors  
  ProcessNotFound               // Process/connection not found
  AlreadyRegistered(String)     // Process name already registered
  NotFound(String)              // Resource not found (exchange, queue, etc.)
  ResourceLocked(String)        // Resource is locked (exclusive queue, etc.)
  
  // Protocol errors
  ChannelClosed(String)         // Channel was closed
  FrameError(String)            // AMQP frame error
  UnexpectedFrame(String)       // Unexpected frame received
  CommandInvalid(String)        // Invalid AMQP command
  
  // Operational errors
  PreconditionFailed(String)    // Precondition not met (e.g., queue in use)
  NoRoute(String)               // No route found for message
  InvalidPath(String)           // Invalid resource path
  NotImplemented(String)        // Feature not implemented
  InternalError(String)         // Internal server error
  
  // Fallback
  UnknownError(String)          // Unknown/unmapped error
}
```

Handle errors appropriately:

```gleam
case carotte.start(client_config) {
  Ok(client) -> {
    // Connection successful
    process_messages(client)
  }
  Error(AuthFailure(msg)) -> {
    io.println("Authentication failed: " <> msg)
    // Handle auth error
  }
  Error(ConnectionTimeout(msg)) -> {
    io.println("Connection timeout: " <> msg)
    // Retry connection
  }
  Error(other) -> {
    io.println("Connection error: " <> string.inspect(other))
    // Handle other errors
  }
}
```

## Advanced Features

### Asynchronous Operations

Most operations have async variants for non-blocking execution:

```gleam
// Async queue declaration
queue.declare_async(my_queue, channel)

// Async exchange deletion
exchange.delete_async(channel: ch, exchange: "old_exchange", unused: True)

// Async queue binding
queue.bind_async(
  channel: ch,
  queue: "my_queue",
  exchange: "my_exchange",
  routing_key: "key"
)
```

### Queue Management

Perform administrative operations on queues:

```gleam
// Get queue status
let assert Ok(status) = queue.status(channel: ch, queue: "my_queue")
io.println("Messages: " <> int.to_string(status.message_count))
io.println("Consumers: " <> int.to_string(status.consumer_count))

// Purge all messages from a queue
let assert Ok(message_count) = queue.purge(channel: ch, queue: "my_queue")

// Delete a queue
let assert Ok(_) = queue.delete(
  channel: ch,
  queue: "my_queue",
  if_unused: True,  // Only delete if no consumers
  if_empty: True    // Only delete if empty
)
```

### Exchange Bindings

Create complex routing topologies:

```gleam
// Bind exchange to exchange
exchange.bind(
  channel: ch,
  source: "raw_logs",
  destination: "processed_logs",
  routing_key: "*.error"
)

// Unbind when no longer needed
exchange.unbind(
  channel: ch,
  source: "raw_logs",
  destination: "processed_logs", 
  routing_key: "*.error"
)
```

## Examples

### Work Queue Pattern

Distribute time-consuming tasks among multiple workers:

```gleam
// Producer
pub fn send_task(channel, task_data) {
  publisher.publish(
    channel: channel,
    exchange: "",
    routing_key: "task_queue",
    payload: task_data,
    options: [publisher.Persistent(True)]
  )
}

// Worker
pub fn start_worker(channel) {
  let assert Ok(queue) = 
    queue.new("task_queue")
    |> queue.as_durable()
    |> queue.declare(channel)

  queue.subscribe(
    channel: channel,
    queue: "task_queue",
    callback: fn(payload, _meta) {
      // Simulate work
      process.sleep(1000)
      io.println("Task completed: " <> payload.payload)
    }
  )
}
```

### Publish/Subscribe Pattern

Send messages to multiple consumers:

```gleam
// Publisher
pub fn broadcast_event(channel, event) {
  publisher.publish(
    channel: channel,
    exchange: "events",
    routing_key: "",  // Fanout ignores routing key
    payload: event,
    options: []
  )
}

// Subscriber
pub fn subscribe_to_events(channel, handler) {
  // Create fanout exchange
  let assert Ok(_) = 
    exchange.new("events")
    |> exchange.with_type(exchange.Fanout)
    |> exchange.declare(channel)

  // Create exclusive queue for this subscriber
  let assert Ok(q) = 
    queue.new("")  // Server-generated name
    |> queue.as_exclusive()
    |> queue.declare(channel)

  // Bind to exchange
  let assert Ok(_) = 
    queue.bind(
      channel: channel,
      queue: q.name,
      exchange: "events",
      routing_key: ""
    )

  // Subscribe
  queue.subscribe(
    channel: channel,
    queue: q.name,
    callback: handler
  )
}
```

### Topic-Based Routing

Route messages based on patterns:

```gleam
// Setup topic exchange
let assert Ok(_) = 
  exchange.new("logs")
  |> exchange.with_type(exchange.Topic)
  |> exchange.declare(channel)

// Subscribe to error logs from any service
queue.bind(
  channel: channel,
  queue: "error_logs",
  exchange: "logs",
  routing_key: "*.error"
)

// Subscribe to all logs from auth service
queue.bind(
  channel: channel,
  queue: "auth_logs",
  exchange: "logs",
  routing_key: "auth.*"
)

// Publish logs
publisher.publish(
  channel: channel,
  exchange: "logs",
  routing_key: "auth.error",  // Will go to both queues
  payload: "Authentication failed",
  options: []
)
```

## Requirements

- Gleam 1.0 or later
- Erlang/OTP 26 or later
- RabbitMQ 3.x or later

## Development

```bash
# Run tests
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

- 📚 [Documentation](https://hexdocs.pm/carotte)
- 🐛 [Issue Tracker](https://github.com/renatillas/carotte/issues)
- 💬 [Discussions](https://github.com/renatillas/carotte/discussions)