package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
local GV = require('src.core.GameVersion')
local Runtime = require('src.mods.Runtime')
GV.set('crystal')
local run = T.sdk.loadMod(MOD_PATH, {generation=2})
assert(#run.errors == 0, table.concat(run.errors, '\n'))
assert(run.mod and run.mod.status ~= 'failed', 'production loader activated mod')
local checks = 0
local function eq(a,b,label)
  checks=checks+1
  assert(a==b, label..': '..tostring(a)..' ~= '..tostring(b))
end
local function emit(name,payload)
  Runtime.emit(name,payload or {})
  eq(#Runtime.errors,0,'event callback succeeds')
end
local function fresh(v)
  return {version=v or 'crystal',generation=2,events={},inventory={},party={},hallOfFame={count=1}}
end
local game={save=fresh()}
run.loader.game=game
emit('game.ready',{game=game})
eq(game.save.crystal.gsBall,'have','ready enables native byte')
eq(next(game.save.inventory),nil,'no injected GS Ball')
eq(next(game.save.events),nil,'no changed event flags')
eq(#game.save.party,0,'no injected Celebi')
local state=game.save.crystal
emit('map.entered')
eq(game.save.crystal,state,'activation is idempotent')
game.save=fresh()
emit('map.entered')
eq(game.save.crystal.gsBall,'have','New Game / campaign arrival')
local loaded=fresh()
emit('save.loaded',{save=loaded})
eq(loaded.crystal.gsBall,'have','continue loaded save')
for _,v in ipairs({'red','blue','yellow','gold','silver','ruby','sapphire','firered','leafgreen','emerald'}) do
  game.save=fresh(v)
  emit('map.entered')
  emit('save.loaded',{save=game.save})
  eq(game.save.crystal,nil,v..' untouched')
end
for _,s in ipairs({'have','given','used','future-state'}) do
  game.save=fresh();game.save.crystal={gsBall=s,beasts={sentinel=true}}
  emit('map.entered')
  eq(game.save.crystal.gsBall,s,'preserve '..s)
  eq(game.save.crystal.beasts.sentinel,true,'preserve other state')
end
game.save=fresh();game.save.crystal={celebiCaught=true}
emit('map.entered')
eq(game.save.crystal.gsBall,nil,'caught event is not rearmed')
game.save=nil;emit('map.entered');emit('save.loaded',{})
for _,hall in ipairs({false,{}, {count=0}, {count=-1}, {count='bad'}, {entered=false,count=0}}) do
  game.save=fresh();game.save.hallOfFame=hall or nil
  emit('game.ready',{game=game})
  emit('map.entered')
  emit('save.loaded',{save=game.save})
  eq(game.save.crystal,nil,'pre-victory save stays locked')
end
game.save=fresh();game.save.hallOfFame={count=0}
emit('map.entered');eq(game.save.crystal,nil,'locked before first win')
require('src.core.gen2.HallOfFame').induct(game.save,{}, {saveFn=function() end})
emit('map.entered')
eq(game.save.crystal.gsBall,'have','native Hall of Fame induction unlocks on next map')
game.save=fresh();game.save.hallOfFame={entered=true,count=0}
emit('save.loaded',{save=game.save})
eq(game.save.crystal.gsBall,'have','imported Hall of Fame status qualifies')
print('Loader and lifecycle: '..checks..' assertions passed')

if not CACHE_PATH then
  print('Native cache tests SKIPPED: pass --cache to exercise imported scripts')
  run.release();return
end
local function cached(name)
  return assert(loadfile(CACHE_PATH..'/data/generated/'..name..'.lua'))()
end
local scripts,constants,maps=cached('scripts'),cached('constants'),cached('maps')
local Vm=require('src.script.gen2.Vm')
local Events=require('src.world.gen2.Events')
local Specials=require('src.script.gen2.Specials')
local Save=require('src.core.gen2.Save')
local BattleTower=require('src.core.gen2.BattleTower')
local center=assert(maps.GOLDENROD_POKECENTER_1F)
assert(center.coordEvents, 'native doorway coordinate events exist')
local doors=0
for _,coord in ipairs(center.coordEvents) do
  local entry=coord.scriptKey
  local list=scripts[entry]
  if list and list[1] and list[1].op=='setval' and list[1].args[1]==BattleTower.ACTIONS.GSBALL then
    doors=doors+1
    local record=fresh()
    game.save=record
    local events=Events.new()
    local given,moves,texts=0,0,0
    local vm=Vm.new(scripts,cached('text'),events,{
      showText=function(_,done) texts=texts+1;if done then done() end end,
      waitButton=function(done) done() end,
      applyMovement=function(_,_,done) moves=moves+1;done() end,
      giveItem=function(item,qty)
        eq(constants.itemOrder[item],'GS_BALL','native item is GS Ball')
        given=given+qty;return true
      end,
      specials={save=function() return record end},
    })
    vm.specialOrder=constants.specialOrder
    local function drive()
      assert(vm:start(entry))
      for _=1,1000 do if not vm:running() then break end;vm:update(1/60) end
      eq(vm:running(),false,'native scene finishes')
    end
    record.hallOfFame={count=0}
    emit('map.entered')
    drive();eq(given,0,'pre-Elite Four exit cannot deliver')
    eq(record.crystal and record.crystal.gsBall,nil,'pre-Elite Four exit cannot activate byte')
    require('src.core.gen2.HallOfFame').induct(record,{}, {saveFn=function() end})
    emit('map.entered')
    drive()
    eq(given,1,'native receptionist hands out one ball')
    eq(moves,2,'native receptionist approaches and departs')
    assert(texts>0,'native dialogue displayed')
    local receipt=scripts[list[3].script]
    assert(receipt,'delivery branch exists')
    for _,cmd in ipairs(receipt) do
      if cmd.op=='setevent' then eq(events:get(cmd.event),true,'native quest flag set') end
    end
    drive();eq(given,1,'repeated exit never duplicates delivery')
    emit('map.entered');drive();eq(given,1,'reenter never duplicates delivery')
  end
end
eq(doors,2,'both native exit tiles tested')
print('Native Crystal scripts: '..checks..' total assertions passed')
run.release()
