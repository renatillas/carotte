import carotte
import gleam/erlang/process.{type Pid}

pub type Channel {
  Channel(pid: Pid)
}

/// Open a channel to a RabbitMQ server
pub fn open_channel(carotte_client: carotte.Client) {
  do_open_channel(carotte_client)
}

@external(erlang, "carotte_ffi", "open_channel")
fn do_open_channel(
  carotte_client: carotte.Client,
) -> Result(Channel, carotte.CarotteError)
