%%%-------------------------------------------------------------------
%% @doc boxy_erlang public API
%% @end
%%%-------------------------------------------------------------------

-module(boxy_erlang_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    boxy_erlang_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
