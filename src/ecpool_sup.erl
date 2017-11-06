%%--------------------------------------------------------------------
%% Copyright (c) 2013-2017 EMQ Enterprise, Inc. (http://emqtt.io)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------
%%
%% @doc ECPool Supervisor.
%%
%%--------------------------------------------------------------------

-module(ecpool_sup).

-author("Feng Lee <feng@emqtt.io>").

-behaviour(supervisor).

%% API
-export([start_link/0, start_pool/3, stop_pool/1, pools/0, pool/1]).

%% Supervisor callbacks
-export([init/1]).

%% @doc Start supervisor.
-spec(start_link() -> {ok, pid()} | {error, any()}).
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_pool(PoolId, Mod, Opts) ->
    supervisor:start_child(?MODULE, pool_spec(PoolId, Mod, Opts)).

stop_pool(PoolId) ->
    ChildId = child_id(PoolId),
	case supervisor:terminate_child(?MODULE, ChildId) of
        ok ->
            supervisor:delete_child(?MODULE, ChildId);
        {error, Reason} ->
            {error, Reason}
	end.

%% @doc All Pools supervisored by ecpool_sup.
-spec(pools() -> [{ecpool:pool_id(), pid()}]).
pools() ->
    [{PoolId, Pid} || {{pool_sup, PoolId}, Pid, supervisor, _}
                      <- supervisor:which_children(?MODULE)].

%% @doc Find a pool.
-spec(pool(ecpool:pool_id()) -> undefined | pid()).
pool(PoolId) ->
    ChildId = child_id(PoolId),
    case [Pid || {Id, Pid, supervisor, _} <- supervisor:which_children(?MODULE), Id =:= ChildId] of
        [] -> undefined;
        L  -> hd(L)
    end.

%%%=============================================================================
%%% Supervisor callbacks
%%%=============================================================================

init([]) ->
    {ok, { {one_for_one, 10, 100}, []} }.

pool_spec(PoolId, Mod, Opts) ->
    {child_id(PoolId),
        {ecpool_pool_sup, start_link, [PoolId, Mod, Opts]},
            transient, infinity, supervisor, [ecpool_pool_sup]}.

child_id(PoolId) ->
    {pool_sup, PoolId}.

