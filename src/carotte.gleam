import gleam/erlang/process.{type Pid}

pub type CarotteClient {
  CarotteClient(pid: Pid)
}

pub type CarotteError {
  Blocked
  Closed
}

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

pub fn default_client() -> Builder {
  Builder("guest", "guest", "/", "localhost", 5672, 2074, 0, 10, 60_000)
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

pub fn start(builder: Builder) -> Result(CarotteClient, CarotteError) {
  do_start(
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
) -> Result(CarotteClient, CarotteError)

pub fn close(client: CarotteClient) -> Result(Nil, CarotteError) {
  do_close(client)
}

@external(erlang, "carotte_ffi", "close")
fn do_close(client: CarotteClient) -> Result(Nil, CarotteError)
