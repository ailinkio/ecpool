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
%% @doc ECPool Worker Supervisor.
%%
%%--------------------------------------------------------------------

-module(ecpool_worker_sup).

-behaviour(supervisor).

-author("Feng Lee <feng@emqtt.io>").

-export([start_link/3, init/1]).

start_link(PoolId, Mod, Opts) ->
    supervisor:start_link(?MODULE, [PoolId, Mod, Opts]).

init([PoolId, Mod, Opts]) ->
    WorkerSpec = fun(Id) ->
        {{worker, Id}, {ecpool_worker, start_link, [PoolId, Id, Mod, Opts]},
            transient, 5000, worker, [ecpool_worker, Mod]}
    end,
    Workers = [WorkerSpec(I) || I <- lists:seq(1, pool_size(Opts))],
    {ok, { {one_for_one, 10, 60}, Workers} }.

pool_size(Opts) ->
    Schedulers = erlang:system_info(schedulers),
    proplists:get_value(pool_size, Opts, Schedulers).

