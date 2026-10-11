-- Personal preference is earned by committed selections, never by the * marker.
-- Keep the native user dictionary and all existing guards intact.
local M={}
local stores={}
-- User-selected five-year half-life: roughly 1.13% loss per 30 days.
local HALF_LIFE=1825*86400
local function eligible(c,input)
 if not c or not input:match('^[a-z]+$') or c.start~=0 or c._end~=#input then return false end
 if (c.comment or ''):find('≈',1,true) or c.text:find('[%s%z\t\r\n]') or c.text:match('^[%w%p]+$') then return false end
 return c.type=='phrase' or c.type=='user_phrase' or c.type=='history_reference'
end
local function decay(r,now)
 return math.exp(-math.log(2)*math.max(0,now-r.updated)/HALF_LIFE)
end
local function score(r,now)
 return (r.strong+r.weak)*decay(r,now)
end
local function append(store,code,text,r)
 local f=io.open(store.path,'ab')
 if not f then log.warning('Personal preference could not be saved');return end
 -- A partial final line after interruption is ignored on the next load.
 local ok=f:write(string.format('%s\t%s\t%.6f\t%.6f\t%d\t%d\n',code,text,r.strong,r.weak,r.explicit,r.updated))
 f:close()
 if not ok then log.warning('Personal preference write failed')end
end
local function open_store()
 local path=rime_api.get_user_data_dir()..'/frost_correction_selection.tsv'
 if stores[path]then return stores[path]end
 local store={path=path,words={}};stores[path]=store
 local f=io.open(path,'rb');if not f then return store end
 for line in f:lines()do
  local code,text,strong,weak,explicit,updated=line:match('^([a-z]+)\t([^\t\r\n]+)\t([%d.]+)\t([%d.]+)\t(%d+)\t(%d+)$')
  if code then
   local r={strong=tonumber(strong),weak=tonumber(weak),explicit=tonumber(explicit),updated=tonumber(updated)}
   if r.strong and r.weak and r.explicit and r.updated and r.weak<=2 then
    store.words[code]=store.words[code]or{};store.words[code][text]=r
   end
  end
 end
 f:close();return store
end
local function snapshot(ctx)
 local input=ctx.input;local seg=ctx.composition:back();local c=ctx:get_selected_candidate()
 if not seg or seg.start~=0 or seg._end~=#input or not eligible(c,input)then return end
 return {code=input,text=c.text,active=seg.selected_index>0}
end
function M.init(env)
 env.store=open_store()
 env.select_connection=env.engine.context.select_notifier:connect(function(ctx)
  env.pending=snapshot(ctx)
 end)
 env.commit_connection=env.engine.context.commit_notifier:connect(function(ctx)
  local s=snapshot(ctx)or env.pending;env.pending=nil
  if not s or ctx.input~=s.code or ctx:get_commit_text()~=s.text then return end
  local now=os.time();local words=env.store.words[s.code]or{};env.store.words[s.code]=words
  local r=words[s.text]or{strong=0,weak=0,explicit=0,updated=now}
  local factor=decay(r,now);r.strong=r.strong*factor;r.weak=r.weak*factor
  if s.active then r.strong=r.strong+4;r.explicit=r.explicit+1
  else r.weak=math.min(2,r.weak+0.25)end
  r.updated=now;words[s.text]=r;append(env.store,s.code,s.text,r)
 end)
 env.delete_connection=env.engine.context.delete_notifier:connect(function(ctx)
  local s=snapshot(ctx);env.pending=nil
  if not s then return end
  local words=env.store.words[s.code];if not words or not words[s.text]then return end
  local r={strong=0,weak=0,explicit=0,updated=os.time()};words[s.text]=r
  append(env.store,s.code,s.text,r)
 end)
end
function M.func(t,env)
 local iter,state,control=t:iter();local first=iter(state,control);if not first then return end
 local input=env.engine.context.input;local words=env.store.words[input]
 local best,best_score;local now=os.time()
 if words and eligible(first,input)then
  local first_score=words[first.text]and score(words[first.text],now)or 0
  for text,r in pairs(words)do
   local value=score(r,now)
   if text~=first.text and r.explicit>=3 and value>=8 and value>=first_score+2 and
      (not best_score or value>best_score or(value==best_score and text<best))then best=text;best_score=value end
  end
 end
 if not best then yield(first);for c in iter,state,first do yield(c)end;return end
 local buffer={first};control=first;local found
 for i=2,32 do
  local c=iter(state,control);if not c then break end
  control=c;buffer[#buffer+1]=c
  if c.text==best and eligible(c,input)then found=#buffer;break end
 end
 if found then
  local c=buffer[found];local promoted=ShadowCandidate(c,c.type,c.text,c.comment or '',true)
  promoted.quality=first.quality+0.001;yield(promoted)
 end
 for i,c in ipairs(buffer)do if i~=found then yield(c)end end
 for c in iter,state,control do yield(c)end
end
function M.fini(env)
 for _,name in ipairs({'select_connection','commit_connection','delete_connection'})do
  if env[name]then env[name]:disconnect();env[name]=nil end
 end
 env.pending=nil;env.store=nil
end
return M
