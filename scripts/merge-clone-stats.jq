# Input: previous ledger; $traffic: current GitHub daily traffic response.
# Keep old daily buckets when they fall outside GitHub's rolling window.
if ($traffic.clones | type) != "array" then error("invalid traffic response") else . end
| reduce $traffic.clones[] as $day (.;
    if ($day.timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T"))
       and ($day.count | type) == "number" and $day.count >= 0 and ($day.count|floor) == $day.count
    then
      ($day.timestamp[0:10]) as $date
      | if $date > .after then .days[$date] = $day.count else . end
    else error("invalid traffic bucket") end)
