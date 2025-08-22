import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result

pub opaque type Client {
  Client(process.Pid)
}

pub type CarotteError {
  Blocked
  Closed
  AuthFailure(String)
  ProcessNotFound
  AlreadyRegistered(String)
  NotFound(String)
  AccessRefused(String)
  PreconditionFailed(String)
  ResourceLocked(String)
  ChannelClosed(String)
  ConnectionRefused(String)
  ConnectionTimeout(String)
  FrameError(String)
  InternalError(String)
  InvalidPath(String)
  NoRoute(String)
  NotAllowed(String)
  NotImplemented(String)
  UnexpectedFrame(String)
  CommandInvalid(String)
  UnknownError(String)
}

pub opaque type Builder {
  Builder(
    name: process.Name(Message),
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

/// Message type used for the client process
pub type Message

/// Create a new client builder with default settings.
/// Uses guest/guest credentials on localhost:5672.
/// 
/// ## Example
/// ```gleam
/// let client = carotte.default_client(process.new_name("my_client"))
///   |> carotte.start()
/// ```
pub fn default_client(name name: process.Name(Message)) -> Builder {
  Builder(
    name: name,
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
    builder.name,
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
  name: process.Name(Message),
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
