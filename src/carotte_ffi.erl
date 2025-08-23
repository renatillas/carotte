-module(carotte_ffi).

-export([start/9, close/1, open_channel/1, publish/5, consume/4, ack/3, unsubscribe/3,
         exchange_declare/2, exchange_delete/4, exchange_bind/5, exchange_unbind/5,
         queue_declare/7, queue_delete/5, queue_bind/5, queue_unbind/4, queue_purge/3,
         header_value_to_header_tuple/1]).

-record(client, {pid}).
-record(channel, {pid}).

% Convert various AMQP errors to Gleam-compatible format
convert_error({auth_failure, Message}) when is_list(Message) ->
  {error, {auth_failure, list_to_binary(Message)}};
convert_error({auth_failure, Message}) when is_binary(Message) ->
  {error, {auth_failure, Message}};
convert_error(auth_failure) ->
  {error, {auth_failure, <<"Authentication failed">>}};
convert_error(blocked) ->
  {error, blocked};
convert_error(closing) ->
  {error, closed};
convert_error(closed) ->
  {error, closed};
convert_error(noproc) ->
  {error, process_not_found};
convert_error({noproc, _}) ->
  {error, process_not_found};
convert_error(already_registered) ->
  {error, {already_registered, <<"Process name already registered">>}};
convert_error({already_registered, Message}) ->
  {error, {already_registered, Message}};
% Handle double-wrapped shutdown errors (from gen_server calls)
convert_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_error({shutdown, {server_initiated_close, Code, Message}});
% Handle shutdown errors with server initiated close using AMQP reply codes
convert_error({shutdown, {server_initiated_close, 312, Message}}) when is_list(Message) ->
  {error, {no_route, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 312, Message}})
  when is_binary(Message) ->
  {error, {no_route, Message}};
convert_error({shutdown, {server_initiated_close, 320, Message}}) when is_list(Message) ->
  {error, {connection_timeout, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 320, Message}})
  when is_binary(Message) ->
  {error, {connection_timeout, Message}};
convert_error({shutdown, {server_initiated_close, 403, Message}}) when is_list(Message) ->
  {error, {access_refused, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 403, Message}})
  when is_binary(Message) ->
  {error, {access_refused, Message}};
convert_error({shutdown, {server_initiated_close, 404, Message}}) when is_list(Message) ->
  {error, {not_found, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 404, Message}})
  when is_binary(Message) ->
  {error, {not_found, Message}};
convert_error({shutdown, {server_initiated_close, 405, Message}}) when is_list(Message) ->
  {error, {resource_locked, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 405, Message}})
  when is_binary(Message) ->
  {error, {resource_locked, Message}};
convert_error({shutdown, {server_initiated_close, 406, Message}}) when is_list(Message) ->
  {error, {precondition_failed, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 406, Message}})
  when is_binary(Message) ->
  {error, {precondition_failed, Message}};
convert_error({shutdown, {server_initiated_close, 501, Message}}) when is_list(Message) ->
  {error, {frame_error, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 501, Message}})
  when is_binary(Message) ->
  {error, {frame_error, Message}};
convert_error({shutdown, {server_initiated_close, 502, Message}}) when is_list(Message) ->
  {error, {command_invalid, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 502, Message}})
  when is_binary(Message) ->
  {error, {command_invalid, Message}};
convert_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {channel_closed, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 503, Message}})
  when is_binary(Message) ->
  {error, {channel_closed, Message}};
convert_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {channel_closed, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 504, Message}})
  when is_binary(Message) ->
  {error, {channel_closed, Message}};
convert_error({shutdown, {server_initiated_close, 505, Message}}) when is_list(Message) ->
  {error, {unexpected_frame, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 505, Message}})
  when is_binary(Message) ->
  {error, {unexpected_frame, Message}};
convert_error({shutdown, {server_initiated_close, 530, Message}}) when is_list(Message) ->
  {error, {not_allowed, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 530, Message}})
  when is_binary(Message) ->
  {error, {not_allowed, Message}};
convert_error({shutdown, {server_initiated_close, 540, Message}}) when is_list(Message) ->
  {error, {not_implemented, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 540, Message}})
  when is_binary(Message) ->
  {error, {not_implemented, Message}};
convert_error({shutdown, {server_initiated_close, 541, Message}}) when is_list(Message) ->
  {error, {internal_error, list_to_binary(Message)}};
convert_error({shutdown, {server_initiated_close, 541, Message}})
  when is_binary(Message) ->
  {error, {internal_error, Message}};
