import carotte
import gleam/erlang/process.{type Pid}

pub type Channel {
  Channel(pid: Pid)
}

/// Open a channel to a RabbitMQ server
pub fn open_channel(client: carotte.Client) {
  do_open_channel(client.name)
}

@external(erlang, "carotte_ffi", "open_channel")
fn do_open_channel(
  carotte_client: process.Name(carotte.Message),
) -> Result(Channel, carotte.CarotteError)
