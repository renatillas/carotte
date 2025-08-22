import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result

pub type Client {
  Client(name: process.Name(Message))
}

pub type CarotteError {
  Blocked
  Closed
  AuthFailure(String)
  ProcessNotFound
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

pub type Message

pub fn default_client(name name: process.Name(Message)) -> Builder {
  Builder(
    "guest",
    "guest",
    "/",
    "localhost",
    5672,
    2074,
    0,
    10,
    60_000,
    name: name,
  )
}

pub fn with_username(builder: Builder, username: String) -> Builder {
  Builder(..builder, username:)
}

pub fn with_password(builder: Builder, password: String) -> Builder {
  Builder(..builder, password:)
}

pub fn with_virtual_host(builder: Builder, virtual_host: String) -> Builder {
  Builder(..builder, virtual_host:)
}

pub fn with_host(builder: Builder, host: String) -> Builder {
  Builder(..builder, host:)
}

pub fn with_port(builder: Builder, port: Int) -> Builder {
  Builder(..builder, port:)
}

pub fn with_channel_max(builder: Builder, channel_max: Int) -> Builder {
  Builder(..builder, channel_max:)
}

pub fn with_frame_max(builder: Builder, frame_max: Int) -> Builder {
  Builder(..builder, frame_max:)
}

pub fn with_heartbeat(builder: Builder, heartbeat: Int) -> Builder {
  Builder(..builder, heartbeat:)
}

pub fn with_connection_timeout(
  builder: Builder,
  connection_timeout: Int,
) -> Builder {
  Builder(..builder, connection_timeout:)
}

pub fn start(builder: Builder) -> actor.StartResult(Client) {
  use pid <- result.try(
    do_start(
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
    )
    |> result.map_error(with: fn(carotte_error) {
      case carotte_error {
        Blocked -> actor.InitFailed("Blocked connection")
        Closed -> actor.InitFailed("Closed connection")
        AuthFailure(reason) -> actor.InitFailed("AuthFailure: " <> reason)
        ProcessNotFound -> actor.InitFailed("Process not found")
      }
    }),
  )
  Ok(actor.Started(pid, named_client(builder.name)))
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

pub fn close(client: Client) -> Result(Nil, CarotteError) {
  do_close(client)
}

@external(erlang, "carotte_ffi", "close")
fn do_close(client: Client) -> Result(Nil, CarotteError)

pub fn supervised(builder: Builder) -> supervision.ChildSpecification(Client) {
  supervision.worker(fn() { start(builder) })
}

pub fn named_client(name: process.Name(Message)) -> Client {
  Client(name)
}
