import carotte
import gleam/erlang/process.{type Pid}

pub type Channel {
  Channel(pid: Pid)
}

/// Open a channel to a RabbitMQ server
pub fn open_channel(candy_client: carotte.CarotteClient) {
  do_open_channel(candy_client)
}

@external(erlang, "carrot_ffi", "open_channel")
fn do_open_channel(
  candy_client: carotte.CarotteClient,
) -> Result(Channel, carotte.CarotteError)
