import carrot
import gleam/erlang/process.{type Pid}

pub type Channel {
  Channel(pid: Pid)
}

/// Open a channel to a RabbitMQ server
pub fn open_channel(candy_client: carrot.CarrotClient) {
  do_open_channel(candy_client)
}

@external(erlang, "carrot_ffi", "open_channel")
fn do_open_channel(
  candy_client: carrot.CarrotClient,
) -> Result(Channel, carrot.CarrotError)
