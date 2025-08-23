import gleam/erlang/process
import gleam/result

/// Represents an active connection to a RabbitMQ server.
/// This is an opaque type that encapsulates the underlying AMQP client process.
/// Use the builder pattern with `default_client()` and `start()` to create a client.
pub opaque type Client {
  Client(process.Pid)
}

/// Errors that can occur when interacting with RabbitMQ.
pub type CarotteError {
  /// The connection is blocked by the server due to resource constraints
  Blocked
  /// The connection or channel has been closed
  Closed
  /// Authentication failed with the provided credentials
  AuthFailure(String)
  /// The specified process could not be found
  ProcessNotFound
  /// The resource is already registered with the given name
  AlreadyRegistered(String)
  /// The requested resource was not found
  NotFound(String)
  /// Access to the resource was refused
  AccessRefused(String)
  /// A precondition for the operation failed
  PreconditionFailed(String)
  /// The resource is locked and cannot be accessed
  ResourceLocked(String)
  /// The channel has been closed
  ChannelClosed(String)
  /// Connection to the server was refused
  ConnectionRefused(String)
  /// Connection attempt timed out
  ConnectionTimeout(String)
  /// An error occurred while processing AMQP frames
  FrameError(String)
  /// An internal server error occurred
  InternalError(String)
  /// The provided path is invalid
  InvalidPath(String)
  /// No route exists to the specified exchange or queue
  NoRoute(String)
  /// The requested operation is not allowed
  NotAllowed(String)
  /// The requested feature is not implemented
  NotImplemented(String)
  /// An unexpected frame was received
  UnexpectedFrame(String)
  /// The AMQP command is invalid
  CommandInvalid(String)
  /// An unknown error occurred
  UnknownError(String)
}

/// Configuration builder for creating a RabbitMQ client.
/// Use `default_client()` to create a builder with sensible defaults,
/// then chain the `with_*` functions to customize the configuration.
pub opaque type Builder {
  Builder(
    username: String,
    password: String,
    virtual_host: String,
    host: String,
    port: Int,
    channel_max: Int,
    frame_max: Int,
    heartbeat: Int,
    connection_timeout: Int,
  )
}

/// Create a new client builder with default settings.
/// Uses guest/guest credentials on localhost:5672.
/// 
/// ## Example
/// ```gleam
/// let client = carotte.default_client(process.new_name("my_client"))
///   |> carotte.start()
/// ```
pub fn default_client() -> Builder {
  Builder(
    username: "guest",
    password: "guest",
    virtual_host: "/",
    host: "localhost",
    port: 5672,
    channel_max: 2074,
    frame_max: 0,
    heartbeat: 10,
    connection_timeout: 60_000,
  )
}

/// Set the username for authentication
pub fn with_username(builder: Builder, username: String) -> Builder {
  Builder(..builder, username:)
}

/// Set the password for authentication
pub fn with_password(builder: Builder, password: String) -> Builder {
  Builder(..builder, password:)
}

/// Set the virtual host to connect to
pub fn with_virtual_host(builder: Builder, virtual_host: String) -> Builder {
  Builder(..builder, virtual_host:)
}

/// Set the hostname or IP address of the RabbitMQ server
pub fn with_host(builder: Builder, host: String) -> Builder {
  Builder(..builder, host:)
}

/// Set the port number for the RabbitMQ server (default: 5672)
pub fn with_port(builder: Builder, port: Int) -> Builder {
  Builder(..builder, port:)
}

/// Set the maximum number of channels (default: 2074)
pub fn with_channel_max(builder: Builder, channel_max: Int) -> Builder {
  Builder(..builder, channel_max:)
}

/// Set the maximum frame size in bytes (0 = no limit)
pub fn with_frame_max(builder: Builder, frame_max: Int) -> Builder {
  Builder(..builder, frame_max:)
}

/// Set the heartbeat interval in seconds (default: 10)
pub fn with_heartbeat(builder: Builder, heartbeat: Int) -> Builder {
  Builder(..builder, heartbeat:)
}

/// Set the connection timeout in milliseconds (default: 60000)
pub fn with_connection_timeout(
  builder: Builder,
  connection_timeout: Int,
) -> Builder {
  Builder(..builder, connection_timeout:)
}

/// Start a RabbitMQ client connection.
/// Returns an actor.StartResult which contains the client on success.
/// 
/// ## Example
/// ```gleam
/// case carotte.start(builder) {
///   Ok(client) -> // Use the client
///   Error(actor.InitFailed(msg)) -> // Handle connection error
/// }
/// ```
pub fn start(builder: Builder) -> Result(Client, CarotteError) {
  use pid <- result.map(do_start(
    builder.username,
    builder.password,
    builder.virtual_host,
    builder.host,
    builder.port,
    builder.channel_max,
    builder.frame_max,
    builder.heartbeat,
    builder.connection_timeout,
  ))
  Client(pid)
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
) -> Result(process.Pid, CarotteError)

/// Close the RabbitMQ client connection.
/// This will close all channels and the underlying AMQP connection.
pub fn close(client: Client) -> Result(Nil, CarotteError) {
  do_close(client)
}

@external(erlang, "carotte_ffi", "close")
fn do_close(client: Client) -> Result(Nil, CarotteError)
