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
%% @doc ECPool Main API.
%%
%%--------------------------------------------------------------------

-module(ecpool).

-author("Feng Lee <feng@emqtt.io>").

-export([pool_spec/4, start_pool/3, start_sup_pool/3, stop_sup_pool/1,
         get_client/1, get_client/2, with_client/2, with_client/3,
         name/1, workers/1]).

-type(pool_id() :: term()).

-type(pool_type() :: random | hash | round_robin).

-type(option() :: {pool_size, pos_integer()}
                | {pool_type, pool_type()}
                | {auto_reconnect, false | pos_integer()}
                | tuple()).

-export_type([pool_id/0]).

pool_spec(ChildId, Pool, Mod, Opts) ->
    {ChildId, {?MODULE, start_pool, [Pool, Mod, Opts]},
     permanent, 5000, supervisor, [ecpool_pool_sup]}.

%% @doc Start the Pool
-spec(start_pool(pool_id(), atom(), [option()]) -> {ok, pid()} | {error, term()}).
start_pool(PoolId, Mod, Opts) ->
    ecpool_pool_sup:start_link(PoolId, Mod, Opts).

%% @doc Start the pool supervised by ecpool_sup
-spec(start_sup_pool(pool_id(), atom(), [option()]) -> {ok, pid()} | {error, term()}).
start_sup_pool(PoolId, Mod, Opts) ->
    ecpool_sup:start_pool(PoolId, Mod, Opts).

%% @doc Start the pool supervised by ecpool_sup
-spec(stop_sup_pool(pool_id()) -> ok).
stop_sup_pool(PoolId) ->
    ecpool_sup:stop_pool(PoolId).

%% @doc Get client/connection
-spec(get_client(pool_id()) -> pid()).
get_client(PoolId) ->
    gproc_pool:pick_worker(name(PoolId)).

%% @doc Get client/connection with hash key.
-spec(get_client(pool_id(), any()) -> pid()).
get_client(PoolId, Key) ->
    gproc_pool:pick_worker(name(PoolId), Key).

%% @doc Call the fun with client/connection
-spec(with_client(pool_id(), fun((Client :: pid()) -> any())) -> any()).
with_client(PoolId, Fun) ->
    with_worker(gproc_pool:pick_worker(name(PoolId)), Fun).

%% @doc Call the fun with client/connection
-spec(with_client(pool_id(), any(), fun((Client :: pid()) -> any())) -> any()).
with_client(PoolId, Key, Fun) ->
    with_worker(gproc_pool:pick_worker(name(PoolId), Key), Fun).

with_worker(Worker, Fun) ->
    case ecpool_worker:client(Worker) of
        {ok, Client}    -> Fun(Client);
        {error, Reason} -> {error, Reason}
    end.

%% @doc ecpool name
name(PoolId) -> {?MODULE, PoolId}.

%% @doc pool workers
workers(PoolId) -> gproc_pool:active_workers(name(PoolId)).

