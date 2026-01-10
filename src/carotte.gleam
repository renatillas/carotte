//// <script>
//// const docs = [
////   {
////     header: "Connection",
////     types: ["Client", "ClientConfig", "ConnectionState", "DisconnectReason", "ConnectionEvent"],
////     functions: ["default_client", "start", "close", "is_connected", "connection_state", "reconnect"]
////   },
////   {
////     header: "Channels",
////     types: ["Channel"],
////     functions: ["open_channel"]
////   },
////   {
////     header: "Exchanges",
////     types: ["Exchange", "ExchangeType"],
////     functions: ["exchange", "declare_exchange", "declare_exchange_async", "delete_exchange", "delete_exchange_async", "bind_exchange", "bind_exchange_async", "unbind_exchange", "unbind_exchange_async"]
////   },
////   {
////     header: "Queues",
////     types: ["QueueConfig", "Queue", "Deliver", "Payload", "QueueOption"],
////     functions: ["queue", "declare_queue", "declare_queue_async", "delete_queue", "delete_queue_async", "bind_queue", "bind_queue_async", "unbind_queue", "purge_queue", "purge_queue_async", "queue_status"]
////   },
////   {
////     header: "Publishing",
////     types: ["HeaderList", "HeaderValue", "PublishOption"],
////     functions: ["publish", "empty_headers", "headers_from_list", "headers_to_list"]
////   },
////   {
////     header: "Consuming",
////     types: ["Consumer", "ConsumerSupervisorMessage"],
////     functions: ["start_consumer", "consumer_supervised", "named_consumer", "subscribe", "subscribe_with_options", "unsubscribe", "unsubscribe_async", "ack", "ack_single", "nack", "nack_single", "reject"]
////   },
////   {
////     header: "Errors",
////     types: ["ConnectionError", "ChannelError", "ExchangeError", "QueueError", "PublishError", "ConsumeError"],
////     functions: ["describe_connection_error", "describe_channel_error", "describe_exchange_error", "describe_queue_error", "describe_publish_error", "describe_consume_error"]
////   }
//// ]
////
//// const callback = () => {
////   const sidebar = document.querySelector(".sidebar")
////   const moduleMembers = document.querySelector(".module-members")
////
////   // Find the Types and Values headings in sidebar
////   const sidebarH2s = sidebar.querySelectorAll("h2")
////   let typesH2, valuesH2
////   sidebarH2s.forEach(h2 => {
////     if (h2.textContent === "Types") typesH2 = h2
////     if (h2.textContent === "Values") valuesH2 = h2
////   })
////
////   // Get the original lists
////   const typesUl = typesH2?.nextElementSibling
////   const valuesUl = valuesH2?.nextElementSibling
////   if (!typesUl || !valuesUl) return
////
////   // Create new sidebar content
////   const newSidebarContent = document.createDocumentFragment()
////   const newMainContent = document.createDocumentFragment()
////
////   for (const section of docs) {
////     // Sidebar section header
////     const sidebarHeader = document.createElement("h2")
////     sidebarHeader.textContent = section.header
////     newSidebarContent.append(sidebarHeader)
////
////     // Sidebar list
////     const sidebarList = document.createElement("ul")
////     newSidebarContent.append(sidebarList)
////
////     // Main content section header
////     const mainHeader = document.createElement("h1")
////     mainHeader.className = "module-member-kind"
////     mainHeader.textContent = section.header
////     newMainContent.append(mainHeader)
////
////     // Move types
////     for (const name of (section.types || [])) {
////       const sidebarItem = typesUl.querySelector(`li:has(a[href="#${name}"])`)
////       const member = moduleMembers.querySelector(`.member:has(h2#${name})`)
////       if (sidebarItem) sidebarList.append(sidebarItem)
////       if (member) newMainContent.append(member)
////     }
////
////     // Move functions
////     for (const name of (section.functions || [])) {
////       const sidebarItem = valuesUl.querySelector(`li:has(a[href="#${name}"])`)
////       const member = moduleMembers.querySelector(`.member:has(h2#${name})`)
////       if (sidebarItem) sidebarList.append(sidebarItem)
////       if (member) newMainContent.append(member)
////     }
////   }
////
////   // Replace Types heading and list
////   typesH2.replaceWith(newSidebarContent)
////   typesUl.remove()
////   valuesH2.remove()
////   valuesUl.remove()
////
////   // Replace main content
////   const moduleTypes = document.querySelector("#module-types")
////   const moduleValues = document.querySelector("#module-values")
////   if (moduleTypes) {
////     moduleTypes.replaceWith(newMainContent)
////   }
////   if (moduleValues) {
////     moduleValues.remove()
////   }
//// }
////
//// document.readyState !== "loading"
////   ? callback()
////   : document.addEventListener("DOMContentLoaded", callback, { once: true })
//// </script>
////
//// # Carotte
////
//// A type-safe RabbitMQ client for Gleam that provides a clean, idiomatic interface
//// for message queue operations on the Erlang VM.
////
//// ## Quick Start
////
//// ```gleam
//// import carotte
//// import gleam/erlang/process
//// import gleam/io
////
//// pub fn main() {
////   // Connect to RabbitMQ
////   let assert Ok(client) = carotte.start(carotte.default_client())
////   let assert Ok(ch) = carotte.open_channel(client)
////
////   // Declare exchange and queue
////   let assert Ok(_) = carotte.declare_exchange(carotte.exchange("my_exchange"), ch)
////   let assert Ok(_) = carotte.declare_queue(carotte.queue("my_queue"), ch)
////   let assert Ok(_) = carotte.bind_queue(channel: ch, queue: "my_queue", exchange: "my_exchange", routing_key: "")
////
////   // Start consumer supervisor and subscribe
////   let consumers = process.new_name("consumers")
////   let assert Ok(consumer) = carotte.start_consumer(consumers)
////   let assert Ok(_) = carotte.subscribe(consumer, channel: ch, queue: "my_queue", callback: fn(msg, _) {
////     io.println("Received: " <> msg.payload)
////   })
////
////   // Publish a message
////   let assert Ok(_) = carotte.publish(channel: ch, exchange: "my_exchange", routing_key: "", payload: "Hello!", options: [])
//// }
//// ```
////
//// ## Features
////
//// - **Type-safe API**: Leverage Gleam's type system for safe message handling
//// - **OTP Supervision**: Integrate consumers into your application's supervision tree
////   via `consumer_supervised`, or use standalone mode with `start_consumer`
//// - **Operation-Specific Errors**: Granular error types (`ConnectionError`, `ChannelError`,
////   `ExchangeError`, `QueueError`, `PublishError`, `ConsumeError`) for precise error handling
//// - **Async Operations**: Non-blocking variants with `_async` suffix
//// - **Full Headers Support**: Type-safe message headers with `HeaderValue` types
//// - **Connection Helpers**: Built-in reconnection support and connection monitoring
////
//// ## OTP Supervision
////
//// For production use, integrate consumers into your supervision tree:
////
//// ```gleam
//// import gleam/erlang/process
//// import gleam/otp/static_supervisor
////
//// let consumers_name = process.new_name("consumers")
//// let spec = carotte.consumer_supervised(consumers_name)
////
//// static_supervisor.new(static_supervisor.OneForOne)
//// |> static_supervisor.add(spec)
//// |> static_supervisor.start()
////
//// let consumer = carotte.named_consumer(consumers_name)
//// carotte.subscribe(consumer, channel: ch, queue: "my_queue", callback: handler)
//// ```
////
//// ## Error Handling
////
//// Each operation category has its own error type:
////
//// | Error Type | Operations |
//// |------------|------------|
//// | `ConnectionError` | `start`, `close`, `reconnect` |
//// | `ChannelError` | `open_channel` |
//// | `ExchangeError` | `declare_exchange`, `delete_exchange`, `bind_exchange`, `unbind_exchange` |
//// | `QueueError` | `declare_queue`, `delete_queue`, `bind_queue`, `unbind_queue`, `purge_queue`, `queue_status` |
//// | `PublishError` | `publish` |
//// | `ConsumeError` | `subscribe`, `unsubscribe`, `ack` |
////
//// Use `describe_*_error` functions to convert errors to human-readable strings.
////

