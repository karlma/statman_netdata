%%%-------------------------------------------------------------------
%%% @author karl
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. 十月 2017 下午4:30
%%%-------------------------------------------------------------------
-module(statman_netdata_report).
-author("karl").

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {socket}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
init([]) ->
    {ok, Socket} = gen_udp:open(0, [binary]),
    statman_server:add_subscriber(self()),
    statman_poller_sup:add_gauge(fun statman_vm_metrics:get_gauges/0, 100),
    statman_poller_sup:add_counter(fun statman_vm_metrics:io/1, 100),
    {ok, #state{socket=Socket}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
    {reply, Reply :: term(), NewState :: #state{}} |
    {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_cast({statman_update, Request}, State) ->
    %%io:format("report receive: ~p~n", [Request]),
    case format_data(Request, []) of
        {ok, <<>>} ->
            ok;
        {ok, Data} ->
            %%io:format("format_data: ~p~n", [Data]),
            send_to_netdata(State#state.socket, Data);
        error ->
            ok % TODO: log
    end,
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, State) ->
    gen_udp:close(State#state.socket),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
    {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec(send_to_netdata(Socket :: gen_udp:socket(), Data::binary()) -> ok | {error, Reason :: term()}).
send_to_netdata(Socket, Data) when is_binary(Data) ->
   gen_udp:send(Socket, "localhost", 9125, Data).

-spec(format_data(L::list(), Data::list()) -> error | {ok, NewData::binary()}).
format_data([], Data) ->
    {ok, list_to_binary(lists:flatten(Data))};
format_data([H|T], Data) ->
    KL = [{{vm, process_count}, "vm.process_count", "g", 1}
            ,{{vm, processes_with_queues}, "vm.processes_with_queues", "g"}
            ,{{vm, messages_in_queue}, "vm.messages_in_queue", "g"}
            ,{{vm, run_queue}, "vm.run_queue", "g"}
            ,{{vm, io_in_bytes}, "vm.io_in_bytes", "c"}
            ,{{vm, io_out_bytes}, "vm.io_out_bytes", "c"}
            ,{{vm_ets, objects}, "vm_ets.objects", "g"}
            ,{{vm_memory, total}, "vm_memory.total", "g"}
            ,{{vm_memory, system}, "vm_memory.system", "g"}
            ,{{vm_memory, processes_used}, "vm_memory.processes_used", "g"}
            ,{{vm_memory, ets}, "vm_memory.ets", "g"}
            ,{{vm_memory, processes}, "vm_memory.processes", "g"}
            ,{{vm_memory, atom}, "vm_memory.atom", "g"}
            ,{{vm_memory, atom_used}, "vm_memory.atom_used", "g"}
            ,{{vm_memory, code}, "vm_memory.code", "g"}
            ,{{vm_memory, binary}, "vm_memory.binary", "g"}
            ,{{ejabberd, sm_register_connection}, "sm_register_connection", "c"}
            ,{{ejabberd, offline_message}, "offline_message", "c"}
            ,{{ejabberd, sm_remove_connection}, "sm_remove_connection", "c"}
            ,{{ejabberd, user_send_packet}, "user_send_packet", "c"}
            ,{{ejabberd, user_receive_packet}, "user_receive_packet", "c"}
            ,{{ejabberd, s2s_send_packet}, "s2s_send_packet", "c"}
            ,{{ejabberd, s2s_receive_packet}, "s2s_receive_packet", "c"}
            ,{{ejabberd, remove_user}, "remove_user", "c"}
            ,{{ejabberd, register_user}, "register_user", "c"}
            ,{{mnesia, session_size}, "mnesia.session_size", "g"}
            ,{{mnesia, vcard_size}, "mnesia.vcard_size", "g"}
            ,{{mnesia, last_activity_size}, "mnesia.last_activity", "g"}],
    case [{K, V} || {key, K} <- H, {value, V} <- H] of
        [{K, V}|_] ->
            case lists:keyfind(K, 1, KL) of
                false ->
                    case K of
                        {vm_ets, Obj} ->
                            format_data(T, [io_lib:format("ejabberd.vm_ets.~s:~w|g", atom_to_list(Obj), V)|Data]);
                        _ ->
                            format_data(T, [Data])
                    end;
                {K, KS, Type} ->
                    format_data(T, [io_lib:format("ejabberd.~s:~w|~s~n", [KS, V, Type])|Data])
            end;
        [] ->
            format_data(T, [Data])
    end.


%% statman_poller_sup:add_gauge(fun statman_vm_metrics:get_gauges/0, 100).

%% [[{key,{vm_memory,processes_used}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,5094944},
%%                   {window,1000}],
%%                  [{key,{vm_memory,processes}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,5094944},
%%                   {window,1000}],
%%                  [{key,{vm_memory,binary}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,1202536},
%%                   {window,1000}],
%%                  [{key,{vm,process_count}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,44},
%%                   {window,1000}],
%%                  [{key,{vm_memory,total}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,105567392},
%%                   {window,1000}],
%%                  [{key,{vm_memory,ets}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,423192},
%%                   {window,1000}],
%%                  [{key,{vm,processes_with_queues}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,0},
%%                   {window,1000}],
%%                  [{key,{vm_memory,code}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,7990957},
%%                   {window,1000}],
%%                  [{key,{vm,messages_in_queue}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,0},
%%                   {window,1000}],
%%                  [{key,{vm_ets,objects}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,240},
%%                   {window,1000}],
%%                  [{key,{vm_memory,atom}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,331249},
%%                   {window,1000}],
%%                  [{key,{vm_memory,atom_used}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,318731},
%%                   {window,1000}],
%%                  [{key,{vm,run_queue}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,0},
%%                   {window,1000}],
%%                  [{key,{vm_memory,system}},
%%                   {node,statman_netdata@19af86e6d815},
%%                   {type,gauge},
%%                   {value,100472448},
%%                   {window,1000}]]
