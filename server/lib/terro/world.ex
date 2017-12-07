defmodule Terro.World do
  use GenServer
  require Logger
  alias Graphmath.Vec2
  require Constants
  alias Float


  @fighter_other 2
  @fighter_mine  3


  def start_link(players) do
    GenServer.start_link(__MODULE__, %WorldState{:players => players})
  end

  def init(state) do
    [id1,id2] = Enum.map(state.players, &(&1.id))

    new_state = %{state|
      :player_states => Enum.reduce(state.players, %{}, fn(p,accum) ->
          Map.put(accum, p.id, %PlayerState{})
        end),
      :defenses => [
          %DefenseBuilding{
            :pos => {100,25},
            :owner => id1
          },
          %DefenseBuilding{
            :pos => {100,175},
            :owner => id2
          }
        ],
      :id_counter => 2
    }

    Enum.map(state.players, fn p ->
      Phoenix.Channel.push(p.socket, "resourceSlots", %{slots: state.resource_slots})
      Enum.map(new_state.defenses, fn d ->
        add_thing(d, p, 5, 4);
      end)
    end)
    schedule_update_world()

    {:ok, new_state}
  end


  def place_spawner(server,pos,player_id) do
    GenServer.call(server, {:place_spawner, pos, player_id})
  end

  def place_defense(server,pos,player_id) do
    GenServer.call(server, {:place_defense, pos, player_id})
  end

  # TODO: Optimize this. Ridiculous time complexity left over from prototype stage
  def update_spawners(players, spawners, defences, delta_time, init_spawn_id) do
    Enum.reduce(spawners, {[[], []], init_spawn_id}, fn(s, {[new_spawners, out_fighters], spawn_id}) ->
        v = s.spawn_timer - delta_time
        if v <= 0 do
          spawner = %{s|:spawn_timer => Constants.spawn_time - (abs v)}
          other_spawners = Enum.filter(spawners, &(&1.owner != s.owner))
          targets =
            if length(other_spawners) != 0 do other_spawners
            else Enum.filter(defences, &(&1.owner != s.owner)) 
            end

          doFigher = length(targets) != 0

          {[[spawner|new_spawners], 
            if doFigher do
              f = %Fighter{
                  :pos => s.pos,
                  :owner => s.owner,
                  :id => spawn_id
                }
              f = %{f| :dir => FighterAI.run(targets, f) }
              Enum.map(players, fn p ->
                {dx, dy} = f.dir
                add_thing(%{f|
                  :dir => {dx*Constants.fighter_move_speed, dy*Constants.fighter_move_speed}
                }, p, @fighter_mine, @fighter_other)
              end)
              [f| out_fighters]
            else
              out_fighters
            end
          ], spawn_id+1}
        else
          spawner = %{s|:spawn_timer => v}
          {[[spawner|new_spawners], out_fighters], spawn_id}
        end
      end)
  end

  defp valid_build_pos(state, player_id, x,y) do
    all = all_buildings state
    collided = collide({x,y}, Constants.building_half_size*2, all)
    my_buildings = Enum.filter(all, &(&1.owner == player_id))
    in_radius = collide({x,y}, Constants.building_radius, my_buildings)
    collided == nil && in_radius != nil
  end


  defp send_thing(add, thing, p, mine_type, other_type) do
    mine = thing.owner == p.id
    Phoenix.Channel.push(p.socket, if add do "addThing" else "removeThing" end, %{
      type: if mine do mine_type else other_type end,
      id: thing.id,
      obj: %{
        pos: Tuple.to_list(thing.pos),
        dir: if Map.has_key?(thing, :dir) do Tuple.to_list(thing.dir) else nil end
      }
    })
  end

  defp add_thing(thing, o, mine_type, other_type) do
    send_thing(true, thing, o, mine_type, other_type)
  end

  defp remove_thing(thing, o, mine_type, other_type) do
    send_thing(false, thing, o, mine_type, other_type)
  end

  def handle_call({:place_defense, pos, player_id}, _, state) do
    [ new_state, added_obj ] = place_building state, :defenses, player_id, pos
    if added_obj != nil do
      Enum.map(state.players, fn p ->
        add_thing(added_obj, p, 5, 4)
      end)
    end
    {:reply, :ok, new_state}
  end


  def handle_call({:place_spawner, pos, player_id}, _, state) do
    [ new_state, added_obj ] = place_building state, :spawners, player_id, pos
    if added_obj != nil do
      Enum.map(state.players, fn p ->
        add_thing(added_obj, p, 1, 0)
      end)
    end
    {:reply, :ok, new_state}
  end


  def place_building(state, type, player_id, [x,y]) do
    no_action = [state, nil]

    if valid_build_pos(state, player_id, x,y) do
      {newObj, rest, cost} =
        case type do
          :defenses -> {%DefenseBuilding{}, state.defenses, Constants.defense_cost}
          :spawners -> {%SpawnerBuilding{}, state.spawners, Constants.spawner_cost}
        end

      if state.player_states[player_id].credits >= cost do
        Logger.info "Placing  building: #{type}, #{x}, #{y}, id: #{player_id}"
        added_obj = %{newObj|
              :pos => {x, y},
              :owner => player_id,
              :id => state.id_counter
            }
        new_state = %{state |
          type => [added_obj | rest],
          :id_counter => state.id_counter+1
        }

        new_state = update_in(new_state.player_states[player_id], fn st ->
          update_in(st.credits, fn c -> c - cost end)
        end)

        Enum.map state.players, fn p -> send_credits p, new_state.player_states end

        # broadcast_state new_state
        [new_state, added_obj]
      else
        no_action
      end
    else
      no_action
    end
  end


  defp send_credits(player, player_states) do
    Phoenix.Channel.push(player.socket, "credits", %{c: player_states[player.id].credits})
  end


  defp schedule_update_world() do
    Process.send_after(self(), :update_world, Constants.frame_delta)
  end


  defp remove_timeout_fighters(players, fighters) do
    {active, timed_out} = Enum.partition(fighters, &(&1.life_time < Constants.max_fighter_lifetime))
    Enum.map(players, fn p ->
      Enum.map(timed_out, fn f ->
        remove_thing(f, p, @fighter_mine, @fighter_other)
      end)
    end)
    active
  end


  defp update_fighters(players, fighters, delta) do
    new_fighters = Enum.map(fighters, fn  f ->
      {x,y} = f.pos
      {dx,dy} = f.dir
      %{f |
       :pos => {x + dx*Constants.fighter_move_speed, y + dy*Constants.fighter_move_speed},
       :life_time => f.life_time + delta
      }

    end)
    remove_timeout_fighters players, new_fighters
  end


  defp collide(pos, rad, objs) do
    Enum.reduce(objs, nil, fn(o,acc) ->
      if Vec2.near(pos, o.pos, rad) do
        o
      else
        acc
      end
    end)
  end


  defp remove_fighter(f, player) do
    remove_thing(f, player, @fighter_mine, @fighter_other)
  end


  defp collide_buildings(players, fighters, in_buildings, is_defense) do
    Enum.reduce(fighters, {%{}, in_buildings,[]}, fn(fighter, {kills, buildings, rest_fighters}) ->
        other_building = Enum.filter(buildings, &(&1.owner != fighter.owner))
        collide_building = collide(fighter.pos, Constants.building_half_size, other_building)
        if collide_building != nil do
          not_collided_buildings = Enum.filter(buildings, fn s->s != collide_building end)
          newHealth = collide_building.health-Constants.damage
          dead = newHealth <= 0
          Enum.map(players, fn p ->
            remove_fighter(fighter, p)
            if dead do
              mine_type = if is_defense do 5 else 1 end
              other_type = if is_defense do 4 else  0 end
              remove_thing(collide_building, p, mine_type, other_type)
            end
          end)
          new_spawners =
            if dead do
              not_collided_buildings
            else
              [%{collide_building|:health => newHealth} | not_collided_buildings]
            end
          {Map.update(kills, fighter.owner, 1, &(&1+1)), new_spawners,  rest_fighters}
        else
          {kills, buildings, [fighter|rest_fighters]}
        end
      end)
  end


  defp process_damages(state) do
    {kills1, spawners, rest_fighters} = collide_buildings(state.players, state.fighters, state.spawners, false)
    {kills2, defenses, rest_fighters} = collide_buildings(state.players, rest_fighters, state.defenses, true)

    kills = Map.merge kills1, kills2

    new_player_states = Enum.reduce(Map.keys(state.player_states), state.player_states, fn (id,accum) ->
      k = kills[id]
      if k == nil do
        accum
      else
        update_in(accum[id].credits, &(&1+k*Constants.credit_per_kill))
      end
    end)

    # Send everyone their credits
    Enum.map state.players, &(send_credits &1, new_player_states)


    %{state|
      :spawners => spawners,
      :defenses => defenses,
      :fighters => rest_fighters,
      :player_states => new_player_states 
    }
  end


  defp buildings_in_resource_areas(buildings, resource_slots) do
    Enum.filter(buildings, fn b ->
      Enum.any?(resource_slots, fn [x,y] ->
        Vec2.near(b.pos, {x,y}, Constants.building_half_size*2+Constants.building_radius)
      end)
    end)
    |> length
  end


  defp all_buildings(state) do
    state.defenses ++ state.spawners
  end


  defp tick_credits(state) do
    new_player_states = Enum.reduce(state.player_states, %{}, fn({id,st}, accum)->
      my_buildings = Enum.filter(all_buildings(state), &(&1.owner == id))
      count = buildings_in_resource_areas(my_buildings, state.resource_slots)
      add_creds = count*Constants.credits_per_tick_per_building
      # Logger.info "#{id} - #{add_creds} - #{st.credits}"
      Map.put(accum, id, %{st| :credits => st.credits+add_creds})
    end)

    Enum.map(state.players, fn player ->
      old_creds = state.player_states[player.id].credits
      new_creds = new_player_states[player.id].credits
      if Float.floor(new_creds) - Float.floor(old_creds) >= 1 do
        send_credits(player, new_player_states)
      end
    end)

    %{state| :player_states => new_player_states }
  end


  defp update_world(state) do
    {[new_spawners, new_fighters], new_spawn_id} =
      update_spawners(
        state.players,
        state.spawners,
        state.defenses,
        Constants.frame_delta,
         state.id_counter
      )

    %{state |
     :spawners => new_spawners,
     :fighters => update_fighters(state.players, new_fighters ++ state.fighters, Constants.frame_delta),
     :id_counter => new_spawn_id
    }
    # |> runFighterAI
    |> process_damages
    |> tick_credits

  end


  def handle_info(:update_world, state) do
    schedule_update_world()

    new_state = update_world state
    # broadcast_state new_state

    {:noreply, new_state}
  end

end
