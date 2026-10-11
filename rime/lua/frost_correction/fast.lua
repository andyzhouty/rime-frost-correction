-- Compare genuine dictionary/sentence weights, never frontend quality offsets.
local M = {}
local ContextModel=require('frost_correction.context_model')
local Channel=require('frost_correction.channel_v1')
local Repair=require('frost_correction.keyboard_repair')
local positions, neighbours = {}, {}
for row, spec in ipairs({{'qwertyuiop',0},{'asdfghjkl',0.25},{'zxcvbnm',0.75}}) do
 for col=1,#spec[1] do positions[spec[1]:sub(col,col)]={col-1+spec[2],row-1} end
end
for a,p in pairs(positions) do
 neighbours[a]={}
 for b,q in pairs(positions) do
  if a~=b and (p[1]-q[1])^2+(p[2]-q[2])^2<=1.3^2 then neighbours[a][b]=true end
 end
end
local function raw_weight(cand)
 local genuine=cand:get_genuine()
 local phrase=genuine:to_phrase()
 if phrase then return phrase.weight end
 local sentence=genuine:to_sentence()
 return sentence and sentence.weight or nil
end
local function error_kind(input, spelling)
 if not spelling or not spelling:match('^[a-z ]+$') then return nil end
 local canonical=spelling:gsub(' ','')
 if canonical==input then return nil end
 -- A nasal change must be at the end of an actual canonical syllable.
 local words={}
 for word in spelling:gmatch('[a-z]+') do words[#words+1]=word end
 for i,word in ipairs(words) do
  local changed
  if word:match('ing$') or word:match('eng$') then changed=word:sub(1,-2)
  elseif word:match('in$') or word:match('en$') then changed=word..'g' end
  if changed then
   local old=words[i];words[i]=changed
   local match=table.concat(words)==input;words[i]=old
   if match then return 'nasal' end
  end
 end
 if #canonical==#input+1 then
  for i=1,#canonical do
   if canonical:sub(1,i-1)..canonical:sub(i+1)==input then return 'omission' end
  end
 end
 if #canonical~=#input then return nil end
 local diffs={}
 for i=1,#input do
  if input:sub(i,i)~=canonical:sub(i,i) then diffs[#diffs+1]=i end
 end
 if #diffs==1 then
  local i=diffs[1];local a=input:sub(i,i);local b=canonical:sub(i,i)
  if neighbours[a] and neighbours[a][b] then return 'neighbour' end
 elseif #diffs==2 and diffs[2]==diffs[1]+1 then
  local i=diffs[1]
  if input:sub(i,i)==canonical:sub(i+1,i+1) and input:sub(i+1,i+1)==canonical:sub(i,i) then return 'swap' end
 end
 return nil
end
local function memo_query(primary)
 local cache={}
 return {
  reset=function(self) cache={};self.capture=false end,
  has=function(self,input) return cache[input]~=nil end,
  set_capture=function(self,enabled) self.capture=enabled end,
  query=function(self,input,seg)
   local key=input
   local entry=cache[key]
   if not entry and not self.capture then return primary:query(input,seg) end
   if not entry then
    local source=primary:query(input,seg)
    if not source then return nil end
    local iter,state,control=source:iter()
    entry={items={},source=source,iter=iter,state=state,control=control,done=false}
    cache[key]=entry
   end
   return {iter=function()
    local index=0
    return function()
     index=index+1
     if entry.items[index] then return entry.items[index] end
     if entry.done then return nil end
     local candidate=entry.iter(entry.state,entry.control)
     entry.control=candidate
     if not candidate then entry.done=true;return nil end
     entry.items[index]=candidate
     return candidate
    end,nil,nil
   end}
  end
 }
end
local function coarse_query(translator,primary,limit,limited)
 return {query=function(self,input,seg)
  local source=translator:query(input,seg)
  if not source then return nil end
  local spellings,seen={},{};local scanned=0
  for candidate in source:iter() do
   scanned=scanned+1
   local spelling=(candidate.comment or ''):gsub('[^a-z ]','')
   local canonical=spelling:gsub(' ','')
   if candidate._end==seg._end and error_kind(input,spelling) and not seen[canonical] then
    seen[canonical]=true;spellings[#spellings+1]={input=canonical,spelling=spelling,kind=error_kind(input,spelling),cost=select(2,spelling:gsub('[a-z]+',''))}
    if #spellings>=(#input>=16 and limit or 4) then break end
   end
   if scanned>=24 then break end
  end
  return {iter=function()
   return coroutine.wrap(function()
    local texts={}
    for _,v in ipairs(spellings) do
     local decoder=Channel.limited(input,v) and not primary:has(v.input) and limited or primary
     local ranked=decoder:query(v.input,seg)
     if ranked then
      local scanned,accepted=0,0
      for candidate in ranked:iter() do
       scanned=scanned+1
       if candidate._end==seg._end+#v.input-#input and (candidate.comment or ''):gsub('[^a-z]','')==v.input and not texts[candidate.text] then
        texts[candidate.text]=true;accepted=accepted+1
        local shadow=ShadowCandidate(candidate,'coarse_repair',candidate.text,v.spelling,true)
        shadow._end=seg._end;shadow.preedit=input;candidate:get_genuine().preedit=input
        coroutine.yield(shadow)
       end
       if accepted>=8 or scanned>=16 then break end
      end
     end
    end
   end),nil,nil
  end}
 end}
end
local function edit_distance(a,b)
 if math.abs(#a-#b)>2 then return 3 end
 local previous,older={},nil
 for j=0,#b do previous[j]=math.min(j,3) end
 for i=1,#a do
  local current={[0]=math.min(i,3)}
  for j=math.max(1,i-2),math.min(#b,i+2) do
   local cost=a:sub(i,i)==b:sub(j,j) and 0 or 1
   local value=math.min((previous[j] or 3)+1,(current[j-1] or 3)+1,(previous[j-1] or 3)+cost,3)
   if older and j>1 and a:sub(i,i)==b:sub(j-1,j-1) and a:sub(i-1,i-1)==b:sub(j,j) then
    value=math.min(value,(older[j-2] or 3)+1)
   end
   current[j]=value
  end
  older,previous=previous,current
 end
 return previous[#b] or 3
end
function M.init(env)
 env.primary=Component.Translator(env.engine,'translator','script_translator')
 env.repair_limited=memo_query(Component.Translator(env.engine,'repair_limited','script_translator'))
 env.metadata=Component.Translator(env.engine,'repair_metadata','script_translator')
 env.repair_primary=memo_query(Component.Translator(env.engine,'repair_primary','script_translator'))
 local config=env.engine.schema.config
 local saved=config:get_item('grammar')
 config:set_map('grammar',ConfigMap())
 local coarse_extra=Component.Translator(env.engine,'typo','script_translator')
 local coarse_omission=Component.Translator(env.engine,'omission','script_translator')
 config:set_item('grammar',saved)
 env.extra=coarse_query(coarse_extra,env.repair_primary,6,env.repair_limited)
 env.omission=coarse_query(coarse_omission,env.repair_primary,6,env.repair_limited)
 env.gain=config:get_double('typo_rank/min_gain') or 6
 env.nasal_gain=config:get_double('typo_rank/nasal_gain') or 4
 env.word_gap=config:get_double('typo_rank/word_alt_gap') or 2.5
 env.sentence_gap=config:get_double('typo_rank/sentence_alt_gap') or 3
 env.context_gain=config:get_double('typo_rank/context_gain') or 6
 env.context_model=ContextModel.open(rime_api.get_user_data_dir()..'/'..(env.engine.schema.config:get_string('correction/context_model') or 'wanxiang-lts-zh-hans')..'.gram')
end
function M.func(input,seg,env)
 env.repair_primary:reset();env.repair_limited:reset()
 local original=env.primary:query(input,seg)
 local iter,state,control
 if original then iter,state,control=original:iter()
 else iter=function() return nil end end
 local first=iter(state,control)
 -- An invalid initial syllable can yield no native candidate at all.
 -- Keep the normal repair search available; never emit the empty anchor.
 local empty_anchor=not first
 if empty_anchor then
  first=Candidate('repair_anchor',seg.start,seg._end,'','')
  first.quality=0
 end
 local seen={[first.text]=true};local extras={};local deferred={};local promoted
 local base_weight=raw_weight(first)
 local full=not empty_anchor and first._end==seg._end
 -- Complete exact words, learned words and explicit syllable boundaries win.
 local protect=full and (first.type~='sentence' or input:find("'",1,true))
 if protect then require('frost_correction.rank').func(input,seg,env,{iter=iter,state=state,control=control,first=first});return end
 local valid_input
 local function valid_once()
  if valid_input==nil then valid_input=Repair.valid(input) end
  return valid_input
 end
 local best_score=-math.huge
 if #input>=4 and input:match("^[a-z']+$") then
  local queries={{translator=env.extra,input=input},{translator=env.omission,input=input}}
  if not input:find("'",1,true) then
   for query_index,v in ipairs(Repair.variants(input)) do if query_index>(not full and 32 or #input>=16 and 24 or 16) then break end;queries[#queries+1]={translator=env.repair_primary,input=v.input,repair=true,kind=v.kind,channel_limited=Channel.limited(input,v)} end
  end
  local collapsed_seen={};local collapsed_count=0
  for i=2,#input do
   if input:sub(i,i)==input:sub(i-1,i-1) and input:sub(i,i):match('[a-z]') then
    local collapsed=input:sub(1,i-1)..input:sub(i+1)
    if not collapsed_seen[collapsed] and collapsed_count<2 then
     collapsed_seen[collapsed]=true;collapsed_count=collapsed_count+1
     queries[#queries+1]={translator=env.metadata,input=collapsed,duplicate=true}
    end
   end
  end
  for _,query in ipairs(queries) do
  if query.channel_limited and not env.repair_primary:has(query.input) then query.translator=env.repair_limited end
  env.repair_primary:set_capture(query.translator==env.extra or query.translator==env.omission)
  env.repair_limited:set_capture(query.translator==env.extra or query.translator==env.omission)
  local expansion=query.translator:query(query.input,seg)
  if expansion then
   local count=0;local found_full=false;local collected=0
   for cand in expansion:iter() do
    count=count+1
    local exact_repair=query.repair and cand._end==seg._end+#query.input-#input and cand.comment and cand.comment:gsub('[^a-z]','')==query.input
    local exact_duplicate=query.duplicate and cand._end==seg._end-1 and cand.preedit and cand.preedit:gsub("[ ']",'')==query.input and cand.comment and cand.comment:gsub('[^a-z]','')==query.input
    if (not query.duplicate and not query.repair and cand._end==seg._end or exact_duplicate or exact_repair) and not seen[cand.text] then
     found_full=true
     collected=collected+1
     local shadow=ShadowCandidate(cand,'typo_suggestion',cand.text,'≈',true)
     if exact_repair then shadow._end=seg._end;cand:get_genuine().preedit=input;shadow.preedit=input end
     if exact_duplicate then shadow._end=seg._end;cand:get_genuine().preedit=input;shadow.preedit=input end
     shadow.quality=first.quality-0.5
     local weight=raw_weight(cand)
     local kind=exact_repair and query.kind or exact_duplicate and 'duplicate' or error_kind(input,cand.comment)
     local penalty=kind=='secondary_nasal' and 6 or (kind=='nasal' or kind=='omission' or kind=='duplicate') and 3 or kind=='neighbour' and 2 or 1.5
     local score=weight and weight-penalty or -math.huge
     local context_delta=kind=='nasal' and not protect and env.context_model and env.context_model:contrast(first.text,cand.text,query.repair) or nil
     local context_override=context_delta and context_delta>=env.context_gain and base_weight and score-base_weight>=(query.repair and -4 or -8)
     local common=true
     if query.repair then for _,u in utf8.codes(cand.text) do if u>=0x20000 and u<=0x323af then common=false;break end end end
     local plausible=context_override or not base_weight or not full or (protect and weight and weight>=base_weight-env.word_gap) or (not protect and score>=base_weight-8)
     seen[cand.text]=true
     if kind and plausible and common and true then extras[#extras+1]={cand=shadow,score=score,order=#extras+1}
     elseif kind and #deferred<3 then
      shadow.quality=first.quality-0.75;deferred[#deferred+1]=shadow
     elseif #deferred<3 and cand.comment:match('^[a-z ]+$') then
      local canonical=cand.comment:gsub(' ','')
      if edit_distance(input,canonical)==2 then
       shadow.quality=first.quality-0.75;deferred[#deferred+1]=shadow
      end
     end
     local word_override=protect and first.type=='phrase' and (kind=='nasal' or kind=='duplicate') and not input:find("'",1,true) and cand:get_genuine():to_phrase() and base_weight and weight and weight-base_weight>=(kind=='duplicate' and 9 or 5)
     if (not protect or word_override) and weight and kind and kind~='secondary_nasal' then
      local penalty=kind=='secondary_nasal' and 6 or (kind=='nasal' or kind=='omission' or kind=='duplicate') and 3 or kind=='neighbour' and 2 or 1.5
      local score=weight-penalty
      local gain=kind=='nasal' and env.nasal_gain or env.gain
      if context_override then score=score+math.min(context_delta,12) end
      if (word_override or context_override or not full or base_weight and score-base_weight>=gain) and common and score>best_score+(query.repair and promoted and env.gain or 0) and (not query.repair or not valid_once() or kind=='nasal' and context_override) then
       best_score=score;promoted=shadow
      end
     end
     if collected>=(query.repair and 4 or 12) then break end
    elseif cand._end<(query.duplicate and seg._end-1 or seg._end) and found_full then break end
    if count>=(query.repair and 16 or 32) then break end
   end
  end
  end
 end
 -- A bounded supplement, with the confident correction occupying slot one.
 table.sort(extras,function(a,b) if a.score==b.score then return a.order<b.order end return a.score>b.score end)
 local displayed={[first.text]=true}
 local front_count=empty_anchor and 0 or 1;local deferred_shown=false
 if promoted then
  promoted.quality=first.quality+0.01;displayed[promoted.text]=true;front_count=front_count+1;yield(promoted)
 end
 if not empty_anchor then yield(first) end
 local shown=promoted and 1 or 0
 for _,item in ipairs(extras) do
  local cand=item.cand
  if cand~=promoted and shown<4 then
   displayed[cand.text]=true;front_count=front_count+1;yield(cand);shown=shown+1
  end
 end
 for cand in iter,state,first do
  -- Only suppress duplicates of candidates we actually displayed.
  if not displayed[cand.text] then
   displayed[cand.text]=true;front_count=front_count+1;yield(cand)
   if front_count>=6 and not deferred_shown then
    deferred_shown=true
    for _,item in ipairs(extras) do local extra=item.cand;if not displayed[extra.text] then displayed[extra.text]=true;yield(extra) end end
    for _,extra in ipairs(deferred) do
     if not displayed[extra.text] then displayed[extra.text]=true;yield(extra) end
    end
   end
  end
 end
end
function M.fini(env)if env.context_model then env.context_model:close() end;env.context_model=nil;env.primary=nil;env.repair_limited=nil;env.metadata=nil;env.repair_primary=nil;env.extra=nil;env.omission=nil end
return M