import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/otp/supervision
import gleam/result
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

// =============================================================================
// ERROR TYPES
// =============================================================================

/// Errors that can occur when establishing or managing RabbitMQ connections.
/// Returned by `start`, `close`, and `reconnect`.
pub type ConnectionError {
  /// The connection is blocked by the server due to resource constraints
  ConnectionBlocked
  /// The connection has been closed
  ConnectionClosed
  /// Authentication failed with the provided credentials
  ConnectionAuthFailure(String)
  /// Connection to the server was refused
  ConnectionRefused(String)
  /// Connection attempt timed out
  ConnectionTimeout(String)
  /// Connection is not currently active
  NotConnected
  /// Reconnection failed with the underlying cause
  ReconnectionFailed(ConnectionError)
  /// Connection is already established
  AlreadyConnected
  /// An unknown connection error occurred
  ConnectionUnknownError(String)
}

/// Errors that can occur when opening or using channels.
/// Returned by `open_channel`.
pub type ChannelError {
  /// The channel has been closed
  ChannelClosed(String)
  /// The channel process could not be found
  ChannelProcessNotFound
  /// The connection is closed, cannot open channel
  ChannelConnectionClosed
  /// An unknown channel error occurred
  ChannelUnknownError(String)
}

/// Errors that can occur during exchange operations.
/// Returned by `declare_exchange`, `delete_exchange`, `bind_exchange`, `unbind_exchange`.
pub type ExchangeError {
  /// The exchange was not found
  ExchangeNotFound(String)
  /// Access to the exchange was refused
  ExchangeAccessRefused(String)
  /// A precondition for the exchange operation failed
  ExchangePreconditionFailed(String)
  /// The channel is closed
  ExchangeChannelClosed(String)
  /// An unknown exchange error occurred
  ExchangeUnknownError(String)
}

/// Errors that can occur during queue operations.
/// Returned by `declare_queue`, `delete_queue`, `bind_queue`, `unbind_queue`, `purge_queue`, `queue_status`.
pub type QueueError {
  /// The queue was not found
  QueueNotFound(String)
  /// Access to the queue was refused
  QueueAccessRefused(String)
  /// A precondition for the queue operation failed
  QueuePreconditionFailed(String)
  /// The queue is locked and cannot be accessed
  QueueResourceLocked(String)
  /// The channel is closed
  QueueChannelClosed(String)
  /// An unknown queue error occurred
  QueueUnknownError(String)
}

/// Errors that can occur when publishing messages.
/// Returned by `publish`.
pub type PublishError {
  /// No route exists to deliver the message (when mandatory flag is set)
  PublishNoRoute(String)
  /// The channel is closed
  PublishChannelClosed(String)
  /// An unknown publish error occurred
  PublishUnknownError(String)
}

/// Errors that can occur during consumer operations.
/// Returned by `subscribe`, `subscribe_with_options`, `unsubscribe`, `ack`.
pub type ConsumeError {
  /// Consumer initialization timed out
  ConsumeInitTimeout
  /// Consumer initialization failed
  ConsumeInitFailed(String)
  /// The consumer process could not be found
  ConsumeProcessNotFound
  /// The channel is closed
  ConsumeChannelClosed(String)
  /// An unknown consume error occurred
  ConsumeUnknownError(String)
}

// =============================================================================
// CONNECTION TYPES
// =============================================================================

/// Represents an active connection to a RabbitMQ server.
/// This is an opaque type that encapsulates the underlying AMQP client process.
/// Use the builder pattern with `default_client()` and `start()` to create a client.
pub opaque type Client {
  Client(pid: Pid, config: ClientConfig)
}

/// Configuration builder for creating a RabbitMQ client.
/// Use `default_client()` to create a builder with sensible defaults,
/// then chain the `with_*` functions to customize the configuration.
pub type ClientConfig {
  ClientConfig(
    username: String,
    password: String,
    virtual_host: String,
    host: String,
    port: Int,
    channel_max: Int,
    frame_max: Int,
    /// Heartbeat interval for the connection.
    /// The minimum duration is one second.
    heartbeat: Duration,
    /// Timeout for establishing a connection.
    connection_timeout: Duration,
  )
}

/// Connection state.
pub type ConnectionState {
  Connected
  Disconnected(reason: DisconnectReason)
}

/// Reason for disconnection.
pub type DisconnectReason {
  /// Server closed the connection.
  ServerClosed
  /// Network error.
  NetworkError
  /// Explicitly closed by user.
  UserClosed
  /// Unknown reason.
  Unknown(String)
  /// The connection process is no longer running.
  ConnectionProcessNotAlive
}

/// Connection event for callbacks.
pub type ConnectionEvent {
  ConnectionDisconnected(DisconnectReason)
  ConnectionReconnected
}

// =============================================================================
// CHANNEL TYPES
// =============================================================================

/// Represents an AMQP channel within a connection.
/// Channels are lightweight connections that share a single TCP connection.
/// Most AMQP operations are performed on channels.
pub type Channel {
  Channel(pid: Pid)
}

// =============================================================================
// EXCHANGE TYPES
// =============================================================================

/// Represents an AMQP exchange configuration.
/// Exchanges receive messages from producers and route them to queues
/// based on routing rules defined by the exchange type.
///
/// Use `exchange()` to create an exchange with defaults, then customize
/// using record update syntax.
pub type Exchange {
  Exchange(
    name: String,
    exchange_type: ExchangeType,
    durable: Bool,
    auto_delete: Bool,
    internal: Bool,
    nowait: Bool,
  )
}

