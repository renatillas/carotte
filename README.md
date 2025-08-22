# 🥕 Carotte

## A RabbitMQ client for Gleam

[![Package Version](https://img.shields.io/hexpm/v/carotte)](https://hex.pm/packages/carotte)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/carotte/)

A type-safe RabbitMQ client for Gleam with comprehensive error handling and support for both supervised and unsupervised connections.

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
import gleam/erlang/process

pub fn main() {
  // Create a client with a unique process name
  let assert Ok(client) =
    carotte.default_client(process.new_name("my_rabbitmq_client"))
    |> carotte.start()

  // Open a channel
  let assert Ok(ch) = channel.open_channel(client.data)

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
  let assert Ok(_) = 
    queue.subscribe(
      channel: ch,
      queue: "my_queue",
      callback: fn(msg, deliver) {
        io.println("Received: " <> msg.payload)
        // Messages are auto-acknowledged by default
      },
    )
}
```

## Client Configuration

### Basic Client

```gleam
import gleam/erlang/process

// Create a client with default settings (guest/guest on localhost:5672)
let client_builder = carotte.default_client(process.new_name("my_client"))

// Customize connection settings
let client_builder = 
  carotte.default_client(process.new_name("my_client"))
  |> carotte.with_host("rabbitmq.example.com")
  |> carotte.with_port(5672)
  |> carotte.with_username("myuser")
  |> carotte.with_password("mypassword")
  |> carotte.with_virtual_host("/myvhost")
  |> carotte.with_heartbeat(30)
  |> carotte.with_connection_timeout(10_000)

// Start the client
let assert Ok(client) = carotte.start(client_builder)
```

### Supervised Client

For production use, it's recommended to use supervised clients that can be restarted automatically:

```gleam
import gleam/otp/static_supervisor

let client_spec = 
  carotte.default_client(process.new_name("supervised_client"))
  |> carotte.supervised()

let assert Ok(sup) =
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.add(client_spec)
  |> static_supervisor.start()

// Access the supervised client by name
let client = carotte.named_client(process.new_name("supervised_client"))
```

## Error Handling

Carotte provides comprehensive error handling with specific error types for different failure scenarios:

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

### Error Handling Examples

```gleam
// Handle connection failures
case carotte.start(client_builder) {
  Ok(client) -> {
    // Connection successful
    client
  }
  Error(actor.InitFailed(msg)) -> {
    // Handle connection error
    io.println("Failed to connect: " <> msg)
    panic
  }
}

// Handle resource errors
case queue.declare(queue.new("amq.reserved"), channel) {
  Ok(_) -> io.println("Queue declared")
  Error(carotte.AccessRefused(msg)) -> {
    // Handle reserved name error
    io.println("Access refused: " <> msg)
  }
  Error(other) -> {
    // Handle other errors
    io.println("Error: " <> carotte.error_to_string(other))
  }
}

// Handle binding errors
case queue.bind(channel: ch, queue: "my_queue", exchange: "nonexistent", routing_key: "") {
  Ok(_) -> io.println("Bound successfully")
  Error(carotte.NotFound(msg)) -> {
    io.println("Exchange not found: " <> msg)
  }
  Error(_) -> io.println("Binding failed")
}
```

## Exchanges

### Exchange Types

```gleam
exchange.Direct   // Direct exchange (default)
exchange.Fanout   // Fanout exchange
exchange.Topic    // Topic exchange
exchange.Headers  // Headers exchange
```

### Declaring Exchanges

```gleam
// Simple declaration
let assert Ok(_) = exchange.declare(exchange.new("my_exchange"), channel)

// With options
let assert Ok(_) = 
  exchange.new("my_exchange")
  |> exchange.with_type(exchange.Topic)
  |> exchange.as_durable()           // Survive broker restart
  |> exchange.as_internal()          // Not accessible to publishers
  |> exchange.with_auto_delete()     // Delete when no longer used
  |> exchange.declare(channel)

// Async declaration (no wait for server confirmation)
let assert Ok(_) = 
  exchange.new("my_exchange")
  |> exchange.declare_async(channel)
```

### Exchange Operations

```gleam
// Delete an exchange
let assert Ok(_) = exchange.delete(channel, "my_exchange", if_unused: True)

// Bind exchanges (exchange-to-exchange binding)
let assert Ok(_) = exchange.bind(
  channel: channel,
  source: "source_exchange",
  destination: "dest_exchange",
  routing_key: "routing_key",
)

// Unbind exchanges
let assert Ok(_) = exchange.unbind(
  channel: channel,
  source: "source_exchange",
  destination: "dest_exchange",
  routing_key: "routing_key",
)
```

## Queues

### Declaring Queues

```gleam
// Simple declaration
let assert Ok(declared) = queue.declare(queue.new("my_queue"), channel)
// declared.name = "my_queue"
// declared.message_count = 0
// declared.consumer_count = 0

// With options
let assert Ok(_) = 
  queue.new("my_queue")
  |> queue.as_durable()        // Survive broker restart
  |> queue.as_exclusive()      // Only accessible by this connection
  |> queue.with_auto_delete()  // Delete when no longer used
  |> queue.declare(channel)

// Async declaration
let assert Ok(_) = queue.declare_async(queue.new("my_queue"), channel)
```

### Queue Operations

```gleam
// Get queue status
let assert Ok(status) = queue.status(channel, "my_queue")

// Delete a queue
let assert Ok(msg_count) = queue.delete(
  channel,
  "my_queue",
  if_unused: True,   // Only delete if no consumers
  if_empty: True,     // Only delete if empty
)

// Purge messages from queue
let assert Ok(purged_count) = queue.purge(channel, "my_queue")

// Bind queue to exchange
let assert Ok(_) = queue.bind(
  channel: channel,
  queue: "my_queue",
  exchange: "my_exchange",
  routing_key: "my_key",
)

// Unbind queue from exchange
let assert Ok(_) = queue.unbind(
  channel: channel,
  queue: "my_queue",
  exchange: "my_exchange",
  routing_key: "my_key",
)
```

## Publishing Messages

### Basic Publishing

```gleam
let assert Ok(_) = publisher.publish(
  channel: channel,
  exchange: "my_exchange",
  routing_key: "my_key",
  payload: "Hello, World!",
  options: [],
)
```

### Publishing Options

```gleam
import carotte/publisher.{
  Mandatory, ContentType, ContentEncoding, Headers,
  Persistent, CorrelationId, Priority, Expiration,
  MessageId, Timestamp, Type
}

// Create headers
let headers = publisher.headers_from_list([
  #("user_id", publisher.StringHeader("12345")),
  #("retry_count", publisher.IntHeader(3)),
  #("is_test", publisher.BoolHeader(True)),
])

// Publish with options
let assert Ok(_) = publisher.publish(
  channel: channel,
  exchange: "my_exchange",
  routing_key: "my_key",
  payload: "Important message",
  options: [
    Mandatory(True),                    // Must be routed to a queue
    ContentType("application/json"),    // Content type
    ContentEncoding("utf-8"),           // Content encoding
    Headers(headers),                    // Custom headers
    Persistent(True),                    // Persist to disk
    CorrelationId("correlation-123"),   // Correlation ID
    Priority(9),                         // Priority (0-9)
    Expiration("60000"),                 // TTL in milliseconds
    MessageId("msg-123"),                // Message ID
    Timestamp(1234567890),               // Unix timestamp
    Type("notification"),                // Message type
  ],
)
```

## Consuming Messages

### Subscribe to a Queue

```gleam
// Basic subscription (with auto-acknowledgment)
let assert Ok(consumer_tag) = queue.subscribe(
  channel: channel,
  queue: "my_queue",
  callback: fn(msg, deliver) {
    io.println("Received: " <> msg.payload)
    io.println("From exchange: " <> deliver.exchange)
    // Messages are auto-acknowledged by default
  },
)

// Manual acknowledgment (future feature - not yet implemented)
// To manually acknowledge messages, you would need to:
// 1. Disable auto-ack in subscription options
// 2. Call queue.ack with the delivery tag
//
// Example (when implemented):
// let assert Ok(_) = queue.ack(channel, deliver.delivery_tag, False)

// Unsubscribe
let assert Ok(_) = queue.unsubscribe(channel, consumer_tag)
```

### Message Structure

```gleam
// Message payload
pub type Payload {
  Payload(
    payload: String,           // Message content
    exchange: String,          // Source exchange
    routing_key: String,       // Routing key used
    redelivered: Bool,         // Was redelivered
    headers: Option(Headers),  // Message headers
    content_type: Option(String),
    content_encoding: Option(String),
    persistent: Option(Bool),
    priority: Option(Int),
    correlation_id: Option(String),
    reply_to: Option(String),
    expiration: Option(String),
    message_id: Option(String),
    timestamp: Option(Int),
    type_: Option(String),
    user_id: Option(String),
    app_id: Option(String),
    cluster_id: Option(String),
  )
}

// Delivery information
pub type Deliver {
  Deliver(
    consumer_tag: String,
    delivery_tag: Int,  // Used for acknowledgment
    redelivered: Bool,
    exchange: String,
    routing_key: String,
  )
}
```

## Testing

The library includes comprehensive error handling tests. To run tests with RabbitMQ:

```sh
# Start RabbitMQ (using Docker)
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:management

# Run tests
gleam test

# Stop RabbitMQ
docker stop rabbitmq && docker rm rabbitmq
```

## Examples

Check the `test/` directory for comprehensive examples of:
- Error handling for various failure scenarios
- Exchange and queue operations
- Publishing and consuming messages
- Supervised and unsupervised clients

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam docs build  # Build documentation
```

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

Further documentation can be found at <https://hexdocs.pm/carotte>.