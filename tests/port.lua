-- Uses each game's own imported maps, items and species, production mod loader,
-- native script VM, real world coordinate dispatch, object ownership, daily
-- reset, inventory and scripted battle construction. Presentation is headless.
if not CACHE_PATH then print('Gold/Silver cache tests SKIPPED');return end
local T=require('tests.modkit')
local GV=require('src.core.GameVersion')
local Runtime=require('src.mods.Runtime')
local Vm=require('src.script.gen2.Vm')
local World=require('src.world.gen2.World')
local Events=require('src.world.gen2.Events')
local Save=require('src.core.gen2.Save')
local Serializer=require('src.core.SaveSerializer')
local Apricorns=require('src.core.gen2.Apricorns')
local Bag=require('src.inventory.Bag')
local checks=0
local function eq(a,b,label)
  checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b))
end
local base=CACHE_PATH:match('^(.*)/[^/]+$')
for _,version in ipairs({'gold','silver'}) do
  GV.set(version)
  local function cached(name)
    return assert(loadfile(base..'/'..version..'/data/generated/'..name..'.lua'))()
  end
  local run=T.sdk.loadMod(MOD_PATH,{generation=2})
  eq(#run.errors,0,version..' production loader')
  local data=run.data
  data.items=cached('items');data.pokemon=cached('pokemon');data.moves=cached('moves')
  local game={data=data,save=Save.newGame()}
  local world=setmetatable({game=game,maps=cached('maps'),scripts=cached('scripts'),
    constants=cached('constants'),events=Events.new(),scriptVars={},mapScenes={},
    preparingLiveMaps=true,player={cellX=3,cellY=7},npcs={}}, {__index=World})
  game.world=world;run.loader.game=game
  local outcome,accept,moves,battles,reloads='caught',true,{},0,0
  local texts={}
  local vm=Vm.new(world.scripts,cached('text'),world.events,{
    commands=data.commands,
    showText=function(body,done) texts[#texts+1]=body;done() end,
    yesorno=function(done) done(accept) end,
    applyMovement=function(object,bytes,done)
      eq(world:objectEntity(object)~=nil or object>5,true,'movement addresses receptionist')
      moves[#moves+1]={object=object,bytes=bytes};done()
    end,
    turnObject=function() end,
    startBattle=function(trainer,wild,done) world:startScriptedBattle(trainer,wild,done) end,
    reloadMap=function(setup) eq(setup,true,'native field setup after scripted battle');reloads=reloads+1 end,
    getEngineFlag=function(id) return world:engineFlag(id) end,
    setEngineFlag=function(id,v) world:setEngineFlag(id,v) end,
  })
  world.vm=vm
  world.startBattle=function(_,opts,done)
    battles=battles+1
    eq(opts.wild.species,'CELEBI','native battle builds Celebi')
    eq(opts.wild.level,30,'native battle level 30')
    assert(opts.wild.stats and #opts.wild.moves>0,'native stats and moves')
    done(outcome)
  end
  local function emit(name,payload)
    Runtime.emit(name,payload or {})
    eq(#Runtime.errors,0,'no mod callback errors')
  end
  local function enter(id)
    world.map={id=id,def=world.maps[id]}
    emit('map.entered',{mapId=id})
  end
  local function drive(key)
    assert(vm:start(key),'script starts '..tostring(key))
    for _=1,1000 do if not vm:running() then break end;vm:update() end
    eq(vm:running(),false,'script completed')
    eq(next(vm.failedVerbs or {}),nil,'no failed custom commands')
    eq(next(vm.unknownVerbs or {}),nil,'no unknown custom commands')
    eq(next(vm.unknownOps or {}),nil,'no unknown native commands')
  end
  local function quest() return game.save.modData.crystal_gs_ball.gsPort end
  local function roundtrip()
    game.save=assert(loadstring(Serializer.encode(game.save)))()
    emit('save.loaded',{save=game.save})
  end
  enter('GOLDENROD_POKECENTER_1F')
  eq(#world.map.def.coordEvents,0,'pre-Elite Four no delivery triggers')
  eq((game.save.crystal and game.save.crystal.gsBall),nil,'Gold/Silver never activate Crystal byte')
  game.save.hallOfFame={count=1}
  enter('GOLDENROD_POKECENTER_1F')
  eq(#world.map.def.coordEvents,2,'both exits installed after victory')
  enter('GOLDENROD_POKECENTER_1F')
  eq(#world.map.def.coordEvents,2,'map rebinding does not duplicate triggers')
  -- Force a full key-item pocket and verify that failed delivery is retryable.
  for i=1,25 do
    local id='TEST_KEY_'..i
    data.items[id]={id=id,name=id,pocket='KEY_ITEM'}
    game.save.inventory[id]=1
  end
  local key=world.map.def.coordEvents[1].scriptKey
  drive(key)
  eq(game.save.inventory.ITEM_73,nil,'full pocket refuses delivery')
  eq(game.save.modData and game.save.modData.crystal_gs_ball,nil,'full pocket does not advance quest')
  eq(#world.maps.GOLDENROD_POKECENTER_1F.objects,4,'temporary receptionist cleaned up')
  for i=1,25 do game.save.inventory['TEST_KEY_'..i]=nil end
  -- Native coordinate dispatch, rather than calling the command directly.
  world.player.cellX=4
  assert(world:tryCoordScript(),'right doorway triggers native coordinate dispatch')
  eq(vm:running(),false,'door scene returns')
  eq(game.save.inventory.ITEM_73,1,'one GS Ball delivered')
  eq(quest().stage,'have','delivery saved')
  eq(data.items.ITEM_73.pocket,'KEY_ITEM','GS Ball goes in native key-item pocket')
  eq(data.items.ITEM_73.canToss,false,'GS Ball cannot be tossed')
  eq(#world.map.def.coordEvents,0,'successful delivery removes exit triggers')
  eq(#world.map.def.objects,4,'no persistent receptionist obstruction')
  eq(#moves,4,'both failed and successful delivery approach/depart')
  roundtrip()
  eq(quest().stage,'have','delivery persists through save roundtrip')
  enter('KURTS_HOUSE')
  local kurt=world.map.def.objects[1].scriptKey
  local wrapper=world.scripts[kurt]
  eq(wrapper[1][1],'crystal_gs_ball:port:kurt','Kurt is routed through quest')
  enter('KURTS_HOUSE')
  eq(world.scripts[kurt],wrapper,'Kurt wrapper is not nested on reentry')
  -- A marker on the preserved native script proves fallback dispatch.
  local nativeKey=wrapper[2].script
  local original=world.scripts[nativeKey]
  local vanilla=0
  data.commands.testVanilla=function() vanilla=vanilla+1;return 'end' end
  world.scripts[nativeKey]={{'testVanilla'}}
  drive(kurt);eq(vanilla,1,'Kurt introduction remains reachable')
  world.events:set(43,true);world.events:set(53,true)
  world.events:set(600,true)
  drive(kurt);eq(vanilla,2,'pending apricorn reward takes priority')
  eq(quest().stage,'have','pending apricorn never consumed')
  world.events:set(600,false)
  world:setEngineFlag(79,true)
  drive(kurt);eq(vanilla,3,'unfinished apricorn takes priority')
  world:setEngineFlag(79,false)
  drive(kurt)
  eq(quest().stage,'studying','Kurt accepts ball')
  eq(game.save.inventory.ITEM_73,nil,'Kurt takes GS Ball from bag')
  eq(world:engineFlag(79),true,'Kurt uses native daily wait flag')
  drive(kurt);eq(quest().stage,'studying','cannot skip same-day wait')
  roundtrip();eq(quest().stage,'studying','Kurt wait persists across reload')
  Apricorns.dailyReset(game.save)
  drive(kurt)
  eq(quest().stage,'shrine','native daily reset unlocks return')
  eq(game.save.inventory.ITEM_73,1,'Kurt returns the ball once')
  drive(kurt);eq(game.save.inventory.ITEM_73,1,'repeat Kurt chat never duplicates ball')
  world.scripts[nativeKey]=original
  enter('ILEX_FOREST')
  local shrine
  for _,ev in ipairs(world.map.def.bgEvents) do if ev.x==8 and ev.y==22 then shrine=ev.scriptKey end end
  assert(shrine,'actual Gold/Silver shrine interaction exists')
  accept=false;drive(shrine)
  eq(quest().stage,'shrine','declining shrine keeps quest state')
  eq(game.save.inventory.ITEM_73,1,'declining shrine keeps ball')
  accept=true;outcome='draw';drive(shrine)
  eq(quest().stage,'placed','running from Celebi leaves retry')
  eq(game.save.inventory.ITEM_73,nil,'shrine consumes ball once')
  outcome='win';drive(shrine);eq(quest().stage,'placed','fainted Celebi can be retried')
  roundtrip();outcome='lose';drive(shrine)
  eq(quest().stage,'placed','whiteout leaves shrine retryable')
  outcome='caught';drive(shrine)
  eq(quest().stage,'caught','capture completes quest')
  eq(reloads,battles,'every battle restores field through native reload hook')
  local prior=battles
  drive(shrine);eq(battles,prior,'completed shrine never spawns duplicate Celebi')
  roundtrip();drive(shrine);eq(battles,prior,'completed quest remains done after reload')
  enter('GOLDENROD_POKECENTER_1F')
  eq(#world.map.def.coordEvents,0,'completed save never redelivers GS Ball')
  eq((game.save.crystal and game.save.crystal.gsBall),nil,'Gold/Silver keep native Crystal gate untouched')
  run.release()
end
print('Gold/Silver quest port: '..checks..' assertions passed')
