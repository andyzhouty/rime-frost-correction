local M={}
local Repair=require('frost_correction.cross3_repair')
function M.init(env)
 env.translator=Component.Translator(env.engine,'repair_primary','script_translator')
end
function M.func(t,env)
 local iter,state,control=t:iter();local first=iter(state,control)
 if not first then return end
 yield(first)
 local ctx=env.engine.context;local input=ctx.input;local seg=ctx.composition:back()
 local alternatives={};local seen={[first.text]=true}
 if seg and seg.start==0 and seg._end==#input and first._end==seg._end and input:match('^[a-z]+$') and not Repair.valid(input) then
  for _,v in ipairs(Repair.variants(input)) do
   if v.kind=='boundary_swap' then
    local expansion=env.translator:query(v.input,seg)
    if expansion then
     local count=0
     for c in expansion:iter() do
      count=count+1
      if c._end==seg._end+#v.input-#input and c.comment and c.comment:gsub('[^a-z]','')==v.input and not seen[c.text] then
       local common=true
       for _,u in utf8.codes(c.text) do if u>=0x20000 and u<=0x323af then common=false;break end end
       if common then
        seen[c.text]=true
        local shadow=ShadowCandidate(c,'boundary_swap',c.text,'≈',true)
        shadow._end=seg._end;shadow.preedit=input;c:get_genuine().preedit=input
        shadow.quality=first.quality-0.01
        local genuine=c:get_genuine();local phrase=genuine:to_phrase()
        alternatives[#alternatives+1]={candidate=shadow,weight=phrase and phrase.weight or -math.huge}
       end
      end
      if count>=4 then break end
     end
    end
   end
  end
 end
 table.sort(alternatives,function(a,b)if a.weight~=b.weight then return a.weight>b.weight end;return a.candidate.text<b.candidate.text end)
 local emitted={[first.text]=true};local at=1;local native=1
 for c in iter,state,first do
  if not emitted[c.text] then
   emitted[c.text]=true;yield(c);native=native+1
   if native==2 or native==3 then
    while alternatives[at] and emitted[alternatives[at].candidate.text] do at=at+1 end
    if alternatives[at] then local extra=alternatives[at].candidate;emitted[extra.text]=true;yield(extra);at=at+1 end
   end
  end
 end
 for i=at,#alternatives do local extra=alternatives[i].candidate;if not emitted[extra.text] then emitted[extra.text]=true;yield(extra) end end
end
function M.fini(env)env.translator=nil end
return M