/// The type of routing logic an exchange uses to deliver messages to queues.
pub type ExchangeType {
  /// Messages are delivered to all bound queues regardless of routing key.
  Fanout
  /// Messages are delivered to queues with an exact routing key match.
  Direct
  /// Messages are delivered to queues with pattern-matching on routing key.
  /// Supports wildcards: `*` matches one word, `#` matches zero or more words.
  Topic
  /// Messages are routed based on header attributes rather than routing key.
  Headers
}

// =============================================================================
// QUEUE TYPES
// =============================================================================

/// Configuration for declaring a queue.
/// Use `queue()` to create a queue with sensible defaults,
/// then customize using record update syntax.
pub type QueueConfig {
  QueueConfig(
    name: String,
    passive: Bool,
    durable: Bool,
    exclusive: Bool,
    auto_delete: Bool,
    nowait: Bool,
  )
}

/// Represents a declared queue on the broker.
/// Returned by `declare_queue()` and `queue_status()` with current statistics.
pub type Queue {
  /// The declared queue with its name, current message count, and consumer count.
  Queue(name: String, message_count: Int, consumer_count: Int)
}

/// Metadata about a message delivery from the broker.
/// Contains information about how and from where the message was delivered.
pub type Deliver {
  Deliver(
    /// Identifier for the consumer that received this message.
    consumer_tag: String,
    /// Unique identifier for this delivery, used for acknowledgment.
    delivery_tag: Int,
    /// True if this message was previously delivered but not acknowledged.
    redelivered: Bool,
    /// The exchange the message was published to.
    exchange: String,
    /// The routing key used when the message was published.
    routing_key: String,
  )
}

/// A message payload received from the broker.
/// Contains the message body, AMQP properties, and custom headers.
pub type Payload {
  Payload(
    /// The message body as a string
    payload: String,
    /// AMQP message properties (content type, correlation ID, etc.)
    properties: List(PublishOption),
    /// Custom headers attached to the message
    headers: HeaderList,
  )
}

/// Options for subscribing to a queue.
pub type QueueOption {
  /// If True, messages are automatically acknowledged upon delivery.
  /// If False, you must call `ack()` to acknowledge messages manually.
  AutoAck(Bool)
}

// =============================================================================
// PUBLISHER TYPES
// =============================================================================