% Handle other shutdown errors
convert_error({shutdown, Reason}) ->
  convert_error(Reason);
convert_error({'EXIT', Reason}) ->
  convert_error(Reason);
convert_error({error, Reason}) ->
  convert_error(Reason);
% Handle AMQP specific errors
convert_error({amqp_error, not_found, Message}) when is_list(Message) ->
  {error, {not_found, list_to_binary(Message)}};
convert_error({amqp_error, not_found, Message}) when is_binary(Message) ->
  {error, {not_found, Message}};
convert_error({amqp_error, access_refused, Message}) when is_list(Message) ->
  {error, {access_refused, list_to_binary(Message)}};
convert_error({amqp_error, access_refused, Message}) when is_binary(Message) ->
  {error, {access_refused, Message}};
convert_error({amqp_error, precondition_failed, Message}) when is_list(Message) ->
  {error, {precondition_failed, list_to_binary(Message)}};
convert_error({amqp_error, precondition_failed, Message}) when is_binary(Message) ->
  {error, {precondition_failed, Message}};
convert_error({amqp_error, resource_locked, Message}) when is_list(Message) ->
  {error, {resource_locked, list_to_binary(Message)}};
convert_error({amqp_error, resource_locked, Message}) when is_binary(Message) ->
  {error, {resource_locked, Message}};
% Map common connection and network errors
convert_error(econnrefused) ->
  {error, {connection_refused, <<"Connection refused by server">>}};
convert_error(etimedout) ->
  {error, {connection_timeout, <<"Connection timed out">>}};
convert_error(timeout) ->
  {error, {connection_timeout, <<"Operation timed out">>}};
convert_error(channel_closed) ->
  {error, {channel_closed, <<"Channel closed">>}};
convert_error(connection_closed) ->
  {error, {closed, <<"Connection closed">>}};
convert_error({channel_closed, Reason}) when is_list(Reason) ->
  {error, {channel_closed, list_to_binary(Reason)}};
convert_error({channel_closed, Reason}) when is_binary(Reason) ->
  {error, {channel_closed, Reason}};
convert_error({connection_closed, Reason}) when is_list(Reason) ->
  {error, {closed, list_to_binary(Reason)}};
convert_error({connection_closed, Reason}) when is_binary(Reason) ->
  {error, {closed, Reason}};
% Handle invalid path errors
convert_error({invalid_path, Path}) when is_list(Path) ->
  {error, {invalid_path, list_to_binary(Path)}};
convert_error({invalid_path, Path}) when is_binary(Path) ->
  {error, {invalid_path, Path}};
% Handle command invalid errors
convert_error(command_invalid) ->
  {error, {command_invalid, <<"Invalid command">>}};
convert_error({command_invalid, Reason}) when is_list(Reason) ->
  {error, {command_invalid, list_to_binary(Reason)}};
convert_error({command_invalid, Reason}) when is_binary(Reason) ->
  {error, {command_invalid, Reason}};
% Handle frame errors
convert_error(frame_error) ->
  {error, {frame_error, <<"Frame error">>}};
convert_error({frame_error, Reason}) when is_list(Reason) ->
  {error, {frame_error, list_to_binary(Reason)}};
convert_error({frame_error, Reason}) when is_binary(Reason) ->
  {error, {frame_error, Reason}};
% Handle internal errors
convert_error(internal_error) ->
  {error, {internal_error, <<"Internal server error">>}};
convert_error({internal_error, Reason}) when is_list(Reason) ->
  {error, {internal_error, list_to_binary(Reason)}};
convert_error({internal_error, Reason}) when is_binary(Reason) ->
  {error, {internal_error, Reason}};
% Generic error handling for tuples - try to map atom to specific error
convert_error({connection_refused, Message}) when is_list(Message) ->
  {error, {connection_refused, list_to_binary(Message)}};
convert_error({connection_refused, Message}) when is_binary(Message) ->
  {error, {connection_refused, Message}};
convert_error({not_allowed, Message}) when is_list(Message) ->
  {error, {not_allowed, list_to_binary(Message)}};
convert_error({not_allowed, Message}) when is_binary(Message) ->
  {error, {not_allowed, Message}};
convert_error({not_implemented, Message}) when is_list(Message) ->
  {error, {not_implemented, list_to_binary(Message)}};
convert_error({not_implemented, Message}) when is_binary(Message) ->
  {error, {not_implemented, Message}};
convert_error({no_route, Message}) when is_list(Message) ->
  {error, {no_route, list_to_binary(Message)}};
