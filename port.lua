-- Gold/Silver lack Crystal's delivery and quest scripts. This adaptation uses
-- their own sprites, map objects, daily reset, inventory and native battle VM.
return function(mod)
  local Bag = require('src.inventory.Bag')
  local Apricorns = require('src.core.gen2.Apricorns')
  local ID, ITEM = 'crystal_gs_ball', 'ITEM_73'
  local PREFIX = ID .. ':port:'

  local function supported(save)
    return save and save.generation == 2
      and (save.version == 'gold' or save.version == 'silver')
  end
  local function champion(save)
    local h = save and save.hallOfFame
    return type(h) == 'table' and (h.entered == true or (tonumber(h.count) or 0) > 0)
  end
  local function state(save)
    local bucket = save.modData and save.modData[ID]
    return bucket and bucket.gsPort
  end
  local function write(save, value)
    save.modData = save.modData or {}
    save.modData[ID] = save.modData[ID] or {}
    save.modData[ID].gsPort = value
  end
  local function live(ctx)
    local game = mod.game
    local world = game and game.world
    if not (game and supported(game.save) and world and world.vm == ctx.vm) then return end
    return game, world, game.save
  end
  local function say(vm, text) vm:showRaw(text) end
  local function move(vm, object, bytes)
    if vm.applyMovementFn then coroutine.yield({kind='move',object=object,bytes=bytes}) end
  end
  local function rows(n, byte, first)
    local out = {}
    if first then out[#out+1] = first end
    for _=1,n do out[#out+1] = byte end
    out[#out+1] = 0x47
    return out
  end
  local function removeDoors(world)
    local def = world.maps.GOLDENROD_POKECENTER_1F
    local kept = {}
    for _, ev in ipairs(def.coordEvents or {}) do
      if not ev.gsBallPort then kept[#kept+1] = ev end
    end
    def.coordEvents = kept
  end

  mod.content.commands:register(PREFIX..'delivery', function(ctx, x)
    local game, world, save = live(ctx)
    if not game or not champion(save) or state(save) ~= nil then return 'end' end
    -- Never duplicate a preexisting copy of the unused slot.
    if (save.inventory[ITEM] or 0) > 0 then
      write(save,{stage='have'})
      removeDoors(world)
      return 'end'
    end
    local npcId = assert(world:addRuntimeObject('GOLDENROD_POKECENTER_1F', {
      sprite='SPRITE_LINK_RECEPTIONIST',x=0,y=7,
      movement='SPRITEMOVEDATA_STANDING_DOWN',type=0,
    },ID))
    local def = world.maps.GOLDENROD_POKECENTER_1F
    local object = def.objects[#def.objects].index + 1
    local vm = ctx.vm
    move(vm, object, rows(x,0x0f,0x0d)) -- up, then right to the player
    if vm.turnObjectFn then
      vm.turnObjectFn(object,'down')
      vm.turnObjectFn(0,'up')
    end
    say(vm, 'Congratulations,\nCHAMPION!\n\nA special delivery\nhas arrived for you.\nIt is a GS BALL.\n\nPlease show it to\nKURT in AZALEA TOWN.')
    if Bag.add(save,ITEM,1,game.data) then
      write(save,{stage='have'})
      say(vm, '{PLAYER} received\nthe GS BALL!')
      removeDoors(world)
    else
      say(vm, 'Your KEY ITEM\npocket is full.\n\nMake room, then\nvisit us again.')
    end
    local back=rows(x,0x0e)
    table.insert(back,#back,0x0c) -- left, then down to the stairs
    move(vm,object,back)
    world:removeRuntimeObject(npcId,ID)
    return 'end'
  end)

  mod.content.commands:register(PREFIX..'kurt',function(ctx)
    local game,world,save=live(ctx)
    if not game or not champion(save) then return end
    local q=state(save)
    if not q or q.stage=='caught' then return end
    local making=world:engineFlagId('ENGINE_KURT_MAKING_BALLS',79)
    if q.stage=='have' then
      -- Let Kurt finish his original introduction and outstanding apricorns.
      if not world.events:get(43) or not world.events:get(53) then return end
      if world:engineFlags()[making] then return end
      for _,row in ipairs(Apricorns.BALLS) do
        if world.events:get(row.event) then return end
      end
      if (save.inventory[ITEM] or 0)<1 then return end
      if ctx.vm.facePlayerFn then ctx.vm.facePlayerFn() end
      say(ctx.vm,'KURT: A GS BALL?\nWhat a curious\nobject!\n\nLet me study it.\nCome back tomorrow.')
      Bag.remove(save,ITEM,1,game.data)
      q.stage='studying'
      world:setEngineFlag(making,true)
    elseif q.stage=='studying' then
      if ctx.vm.facePlayerFn then ctx.vm.facePlayerFn() end
      if world:engineFlags()[making] then
        say(ctx.vm,'KURT: I am still\nexamining the ball.\nCome back tomorrow.')
      else
        say(ctx.vm,'KURT: The GS BALL\nstarted shaking!\n\nIt seems connected\nto ILEX FOREST.\n\nTake it to the\nshrine there.')
        if Bag.add(save,ITEM,1,game.data) then
          q.stage='shrine'
          say(ctx.vm,'KURT returned\nthe GS BALL.')
        else
          say(ctx.vm,'Make room in your\nKEY ITEM pocket,\nthen speak to me.')
        end
      end
    elseif q.stage=='shrine' or q.stage=='placed' then
      if ctx.vm.facePlayerFn then ctx.vm.facePlayerFn() end
      say(ctx.vm,'KURT: Visit the\nshrine in ILEX\nFOREST.')
    else
      return -- unknown future state: preserve it and use native conversation
    end
    return 'end'
  end)

  mod.content.commands:register(PREFIX..'shrine',function(ctx)
    local game,world,save=live(ctx)
    if not game or not champion(save) then return end
    local q=state(save)
    if not q or (q.stage~='shrine' and q.stage~='placed') then return end
    if q.stage=='shrine' and (save.inventory[ITEM] or 0)<1 then return end
    local species=game.data.pokemon and game.data.pokemon.CELEBI
    if not (species and type(species.index)=='number') then
      say(ctx.vm,'The forest is quiet.\nTry again after\nreloading the game.')
      return 'end'
    end
    say(ctx.vm, q.stage=='shrine' and 'The GS BALL shakes.\nPlace it in the\nshrine?' or 'A presence stirs\ninside the shrine.\nCall out to it?')
    if not coroutine.yield({kind='yesorno'}) then return 'end' end
    if q.stage=='shrine' then
      Bag.remove(save,ITEM,1,game.data)
      q.stage='placed'
    end
    say(ctx.vm,'A gentle light\nfills the forest.\n\nCELEBI appeared!')
    -- A real native wild battle handles capture, party/box storage, EXP,
    -- fainting and whiteout. The quest never constructs or awards a Pokemon.
    local outcome=coroutine.yield({kind='battle',wild={species=species.index,level=30}})
    ctx.vm.justBattled=true
    ctx.vm.battleOutcome=outcome
    if outcome=='caught' then
      q.stage='caught'
    end
    -- Scripted battles leave the field reload to their script. Mirror the
    -- native reloadmapafterbattle tail, including terminating after whiteout.
    if ctx.vm.reloadMapFn then ctx.vm.reloadMapFn(true) end
    if outcome==nil or outcome=='lose' then
      ctx.vm.aborted=true
      return 'end'
    end
    ctx.vm:waitFrames(1)
    if outcome~='caught' then
      say(ctx.vm,'The shrine is quiet.\nYou sense CELEBI\nmay return here.')
    end
    return 'end'
  end)

  local function wrap(world,key,verb)
    if not key or not world.scripts[key] then return end
    local marker=PREFIX..'base:'..key
    if world.scripts[marker] then return end
    world.scripts[marker]=world.scripts[key]
    world.scripts[key]={{verb},{op='sjump',script=marker}}
  end
  return function(game)
    local save=game and game.save
    if not supported(save) then return end
    -- Slot $73 is unused TERU-SAMA in Gold/Silver and the GS BALL in Crystal.
    -- Keep its native id and index so bag handling and cartridge export agree.
    local item=game.data and game.data.items and game.data.items[ITEM]
    if item then
      item.name='GS BALL';item.price=0;item.pocket='KEY_ITEM';item.pocketId=2
      item.canToss=false;item.canSelect=false;item.propertyRaw=192
      item.description='A mysterious ball\nlinked to the forest.'
    end
    local world=game.world
    if not (item and world and world.maps and world.vm) then return end
    local mapId=world.map and world.map.id
    if mapId=='GOLDENROD_POKECENTER_1F' and champion(save) and state(save)==nil then
      local def=world.maps[mapId]
      def.coordEvents=def.coordEvents or {}
      for _,x in ipairs({3,4}) do
        local key=PREFIX..'delivery:'..x
        world.scripts[key]={{PREFIX..'delivery',x}}
        local found=false
        for _,ev in ipairs(def.coordEvents) do if ev.scriptKey==key then found=true end end
        if not found then
          def.coordEvents[#def.coordEvents+1]={x=x,y=7,sceneId=0,scriptKey=key,gsBallPort=true}
        end
      end
    elseif mapId=='KURTS_HOUSE' then
      for _,obj in ipairs(world.maps[mapId].objects or {}) do
        if obj.sprite=='SPRITE_KURT' then wrap(world,obj.scriptKey,PREFIX..'kurt') end
      end
    elseif mapId=='ILEX_FOREST' then
      for _,ev in ipairs(world.maps[mapId].bgEvents or {}) do
        if ev.x==8 and ev.y==22 then wrap(world,ev.scriptKey,PREFIX..'shrine') end
      end
    end
  end
end