/// An opaque container for message headers.
/// Headers are key-value pairs that can be attached to messages for
/// additional metadata or routing with header exchanges.
///
/// Create with `headers_from_list()` and read with `headers_to_list()`.
pub opaque type HeaderList {
  HeaderList(List(#(String, atom.Atom, dynamic.Dynamic)))
}

/// Represents a typed header value.
/// AMQP headers support several primitive types.
pub type HeaderValue {
  /// A boolean header value.
  BoolHeader(Bool)
  /// A floating-point header value.
  FloatHeader(Float)
  /// An integer header value.
  IntHeader(Int)
  /// A string header value.
  StringHeader(String)
  /// A list of header values (nested).
  ListHeader(List(HeaderValue))
}

/// Options for publishing messages.
pub type PublishOption {
  /// If set, returns an error if the broker can't route the message to a queue.
  Mandatory(Bool)
  /// MIME content type.
  ContentType(String)
  /// MIME content encoding.
  ContentEncoding(String)
  /// Headers to attach to the message. Use `headers_from_list` to create headers
  /// for sending, and `headers_to_list` to read headers from received messages.
  MessageHeaders(HeaderList)
  /// If set, uses persistent delivery mode.
  /// Messages marked as persistent that are delivered to durable queues will be logged to disk.
  Persistent(Bool)
  /// Arbitrary application-specific message identifier.
  CorrelationId(String)
  /// Message priority, ranging from 0 to 9.
  Priority(Int)
  /// Name of the reply queue.
  ReplyTo(String)
  /// How long the message is valid before it expires.
  Expiration(Duration)
  /// Message identifier.
  MessageId(String)
  /// Timestamp associated with this message.
  /// Note: AMQP only supports second-level precision, so any nanoseconds
  /// in the timestamp will be truncated when sending.
  Timestamp(Timestamp)
  /// Message type.
  Type(String)
  /// Creating user ID. RabbitMQ will validate this against the active connection user.
  UserId(String)
  /// Application ID.
  AppId(String)
}

// =============================================================================
// SUPERVISOR TYPES
// =============================================================================

/// Configuration for a consumer.
pub opaque type ConsumerConfig {
  ConsumerConfig(
    channel: Channel,
    queue: String,
    auto_ack: Bool,
    callback: fn(Payload, Deliver) -> Nil,
  )
}

/// Opaque reference to a consumer supervisor.
///
/// Similar to how pog's Connection wraps a pool reference, this type
/// wraps the consumer supervisor name. Use it to subscribe to queues.
///
/// - Use `start_consumer` or `named_consumer` to get a Consumer
/// - Use `subscribe` with a Consumer to start consuming (returns consumer_tag)
/// - Use `unsubscribe` with channel + consumer_tag to stop consuming
pub opaque type Consumer {
  Consumer(name: process.Name(ConsumerSupervisorMessage))
}

// =============================================================================
// CONNECTION FUNCTIONS
// =============================================================================

/// Create a new client builder with default settings.
/// Uses guest/guest credentials on localhost:5672.
///
/// ## Example
/// ```gleam
/// let client = carotte.default_client()
///   |> carotte.start()
/// ```
pub fn default_client() -> ClientConfig {
  ClientConfig(
    username: "guest",
    password: "guest",
    virtual_host: "/",
    host: "localhost",
    port: 5672,
    channel_max: 2074,
    frame_max: 0,
    heartbeat: duration.seconds(10),
    connection_timeout: duration.seconds(60),
  )
}

/// Start a RabbitMQ client connection.
/// Returns an actor.StartResult which contains the client on success.
///
/// ## Example
/// ```gleam
/// case carotte.start(builder) {
///   Ok(client) -> // Use the client
///   Error(connection_error) -> // Handle connection error
/// }
/// ```
pub fn start(builder: ClientConfig) -> Result(Client, ConnectionError) {
  // Convert Duration to seconds for heartbeat
  let #(heartbeat_secs, heartbeat_nanoseconds) =
    duration.to_seconds_and_nanoseconds(builder.heartbeat)
  let heartbeat_secs = case heartbeat_nanoseconds > 0 {
    True -> heartbeat_secs + 1
    False -> heartbeat_secs
  }
  // Convert Duration to milliseconds for connection_timeout
  let #(timeout_secs, timeout_nanos) =
    duration.to_seconds_and_nanoseconds(builder.connection_timeout)
  let timeout_ms = timeout_secs * 1000 + timeout_nanos / 1_000_000

  use pid <- result.map(do_start(
    builder.username,
    builder.password,
    builder.virtual_host,
    builder.host,
    builder.port,
    builder.channel_max,
    builder.frame_max,
    heartbeat_secs,
    timeout_ms,
  ))
  Client(pid:, config: builder)
}

@external(erlang, "carotte_ffi", "start")
fn do_start(
  username: String,
  password: String,
  virtual_host: String,
  host: String,
  port: Int,
  channel_max: Int,
  frame_max: Int,
  heartbeat: Int,
  connection_timeout: Int,
) -> Result(Pid, ConnectionError)

/// Close the RabbitMQ client connection.
/// This will close all channels and the underlying AMQP connection.
pub fn close(client: Client) -> Result(Nil, ConnectionError) {
  do_close(client)
}

@external(erlang, "carotte_ffi", "close")
fn do_close(client: Client) -> Result(Nil, ConnectionError)

/// Check if the client connection is currently active.
pub fn is_connected(client: Client) -> Bool {
  do_is_process_alive(client)
}

@external(erlang, "carotte_ffi", "is_process_alive")
fn do_is_process_alive(client: Client) -> Bool

/// Get the current connection state.
pub fn connection_state(client: Client) -> ConnectionState {
  case is_connected(client) {
    True -> Connected
    False -> Disconnected(reason: ConnectionProcessNotAlive)
  }
}

/// Attempt to reconnect a disconnected client.
/// Uses the original connection parameters.
/// Returns error if already connected or reconnection fails.
pub fn reconnect(client: Client) -> Result(Client, ConnectionError) {
  case is_connected(client) {
    True -> Error(AlreadyConnected)
    False -> {
      let builder = client.config
      // Convert Duration to seconds for heartbeat
      let #(heartbeat_secs, heartbeat_nanoseconds) =
        duration.to_seconds_and_nanoseconds(builder.heartbeat)
      let heartbeat_secs = case heartbeat_nanoseconds > 0 {
        True -> heartbeat_secs + 1
        False -> heartbeat_secs
      }
      // Convert Duration to milliseconds for connection_timeout
      let #(timeout_secs, timeout_nanos) =
        duration.to_seconds_and_nanoseconds(builder.connection_timeout)
      let timeout_ms = timeout_secs * 1000 + timeout_nanos / 1_000_000

      case
        do_start(
          builder.username,
          builder.password,
          builder.virtual_host,
          builder.host,
          builder.port,
          builder.channel_max,
          builder.frame_max,
          heartbeat_secs,
          timeout_ms,
        )
      {
        Ok(pid) -> Ok(Client(pid:, config: builder))
        Error(e) -> Error(ReconnectionFailed(e))
      }
    }
  }
}

/// Convert a ConnectionError to a human-readable string description.
/// Useful for logging or displaying error messages to users.
pub fn describe_connection_error(err: ConnectionError) -> String {
  case err {
    ConnectionBlocked -> "Connection blocked"
    ConnectionClosed -> "Connection closed"
    ConnectionAuthFailure(msg) -> "Auth failure: " <> msg
    ConnectionRefused(msg) -> "Connection refused: " <> msg
    ConnectionTimeout(msg) -> "Connection timeout: " <> msg
    NotConnected -> "Not connected"
    ReconnectionFailed(cause) ->
      "Reconnection failed: " <> describe_connection_error(cause)
    AlreadyConnected -> "Already connected"
    ConnectionUnknownError(msg) -> "Unknown error: " <> msg
  }
}

/// Convert a ChannelError to a human-readable string description.
pub fn describe_channel_error(err: ChannelError) -> String {
  case err {
    ChannelClosed(msg) -> "Channel closed: " <> msg
    ChannelProcessNotFound -> "Channel process not found"
    ChannelConnectionClosed -> "Connection closed"
    ChannelUnknownError(msg) -> "Unknown error: " <> msg
  }
}

/// Convert an ExchangeError to a human-readable string description.
pub fn describe_exchange_error(err: ExchangeError) -> String {
  case err {
    ExchangeNotFound(msg) -> "Exchange not found: " <> msg
    ExchangeAccessRefused(msg) -> "Access refused: " <> msg
    ExchangePreconditionFailed(msg) -> "Precondition failed: " <> msg
    ExchangeChannelClosed(msg) -> "Channel closed: " <> msg
    ExchangeUnknownError(msg) -> "Unknown error: " <> msg
  }
}

/// Convert a QueueError to a human-readable string description.
pub fn describe_queue_error(err: QueueError) -> String {
  case err {
    QueueNotFound(msg) -> "Queue not found: " <> msg
    QueueAccessRefused(msg) -> "Access refused: " <> msg
    QueuePreconditionFailed(msg) -> "Precondition failed: " <> msg
    QueueResourceLocked(msg) -> "Resource locked: " <> msg
    QueueChannelClosed(msg) -> "Channel closed: " <> msg
    QueueUnknownError(msg) -> "Unknown error: " <> msg
  }
}

/// Convert a PublishError to a human-readable string description.
pub fn describe_publish_error(err: PublishError) -> String {
  case err {
    PublishNoRoute(msg) -> "No route: " <> msg
    PublishChannelClosed(msg) -> "Channel closed: " <> msg
    PublishUnknownError(msg) -> "Unknown error: " <> msg
  }
}

/// Convert a ConsumeError to a human-readable string description.
pub fn describe_consume_error(err: ConsumeError) -> String {
  case err {
    ConsumeInitTimeout -> "Consumer init timeout"
    ConsumeInitFailed(msg) -> "Consumer init failed: " <> msg
    ConsumeProcessNotFound -> "Consumer process not found"
    ConsumeChannelClosed(msg) -> "Channel closed: " <> msg
    ConsumeUnknownError(msg) -> "Unknown error: " <> msg
  }
}

// =============================================================================
// CHANNEL FUNCTIONS
// =============================================================================

/// Open a channel to a RabbitMQ server.
pub fn open_channel(client: Client) -> Result(Channel, ChannelError) {
  do_open_channel(client)
}

@external(erlang, "carotte_ffi", "open_channel")
fn do_open_channel(carotte_client: Client) -> Result(Channel, ChannelError)

// =============================================================================
// EXCHANGE FUNCTIONS
// =============================================================================

/// Create an exchange with the given name and sensible defaults.
/// Returns a Direct exchange with all options set to False.
///
/// To customize, use record update syntax:
/// ```gleam
/// Exchange(..exchange("events"), exchange_type: Topic, durable: True)
/// ```
pub fn exchange(name: String) -> Exchange {
  Exchange(
    name:,
    exchange_type: Direct,
    durable: False,
    auto_delete: False,
    internal: False,
    nowait: False,
  )
}

/// Declare an exchange on the broker.
pub fn declare_exchange(
  exchange: Exchange,
  channel: Channel,
) -> Result(Nil, ExchangeError) {
  do_declare_exchange(channel, exchange)
}

/// Declare an exchange on the broker without waiting for a response.
pub fn declare_exchange_async(
  exchange: Exchange,
  channel: Channel,
) -> Result(Nil, ExchangeError) {
  do_declare_exchange(channel, Exchange(..exchange, nowait: True))
}

@external(erlang, "carotte_ffi", "exchange_declare")
fn do_declare_exchange(
  channel: Channel,
  exchange: Exchange,
) -> Result(Nil, ExchangeError)

/// Delete an exchange from the broker.
/// If `unused` is set to true, the exchange will only be deleted if it has no queues bound to it.
pub fn delete_exchange(
  channel channel: Channel,
  exchange exchange: String,
  if_unused unused: Bool,
) -> Result(Nil, ExchangeError) {
  do_delete_exchange(channel, exchange, unused, False)
}

/// Delete an exchange from the broker without waiting for a response.
pub fn delete_exchange_async(
  channel channel: Channel,
  exchange exchange: String,
  if_unused unused: Bool,
) -> Result(Nil, ExchangeError) {
  do_delete_exchange(channel, exchange, unused, True)
}

@external(erlang, "carotte_ffi", "exchange_delete")
fn do_delete_exchange(
  channel: Channel,
  exchange: String,
  if_unused: Bool,
  nowait: Bool,
) -> Result(Nil, ExchangeError)

/// Bind an exchange to another exchange.
/// Routing keys are used to filter messages from the source exchange.
pub fn bind_exchange(
  channel channel: Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, ExchangeError) {
  do_bind_exchange(channel, source, destination, routing_key, False)
}

/// Bind an exchange to another exchange without waiting for a response.
/// Same semantics as `bind_exchange`.
pub fn bind_exchange_async(
  channel channel: Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, ExchangeError) {
  do_bind_exchange(channel, source, destination, routing_key, True)
}

@external(erlang, "carotte_ffi", "exchange_bind")
fn do_bind_exchange(
  channel: Channel,
  source: String,
  destination: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, ExchangeError)

/// Unbind an exchange from another exchange.
pub fn unbind_exchange(
  channel channel: Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, ExchangeError) {
  do_unbind_exchange(channel, source, destination, routing_key, False)
}

/// Unbind an exchange from another exchange asynchronously.
/// Same semantics as `unbind_exchange`.
pub fn unbind_exchange_async(
  channel channel: Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, ExchangeError) {
  do_unbind_exchange(channel, source, destination, routing_key, True)
}

@external(erlang, "carotte_ffi", "exchange_unbind")
fn do_unbind_exchange(
  channel: Channel,
  source: String,
  destination: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, ExchangeError)

// =============================================================================
// QUEUE FUNCTIONS
// =============================================================================

/// Create a queue configuration with the given name and sensible defaults.
/// All boolean options default to False.
///
/// To customize, use record update syntax:
/// ```gleam
/// QueueConfig(..queue("my_queue"), durable: True, exclusive: True)
/// ```
///
/// For an auto-generated queue name, pass an empty string:
/// ```gleam
/// queue("")
/// |> declare_queue(channel)
/// // Returns Queue with broker-generated name like "amq.gen-..."
/// ```
pub fn queue(name: String) -> QueueConfig {
  QueueConfig(
    name:,
    passive: False,
    durable: False,
    exclusive: False,
    auto_delete: False,
    nowait: False,
  )
}

/// Declare a queue on the broker.
pub fn declare_queue(
  queue: QueueConfig,
  channel: Channel,
) -> Result(Queue, QueueError) {
  do_declare_queue(
    channel,
    queue.name,
    queue.passive,
    queue.durable,
    queue.exclusive,
    queue.auto_delete,
    queue.nowait,
  )
}

@external(erlang, "carotte_ffi", "queue_declare")
fn do_declare_queue(
  channel: Channel,
  queue: String,
  passive: Bool,
  durable: Bool,
  exclusive: Bool,
  auto_delete: Bool,
  nowait: Bool,
) -> Result(Queue, QueueError)

/// Declare a queue on the broker asynchronously.
pub fn declare_queue_async(
  queue: QueueConfig,
  channel: Channel,
) -> Result(Nil, QueueError) {
  do_declare_queue_async(
    channel,
    queue.name,
    queue.passive,
    queue.durable,
    queue.exclusive,
    queue.auto_delete,
    True,
  )
}

@external(erlang, "carotte_ffi", "queue_declare")
fn do_declare_queue_async(
  channel: Channel,
  queue: String,
  passive: Bool,
  durable: Bool,
  exclusive: Bool,
  auto_delete: Bool,
  nowait: Bool,
) -> Result(Nil, QueueError)

/// Delete a queue from the broker.
/// If `if_unused` is set, the queue will only be deleted if it has no subscribers.
/// If `if_empty` is set, the queue will only be deleted if it has no messages.
/// Returns the number of messages that were in the queue when it was deleted.
pub fn delete_queue(
  channel channel: Channel,
  queue queue: String,
  if_unused if_unused: Bool,
  if_empty if_empty: Bool,
) -> Result(Int, QueueError) {
  do_delete_queue(channel, queue, if_unused, if_empty, False)
}

/// Delete a queue from the broker asynchronously.
/// Same semantics as `delete_queue`.
pub fn delete_queue_async(
  channel channel: Channel,
  queue queue: String,
  if_unused if_unused: Bool,
  if_empty if_empty: Bool,
) -> Result(Nil, QueueError) {
  use _ <- result.map(do_delete_queue(channel, queue, if_unused, if_empty, True))
  Nil
}

@external(erlang, "carotte_ffi", "queue_delete")
fn do_delete_queue(
  channel: Channel,
  queue: String,
  if_unused: Bool,
  if_empty: Bool,
  nowait: Bool,
) -> Result(Int, QueueError)

/// Bind a queue to an exchange.
/// The `routing_key` is used to filter messages from the exchange.
pub fn bind_queue(
  channel channel: Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, QueueError) {
  do_bind_queue(channel, queue, exchange, routing_key, False)
}

/// Bind a queue to an exchange asynchronously.
/// Same semantics as `bind_queue`.
pub fn bind_queue_async(
  channel channel: Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, QueueError) {
  do_bind_queue(channel, queue, exchange, routing_key, True)
}

@external(erlang, "carotte_ffi", "queue_bind")
fn do_bind_queue(
  channel: Channel,
  queue: String,
  exchange: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, QueueError)

/// Unbind a queue from an exchange.
/// The `routing_key` is used to filter messages from the exchange.
pub fn unbind_queue(
  channel channel: Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, QueueError) {
  do_unbind_queue(channel, queue, exchange, routing_key)
}

@external(erlang, "carotte_ffi", "queue_unbind")
fn do_unbind_queue(
  channel: Channel,
  queue: String,
  exchange: String,
  routing_key: String,
) -> Result(Nil, QueueError)

/// Purge a queue of all messages.
pub fn purge_queue(
  channel channel: Channel,
  queue queue: String,
) -> Result(Int, QueueError) {
  do_purge_queue(channel, queue, False)
}

/// Purge a queue of all messages asynchronously.
pub fn purge_queue_async(
  channel channel: Channel,
  queue queue: String,
) -> Result(Nil, QueueError) {
  use _ <- result.map(do_purge_queue(channel, queue, True))
  Nil
}

@external(erlang, "carotte_ffi", "queue_purge")
fn do_purge_queue(
  channel: Channel,
  queue: String,
  nowait: Bool,
) -> Result(Int, QueueError)

/// Get the status of a queue.
pub fn queue_status(
  channel channel: Channel,
  queue queue: String,
) -> Result(Queue, QueueError) {
  do_declare_queue(channel, queue, True, False, False, False, False)
}

// =============================================================================
// PUBLISHER FUNCTIONS
// =============================================================================

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
/// case carotte.subscribe(supervisor, channel, "my_queue", fn(payload, _deliver) {
///   let headers = carotte.headers_to_list(payload.headers)
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
  let array_decoder = decode.list(decode.dynamic)

  use items <- result.try(
    decode.run(value, array_decoder)
    |> result.replace_error(Nil),
  )

  items
  |> list.try_map(fn(item) {
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

/// Publish a message to an exchange.
/// The `routing_key` is used to route messages to queues.
/// The `options` are used to set message properties.
pub fn publish(
  channel channel: Channel,
  exchange exchange: String,
  routing_key routing_key: String,
  payload payload: String,
  options options: List(PublishOption),
) -> Result(Nil, PublishError) {
  let ffi_options = list.map(options, convert_publish_option_for_ffi)
  do_publish(channel, exchange, routing_key, payload, ffi_options)
}

/// Internal type for FFI - expiration is a string (AMQP protocol requirement).
type PublishOptionFfi {
  MandatoryFfi(Bool)
  ContentTypeFfi(String)
  ContentEncodingFfi(String)
  MessageHeadersFfi(HeaderList)
  PersistentFfi(Bool)
  CorrelationIdFfi(String)
  PriorityFfi(Int)
  ReplyToFfi(String)
  ExpirationFfi(String)
  MessageIdFfi(String)
  TimestampFfi(Int)
  TypeFfi(String)
  UserIdFfi(String)
  AppIdFfi(String)
}

fn convert_publish_option_for_ffi(option: PublishOption) -> PublishOptionFfi {
  case option {
    Mandatory(v) -> MandatoryFfi(v)
    ContentType(v) -> ContentTypeFfi(v)
    ContentEncoding(v) -> ContentEncodingFfi(v)
    MessageHeaders(v) -> MessageHeadersFfi(v)
    Persistent(v) -> PersistentFfi(v)
    CorrelationId(v) -> CorrelationIdFfi(v)
    Priority(v) -> PriorityFfi(v)
    ReplyTo(v) -> ReplyToFfi(v)
    Expiration(dur) -> {
      let #(seconds, nanos) = duration.to_seconds_and_nanoseconds(dur)
      let millis = seconds * 1000 + nanos / 1_000_000
      ExpirationFfi(int.to_string(millis))
    }
    MessageId(v) -> MessageIdFfi(v)
    Timestamp(ts) -> {
      let #(epoch_secs, _) = timestamp.to_unix_seconds_and_nanoseconds(ts)
      TimestampFfi(epoch_secs)
    }
    Type(v) -> TypeFfi(v)
    UserId(v) -> UserIdFfi(v)
    AppId(v) -> AppIdFfi(v)
  }
}

@external(erlang, "carotte_ffi", "publish")
fn do_publish(
  channel: Channel,
  exchange: String,
  routing_key: String,
  payload: String,
  publish_options: List(PublishOptionFfi),
) -> Result(Nil, PublishError)

// =============================================================================
// CONSUMER SUPERVISOR FUNCTIONS
// =============================================================================

/// The message type for the consumer supervisor.
/// Used when registering with a name.
pub type ConsumerSupervisorMessage =
  factory_supervisor.Message(ConsumerConfig, String)

/// Start the consumer supervisor directly without adding it to a supervision tree.
///
/// Most of the time you want to use `consumer_supervised` and add the
/// supervisor to your application's supervision tree instead of using this
/// function directly.
///
/// The supervisor will be linked to the calling process and registered with
/// the given name.
///
/// ## Example
///
/// ```gleam
/// let name = process.new_name("my_consumers")
/// let assert Ok(consumer) = carotte.start_consumer(name)
/// ```
pub fn start_consumer(
  name: process.Name(ConsumerSupervisorMessage),
) -> Result(Consumer, actor.StartError) {
  factory_supervisor.worker_child(start_consumer_actor)
  |> factory_supervisor.named(name)
  |> factory_supervisor.start
  |> result.map(fn(_) { Consumer(name) })
}

/// Create a child specification for adding the consumer supervisor to your
/// application's supervision tree.
///
/// This is the recommended way to start the consumer supervisor, as it ensures
/// proper lifecycle management within your OTP application.
///
/// You must provide a name so that other parts of your application can
/// find the supervisor to subscribe consumers.
///
/// ## Example
///
/// ```gleam
/// import gleam/erlang/process
/// import gleam/otp/static_supervisor
///
/// pub fn start_app() {
///   // Create a name at program startup
///   let consumers_name = process.new_name("consumers")
///
///   // Create the child specification (max 5 restarts in 10 seconds)
///   let consumer_spec = carotte.consumer_supervised(consumers_name)
///
///   // Add to your supervision tree
///   static_supervisor.new(static_supervisor.OneForOne)
///   |> static_supervisor.add(consumer_spec)
///   |> static_supervisor.start()
///
///   // Later, get the supervisor to subscribe
///   let sup = carotte.named_consumer(consumers_name)
///   carotte.subscribe(sup, channel: ch, queue: "my_queue", callback: handler)
/// }
/// ```
pub fn consumer_supervised(
  name: process.Name(ConsumerSupervisorMessage),
) -> supervision.ChildSpecification(
  factory_supervisor.Supervisor(ConsumerConfig, String),
) {
  factory_supervisor.worker_child(start_consumer_actor)
  |> factory_supervisor.named(name)
  |> factory_supervisor.supervised
}

/// Get a reference to a running consumer supervisor by its registered name.
///
/// Use this to get a supervisor reference after it has been started as part
/// of your supervision tree via `consumer_supervised`.
///
/// ## Example
///
/// ```gleam
/// let consumer = carotte.named_consumer(consumers_name)
/// ```
pub fn named_consumer(name: process.Name(ConsumerSupervisorMessage)) -> Consumer {
  Consumer(name)
}

/// Start a consumer under supervision.
/// Returns the consumer_tag string which can be used to unsubscribe later.
pub fn subscribe(
  consumer: Consumer,
  channel channel: Channel,
  queue queue: String,
  callback callback: fn(Payload, Deliver) -> Nil,
) -> Result(String, ConsumeError) {
  let Consumer(name) = consumer
  let config = ConsumerConfig(channel:, queue:, auto_ack: True, callback:)
  let supervisor = factory_supervisor.get_by_name(name)

  factory_supervisor.start_child(supervisor, config)
  |> result.map(fn(started) { started.data })
  |> result.map_error(fn(e) {
    case e {
      actor.InitTimeout -> ConsumeInitTimeout
      actor.InitFailed(msg) -> ConsumeInitFailed(msg)
      actor.InitExited(_) -> ConsumeInitFailed("Consumer init exited")
    }
  })
}

/// Start a consumer with options under supervision.
/// Returns the consumer_tag string which can be used to unsubscribe later.
pub fn subscribe_with_options(
  consumer: Consumer,
  channel channel: Channel,
  queue queue: String,
  options options: List(QueueOption),
  callback callback: fn(Payload, Deliver) -> Nil,
) -> Result(String, ConsumeError) {
  let Consumer(name) = consumer
  let auto_ack = case options {
    [] -> True
    [AutoAck(ack), ..] -> ack
  }
  let config = ConsumerConfig(channel:, queue:, auto_ack:, callback:)
  let supervisor = factory_supervisor.get_by_name(name)

  factory_supervisor.start_child(supervisor, config)
  |> result.map(fn(started) { started.data })
  |> result.map_error(fn(e) {
    case e {
      actor.InitTimeout -> ConsumeInitTimeout
      actor.InitFailed(msg) -> ConsumeInitFailed(msg)
      actor.InitExited(_) -> ConsumeInitFailed("Consumer init exited")
    }
  })
}

/// Unsubscribe and stop a consumer gracefully.
pub fn unsubscribe(
  channel channel: Channel,
  consumer_tag consumer_tag: String,
) -> Result(Nil, ConsumeError) {
  do_unsubscribe(channel, consumer_tag, False)
}

/// Unsubscribe a consumer asynchronously.
pub fn unsubscribe_async(
  channel channel: Channel,
  consumer_tag consumer_tag: String,
) -> Result(Nil, ConsumeError) {
  do_unsubscribe(channel, consumer_tag, True)
}

@external(erlang, "carotte_ffi", "unsubscribe")
fn do_unsubscribe(
  channel: Channel,
  consumer_tag: String,
  nowait: Bool,
) -> Result(Nil, ConsumeError)

/// Acknowledge a message delivery.
/// Used when manual acknowledgment is enabled (AutoAck(False)).
///
/// ## Parameters
/// - `channel`: The channel to acknowledge on
/// - `delivery_tag`: The delivery tag from the message metadata
/// - `multiple`: If True, acknowledges all messages up to and including this delivery tag
///
/// ## Example
/// ```gleam
/// carotte.subscribe_with_options(
///   supervisor,
///   channel: ch,
///   queue: "my_queue",
///   options: [carotte.AutoAck(False)],
///   callback: fn(msg, meta) {
///     // Process message
///     let _ = carotte.ack(ch, meta.delivery_tag, False)
///   },
/// )
/// ```
pub fn ack(
  channel: Channel,
  delivery_tag: Int,
  multiple: Bool,
) -> Result(Nil, ConsumeError) {
  do_basic_ack(channel, delivery_tag, multiple)
}

/// Acknowledge a message delivery (acknowledges only this message).
/// Convenience function for ack with multiple=False.
pub fn ack_single(
  channel: Channel,
  delivery_tag: Int,
) -> Result(Nil, ConsumeError) {
  do_basic_ack(channel, delivery_tag, False)
}

@external(erlang, "carotte_ffi", "ack")
fn do_basic_ack(
  channel: Channel,
  delivery_tag: Int,
  multiple: Bool,
) -> Result(Nil, ConsumeError)

/// Negatively acknowledge a message delivery.
/// Used when manual acknowledgment is enabled (AutoAck(False)) and you want
/// to indicate that the message could not be processed.
///
/// ## Parameters
/// - `channel`: The channel to nack on
/// - `delivery_tag`: The delivery tag from the message metadata
/// - `multiple`: If True, nacks all messages up to and including this delivery tag
/// - `requeue`: If True, the message(s) will be requeued; if False, they will be
///   discarded or dead-lettered (if a dead letter exchange is configured)
///
/// ## Example
/// ```gleam
/// carotte.subscribe_with_options(
///   consumer,
///   channel: ch,
///   queue: "my_queue",
///   options: [carotte.AutoAck(False)],
///   callback: fn(msg, meta) {
///     case process_message(msg) {
///       Ok(_) -> carotte.ack_single(ch, meta.delivery_tag)
///       Error(_) -> carotte.nack(ch, meta.delivery_tag, False, True)  // Requeue for retry
///     }
///   },
/// )
/// ```
pub fn nack(
  channel: Channel,
  delivery_tag: Int,
  multiple: Bool,
  requeue: Bool,
) -> Result(Nil, ConsumeError) {
  do_basic_nack(channel, delivery_tag, multiple, requeue)
}

/// Negatively acknowledge a single message.
/// Convenience function for nack with multiple=False.
///
/// ## Parameters
/// - `channel`: The channel to nack on
/// - `delivery_tag`: The delivery tag from the message metadata
/// - `requeue`: If True, the message will be requeued; if False, it will be
///   discarded or dead-lettered
pub fn nack_single(
  channel: Channel,
  delivery_tag: Int,
  requeue: Bool,
) -> Result(Nil, ConsumeError) {
  do_basic_nack(channel, delivery_tag, False, requeue)
}

@external(erlang, "carotte_ffi", "nack")
fn do_basic_nack(
  channel: Channel,
  delivery_tag: Int,
  multiple: Bool,
  requeue: Bool,
) -> Result(Nil, ConsumeError)

/// Reject a message delivery.
/// Similar to nack but only works with a single message (no multiple option).
/// This is the original AMQP 0-9-1 method for rejecting messages.
///
/// ## Parameters
/// - `channel`: The channel to reject on
/// - `delivery_tag`: The delivery tag from the message metadata
/// - `requeue`: If True, the message will be requeued; if False, it will be
///   discarded or dead-lettered (if a dead letter exchange is configured)
///
/// ## Example
/// ```gleam
/// carotte.subscribe_with_options(
///   consumer,
///   channel: ch,
///   queue: "my_queue",
///   options: [carotte.AutoAck(False)],
///   callback: fn(msg, meta) {
///     case validate_message(msg) {
///       Ok(_) -> carotte.ack_single(ch, meta.delivery_tag)
///       Error(_) -> carotte.reject(ch, meta.delivery_tag, False)  // Discard invalid message
///     }
///   },
/// )
/// ```
pub fn reject(
  channel: Channel,
  delivery_tag: Int,
  requeue: Bool,
) -> Result(Nil, ConsumeError) {
  do_basic_reject(channel, delivery_tag, requeue)
}

@external(erlang, "carotte_ffi", "reject")
fn do_basic_reject(
  channel: Channel,
  delivery_tag: Int,
  requeue: Bool,
) -> Result(Nil, ConsumeError)

// =============================================================================
// CONSUMER ACTOR (INTERNAL)
// =============================================================================

type ConsumerState {
  ConsumerState(
    channel: Channel,
    consumer_tag: String,
    callback: fn(Payload, Deliver) -> Nil,
    auto_ack: Bool,
  )
}

type ConsumerMessage {
  AmqpDelivery(Payload, Deliver)
  AmqpCancelled
  Shutdown
}

fn start_consumer_actor(
  config: ConsumerConfig,
) -> Result(actor.Started(String), actor.StartError) {
  actor.new_with_initialiser(5000, fn(_self_subject) {
    // Subscribe to the AMQP queue
    let consumer_pid = process.self()
    case
      do_consume_ffi(
        config.channel,
        config.queue,
        consumer_pid,
        config.auto_ack,
      )
    {
      Ok(consumer_tag) -> {
        // Wait for basic.consume_ok
        let _ =
          process.new_selector()
          |> process.select_record(atom.create("basic.consume_ok"), 1, fn(_) {
            Nil
          })
          |> process.selector_receive(1000)

        let state =
          ConsumerState(
            channel: config.channel,
            consumer_tag:,
            callback: config.callback,
            auto_ack: config.auto_ack,
          )

        let selector = build_consumer_selector()

        Ok(
          actor.initialised(state)
          |> actor.selecting(selector)
          |> actor.returning(consumer_tag),
        )
      }
      Error(_) -> Error("Failed to subscribe to queue")
    }
  })
  |> actor.on_message(handle_consumer_message)
  |> actor.start
}

fn build_consumer_selector() -> process.Selector(ConsumerMessage) {
  process.new_selector()
  |> process.select_record(atom.create("basic.cancel"), 2, fn(_) {
    AmqpCancelled
  })
  |> process.select_record(atom.create("basic.cancel_ok"), 1, fn(_) {
    AmqpCancelled
  })
  |> process.select_other(fn(delivery_dyn) {
    let basic_deliver_decoder = {
      use consumer_tag <- decode.subfield([0, 1], decode.string)
      use delivery_tag <- decode.subfield([0, 2], decode.int)
      use redelivered <- decode.subfield([0, 3], decode.bool)
      use exchange <- decode.subfield([0, 4], decode.string)
      use routing_key <- decode.subfield([0, 5], decode.string)
      decode.success(Deliver(
        consumer_tag,
        delivery_tag,
        redelivered,
        exchange,
        routing_key,
      ))
    }

    let payload_properties_decoder = {
      let properties = []
      use content_type <- decode.subfield([1], decode.optional(decode.string))
      let properties = add_if_some(properties, ContentType, content_type)

      use content_encoding <- decode.subfield(
        [2],
        decode.optional(decode.string),
      )
      let properties =
        add_if_some(properties, ContentEncoding, content_encoding)

      use delivery_mode <- decode.subfield([4], decode.optional(decode.int))
      let properties =
        add_if_some(properties, Persistent, case delivery_mode {
          Some(2) -> Some(True)
          Some(1) -> Some(False)
          _ -> None
        })

      use priority <- decode.subfield([5], decode.optional(decode.int))
      let properties = add_if_some(properties, Priority, priority)

      use correlation_id <- decode.subfield([6], decode.optional(decode.string))
      let properties = add_if_some(properties, CorrelationId, correlation_id)

      use reply_to <- decode.subfield([7], decode.optional(decode.string))
      let properties = add_if_some(properties, ReplyTo, reply_to)

      use expiration_str <- decode.subfield([8], decode.optional(decode.string))
      let expiration_duration = case expiration_str {
        Some(s) ->
          case int.parse(s) {
            Ok(ms) -> Some(duration.milliseconds(ms))
            Error(_) -> None
          }
        None -> None
      }
      let properties = add_if_some(properties, Expiration, expiration_duration)

      use message_id <- decode.subfield([9], decode.optional(decode.string))
      let properties = add_if_some(properties, MessageId, message_id)

      use timestamp_secs <- decode.subfield([10], decode.optional(decode.int))
      let timestamp_value = case timestamp_secs {
        Some(secs) -> Some(timestamp.from_unix_seconds(secs))
        None -> None
      }
      let properties = add_if_some(properties, Timestamp, timestamp_value)

      use message_type <- decode.subfield([11], decode.optional(decode.string))
      let properties = add_if_some(properties, Type, message_type)

      use user_id <- decode.subfield([12], decode.optional(decode.string))
      let properties = add_if_some(properties, UserId, user_id)

      use app_id <- decode.subfield([13], decode.optional(decode.string))
      let properties = add_if_some(properties, AppId, app_id)

      decode.success(properties)
    }

    let payload_decoder = {
      use properties <- decode.subfield([1, 1], payload_properties_decoder)
      use payload <- decode.subfield([1, 2], decode.string)
      use raw_headers <- decode.subfield([1, 1, 3], decode.dynamic)
      let headers = parse_amqp_headers(raw_headers)
      decode.success(Payload(payload, properties, headers))
    }

    let assert Ok(basic_deliver) =
      decode.run(delivery_dyn, basic_deliver_decoder)
    let assert Ok(payload) = decode.run(delivery_dyn, payload_decoder)

    AmqpDelivery(payload, basic_deliver)
  })
}

fn handle_consumer_message(
  state: ConsumerState,
  message: ConsumerMessage,
) -> actor.Next(ConsumerState, ConsumerMessage) {
  case message {
    AmqpDelivery(payload, deliver) -> {
      // Call the user's callback
      state.callback(payload, deliver)
      actor.continue(state)
    }
    AmqpCancelled -> actor.stop()
    Shutdown -> actor.stop()
  }
}

@external(erlang, "carotte_ffi", "consume")
fn do_consume_ffi(
  channel: Channel,
  queue: String,
  pid: Pid,
  no_ack: Bool,
) -> Result(String, ConsumeError)

@external(erlang, "carotte_ffi", "parse_amqp_headers")
fn parse_amqp_headers(headers: decode.Dynamic) -> HeaderList

fn add_if_some(list, constructor, value) {
  case value {
    Some(v) -> [constructor(v), ..list]
    None -> list
  }
}