convert_error({no_route, Message}) when is_binary(Message) ->
  {error, {no_route, Message}};
convert_error({unexpected_frame, Message}) when is_list(Message) ->
  {error, {unexpected_frame, list_to_binary(Message)}};
convert_error({unexpected_frame, Message}) when is_binary(Message) ->
  {error, {unexpected_frame, Message}};
% Generic error handling for other tuples
convert_error({ErrorType, Message}) when is_atom(ErrorType), is_list(Message) ->
  {error, {ErrorType, list_to_binary(Message)}};
convert_error({ErrorType, Message}) when is_atom(ErrorType), is_binary(Message) ->
  {error, {ErrorType, Message}};
% Fallback for unknown atom errors
convert_error(Error) when is_atom(Error) ->
  {error, Error};
% Fallback for completely unknown errors
convert_error(Error) ->
  {error, {unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

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
      {ok, Pid};
    {error, Error} ->
      convert_error(Error)
  end.

open_channel(Client) ->
  case amqp_connection:open_channel(Client#client.pid) of
    {ok, ChannelPid} ->
      {ok, #channel{pid = ChannelPid}};
    {error, Error} ->
      convert_error(Error)
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
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('exchange.delete', {ticket = 0, exchange, if_unused = false, nowait = false}).

exchange_delete(Channel, Name, IfUnused, Nowait) ->
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('exchange.bind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_bind(Channel, Source, Destination, RoutingKey, Nowait) ->
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('exchange.unbind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_unbind(Channel, Source, Destination, RoutingKey, Nowait) ->
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
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
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('queue.delete',
        {ticket = 0, queue = <<"">>, if_unused = false, if_empty = false, nowait = false}).

queue_delete(Channel, Queue, IfUnused, IfEmpty, Nowait) ->
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('queue.bind',
        {ticket = 0,
         queue = <<"">>,
         exchange,
         routing_key = <<"">>,
         nowait = false,
         arguments = []}).

queue_bind(Channel, Queue, Exchange, RoutingKey, Nowait) ->
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('queue.unbind',
        {ticket = 0, queue = <<"">>, exchange, routing_key = <<"">>, arguments = []}).

queue_unbind(Channel, Queue, Exchange, RoutingKey) ->
  try
    case amqp_channel:call(Channel#channel.pid,
                           #'queue.unbind'{queue = Queue,
                                           exchange = Exchange,
                                           routing_key = RoutingKey})
    of
      {'queue.unbind_ok'} ->
        {ok, nil};
      Error ->
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
  end.

-record('queue.purge', {ticket = 0, queue = <<"">>, nowait = false}).

queue_purge(Channel, Queue, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(Channel#channel.pid, #'queue.purge'{queue = Queue, nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'queue.purge_ok', MessageCount}} ->
        {ok, MessageCount};
      {_, Error} ->
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
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
  try
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
        convert_error(Error)
    end
  catch
    exit:Reason ->
      convert_error(Reason);
    error:Reason ->
      convert_error(Reason)
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
-record('basic.consume_ok', {consumer_tag}).

consume(Channel, Queue, Pid, RequiredAck) ->
  % Set no_ack to true so messages are automatically acknowledged by RabbitMQ
  % AMQP will send messages directly to Pid, including basic.consume_ok
  case amqp_channel:subscribe(Channel#channel.pid,
                              #'basic.consume'{queue = Queue, no_ack = RequiredAck},
                              Pid)
  of
    {'basic.consume_ok', ConsumerTag_} ->
      % The AMQP client might send basic.consume_ok directly to Pid
      % Don't send it again
      {ok, ConsumerTag_};
    _ ->
      io:write("Unexpected response in consume/3\n"),
      {error, unexpected_response}
  end.

-record('basic.ack', {delivery_tag = 0, multiple = false}).

ack(Channel, DeliveryTag, Multiple) ->
  case amqp_channel:call(Channel#channel.pid,
                         #'basic.ack'{delivery_tag = DeliveryTag, multiple = Multiple})
  of
    ok ->
      {ok, nil};
    Error ->
      convert_error(Error)
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
      convert_error(Error)
  end.

close(CarotteClient) ->
  case amqp_connection:close(CarotteClient#client.pid) of
    ok ->
      {ok, nil};
    {error, Error} ->
      convert_error(Error)
  end.

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
       lists:map(fun({ArrayValue}) -> {header_value_to_header_tuple(ArrayValue)} end, Inner)}
  end.
