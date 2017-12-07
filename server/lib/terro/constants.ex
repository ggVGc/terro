
defmodule Constants do
  use ConstantsHelp
  con spawner_health, 26
  con defense_health, 45
  con initial_credits, 10.0
  con spawn_time, 4300
  con damage, 16
  con spawner_cost, 3
  con defense_cost, 2
  con credit_per_kill, 1
  con credits_per_tick_per_building, 0.0026
  con max_fighter_lifetime, 15000
  con building_half_size, 6
  con fighter_move_speed, 1.2
  con building_radius, 29
  con frame_delta, 100 
  con init_resource_slots, [
      [100,100],
      [30,75],
      [170,135],
      [30,135],
      [170,75]
    ]
end

