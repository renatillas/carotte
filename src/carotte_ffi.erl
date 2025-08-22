-module(carotte_ffi).

-export([start/9, close/1, open_channel/1, publish/5, consume/3, ack/3, unsubscribe/3,
         exchange_declare/2, exchange_delete/4, exchange_bind/5, exchange_unbind/5,
         queue_declare/7, queue_delete/5, queue_bind/5, queue_unbind/4, queue_purge/3,
         header_value_to_header_tuple/1]).

-record(carotte_client, {pid}).
-record(channel, {pid}).
-record(amqp_params_network,
        {username = <<"guest">>,
         password = <<"guest">>,
         virtual_host = <<"/">>,
         host = "localhost",
         port = undefined,
         channel_max = 2047,
         frame_max = 0,
         heartbeat = 10,
         connection_timeout = 60000,
         ssl_options = none,
         auth_mechanisms = [fun amqp_auth_mechanisms:plain/3, fun amqp_auth_mechanisms:amqplain/3],
         client_properties = [],
         socket_options = []}).

start(Username,
      Password,
      VirtualHost,
      Host,
      Port,
      ChannelMax,
      FrameMax,
      Heartbeat,
      ConnectionTimeout) ->
  case amqp_connection:start(#amqp_params_network{username = Username,
                                                  password = Password,
                                                  virtual_host = VirtualHost,
                                                  host = binary_to_list(Host),
                                                  port = Port,
                                                  channel_max = ChannelMax,
                                                  frame_max = FrameMax,
                                                  heartbeat = Heartbeat,
                                                  connection_timeout = ConnectionTimeout})
  of
    {ok, Pid} ->
      {ok, #carotte_client{pid = Pid}};
    {error, Error} ->
      case Error of
        {Err, Msg} ->
          {error, {Err, erlang:list_to_binary(Msg)}};
        _ -> {error, Error}
        end
  end.

open_channel(CarotteClient) ->
  case amqp_connection:open_channel(CarotteClient#carotte_client.pid) of
    {ok, Pid} ->
      {ok, #channel{pid = Pid}};
    {error, Error} ->
      {error, Error}
  end.

-record('exchange.declare',
        {ticket = 0,
         exchange,
         type = <<"direct">>,
         passive = false,
         durable = false,
         auto_delete = false,
         internal = false,
         nowait = false,
         arguments = []}).

exchange_declare(Channel,
                 {exchange, Name, Type, Durable, AutoDelete, Internal, Nowait}) ->
  Result =
    amqp_channel:call(Channel#channel.pid,
                      #'exchange.declare'{exchange = Name,
                                          type = atom_to_binary(Type),
                                          durable = Durable,
                                          auto_delete = AutoDelete,
                                          internal = Internal,
                                          nowait = Nowait,
                                          arguments = []}),
  case {Nowait, Result} of
    {true, ok} ->
      {ok, nil};
    {_, {'exchange.declare_ok'}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

-record('exchange.delete', {ticket = 0, exchange, if_unused = false, nowait = false}).

exchange_delete(Channel, Name, IfUnused, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'exchange.delete'{exchange = Name,
                                             if_unused = IfUnused,
                                             nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'exchange.delete_ok'}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

-record('exchange.bind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_bind(Channel, Source, Destination, RoutingKey, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'exchange.bind'{destination = Destination,
                                           source = Source,
                                           routing_key = RoutingKey,
                                           nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'exchange.bind_ok'}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

-record('exchange.unbind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_unbind(Channel, Source, Destination, RoutingKey, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'exchange.unbind'{destination = Destination,
                                             source = Source,
                                             routing_key = RoutingKey,
                                             nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'exchange.unbind_ok'}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

-record('queue.declare',
        {ticket = 0,
         queue = <<"">>,
         passive = false,
         durable = false,
         exclusive = false,
         auto_delete = false,
         nowait = false,
         arguments = []}).

queue_declare(Channel, Queue, Passive, Durable, Exclusive, AutoDelete, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'queue.declare'{queue = Queue,
                                           passive = Passive,
                                           durable = Durable,
                                           exclusive = Exclusive,
                                           auto_delete = AutoDelete,
                                           nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'queue.declare_ok', Queue, MessageCount, ConsumerCount}} ->
      {ok, {declared_queue, Queue, MessageCount, ConsumerCount}};
    {_, Error} ->
      {error, Error}
  end.

-record('queue.delete',
        {ticket = 0, queue = <<"">>, if_unused = false, if_empty = false, nowait = false}).

queue_delete(Channel, Queue, IfUnused, IfEmpty, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'queue.delete'{queue = Queue,
                                          if_unused = IfUnused,
                                          if_empty = IfEmpty,
                                          nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'queue.delete_ok', MessageCount}} ->
      {ok, MessageCount};
    {_, Error} ->
      {error, Error}
  end.

-record('queue.bind',
        {ticket = 0,
         queue = <<"">>,
         exchange,
         routing_key = <<"">>,
         nowait = false,
         arguments = []}).

queue_bind(Channel, Queue, Exchange, RoutingKey, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid,
                          #'queue.bind'{queue = Queue,
                                        exchange = Exchange,
                                        routing_key = RoutingKey,
                                        nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'queue.bind_ok'}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

-record('queue.unbind',
        {ticket = 0, queue = <<"">>, exchange, routing_key = <<"">>, arguments = []}).

queue_unbind(Channel, Queue, Exchange, RoutingKey) ->
  case amqp_channel:call(Channel#channel.pid,
                         #'queue.unbind'{queue = Queue,
                                         exchange = Exchange,
                                         routing_key = RoutingKey})
  of
    {'queue.unbind_ok'} ->
      {ok, nil};
    Error ->
      {error, Error}
  end.

-record('queue.purge', {ticket = 0, queue = <<"">>, nowait = false}).

queue_purge(Channel, Queue, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid, #'queue.purge'{queue = Queue, nowait = Nowait})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'queue.purge_ok', MessageCount}} ->
      {ok, MessageCount};
    {_, Error} ->
      {error, Error}
  end.

-record('basic.publish',
        {ticket = 0,
         exchange = <<"">>,
         routing_key = <<"">>,
         mandatory = false,
         immediate = false}).
-record('P_basic',
        {content_type,
         content_encoding,
         headers,
         delivery_mode,
         priority,
         correlation_id,
         reply_to,
         expiration,
         message_id,
         timestamp,
         type,
         user_id,
         app_id,
         cluster_id}).
-record(amqp_msg, {props = #'P_basic'{}, payload = <<>>}).

publish(Channel, Exchange, RoutingKey, Payload, Proplist) ->
  Headers =
    case proplists:get_value(headers, Proplist, undefined) of
      {header_list, HeaderList} ->
        HeaderList;
      _ ->
        undefined
    end,
  Props =
    #'P_basic'{content_type = proplists:get_value(content_type, Proplist, undefined),
               content_encoding = proplists:get_value(content_encoding, Proplist, undefined),
               headers = Headers,
               delivery_mode =
                 case proplists:get_value(persistent, Proplist, false) of
                   true ->
                     2;
                   false ->
                     1
                 end,
               priority = proplists:get_value(priority, Proplist, undefined),
               correlation_id = proplists:get_value(correlation_id, Proplist, undefined),
               reply_to = proplists:get_value(reply_to, Proplist, undefined),
               expiration = proplists:get_value(expiration, Proplist, undefined),
               message_id = proplists:get_value(message_id, Proplist, undefined),
               timestamp = proplists:get_value(timestamp, Proplist, undefined),
               type = proplists:get_value(type, Proplist, undefined),
               user_id = proplists:get_value(user_id, Proplist, undefined),
               app_id = proplists:get_value(app_id, Proplist, undefined),
               cluster_id = proplists:get_value(cluster_id, Proplist, undefined)},
  case amqp_channel:call(Channel#channel.pid,
                         #'basic.publish'{exchange = Exchange,
                                          routing_key = RoutingKey,
                                          mandatory =
                                            proplists:get_value(mandatory, Proplist, false),
                                          immediate =
                                            proplists:get_value(immediate, Proplist, false)},
                         #amqp_msg{props = Props, payload = Payload})
  of
    ok ->
      {ok, nil};
    Error ->
      {error, Error}
  end.

-record('basic.consume',
        {ticket = 0,
         queue = <<"">>,
         consumer_tag = <<"">>,
         no_local = false,
         no_ack = false,
         exclusive = false,
         nowait = false,
         arguments = []}).

consume(Channel, Queue, Pid) ->
  case amqp_channel:subscribe(Channel#channel.pid, #'basic.consume'{queue = Queue}, Pid) of
    {'basic.consume_ok', ConsumerTag_} ->
      {ok, ConsumerTag_};
    Error ->
      {error, Error}
  end.

-record('basic.ack', {delivery_tag = 0, multiple = false}).

ack(Channel, DeliveryTag, Multiple) ->
  case amqp_channel:call(Channel#channel.pid,
                         #'basic.ack'{delivery_tag = DeliveryTag, multiple = Multiple})
  of
    ok ->
      {ok, nil};
    Error ->
      {error, Error}
  end.

-record('basic.cancel', {consumer_tag, nowait = false}).

unsubscribe(Channel, ConsumerTag, Nowait) ->
  case {Nowait,
        amqp_channel:call(Channel#channel.pid, #'basic.cancel'{consumer_tag = ConsumerTag})}
  of
    {true, ok} ->
      {ok, nil};
    {_, {'basic.cancel_ok', _}} ->
      {ok, nil};
    {_, Error} ->
      {error, Error}
  end.

close(CarotteClient) ->
  amqp_connection:close(CarotteClient#carotte_client.pid).

header_value_to_header_tuple(Value) ->
  case Value of
    {bool_header, Inner} ->
      {bool, Inner};
    {float_header, Inner} ->
      {float, Inner};
    {int_header, Inner} ->
      {long, Inner};
    {string_header, Inner} ->
      {longstr, Inner};
    {list_header, Inner} ->
      {array,
       list:map(fun({ArrayValue}) -> {header_value_to_header_tuple(ArrayValue)} end, Inner)}
  end.
