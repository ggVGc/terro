
defmodule FighterAI do
  require Logger
  alias Graphmath.Vec2

  defp find_closest(pos, objs) do
    Enum.reduce(objs, fn(o, closest) ->
      d = Vec2.length(Vec2.subtract(pos, o.pos))
      closest_dist = Vec2.length Vec2.subtract(pos, closest.pos)
      if d < closest_dist do
        o
      else
        closest
      end
    end)
  end


  def run(spawners, fighter) do
    other_spawners = Enum.filter(spawners, fn s -> s.owner != fighter.owner end)
    if length(other_spawners) == 0 do
      fighter.dir
    else
      closest = find_closest(fighter.pos, other_spawners)

      if closest == nil do
        fighter.dir
      else
        try do
          Vec2.normalize(Vec2.subtract(closest.pos, fighter.pos))
        rescue e in ArithmeticError ->
          fighter.dir
        end
      end
    end
  end

end
