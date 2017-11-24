%%%-------------------------------------------------------------------
%% @doc statman_netdata top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(statman_netdata_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    {ok, { {one_for_all, 0, 1}, [
        %%{statman_aggregator, {statman_aggregator, start_link, []}, permanent, 5000, worker, [statman_aggregator]},
        {statman_netdata_report, {statman_netdata_report, start_link, []}, permanent, 5000, worker, [statman_netdata_report]}
    ]} }.

%%====================================================================
%% Internal functions
%%====================================================================
