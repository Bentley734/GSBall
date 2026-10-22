-- Crystal's native delivery gate is sGSBallFlag == $0B (SRAM bank 1,
-- $BE3C), rather than a wEventFlags completion bit. Gen1recomp models it
-- as save.crystal.gsBall == "have"; BattleTowerAction GSBALL reads it.
return function(mod)
  local function unlock(save)
    if type(save) ~= "table" or save.version ~= "crystal" then return end
    if save.generation ~= 2 then return end
    -- Native HallOfFame.hasEntered evidence; `entered` also supports
    -- imported cartridge saves whose victory count is unavailable.
    local hall = save.hallOfFame
    if type(hall) ~= "table" then return end
    if hall.entered ~= true and (tonumber(hall.count) or 0) < 1 then return end
    local crystal = save.crystal
    if crystal ~= nil and type(crystal) ~= "table" then return end
    -- Never downgrade an existing activation or later quest state.
    if crystal and (crystal.gsBall ~= nil or crystal.celebiCaught) then return end
    if not crystal then crystal = {}; save.crystal = crystal end
    crystal.gsBall = "have"
  end

  mod.events:on("game.ready", function(ev)
    local game = ev.game or mod.game
    unlock(game and game.save)
  end)
  mod.events:on("save.loaded", function(ev) unlock(ev.save) end)
  -- Covers New Game, map changes and Hoennto campaign arrivals. Resolve
  -- the current owner each time; never retain a previous campaign's save.
  mod.events:on("map.entered", function()
    local game = mod.game
    unlock(game and game.save)
  end)
end
