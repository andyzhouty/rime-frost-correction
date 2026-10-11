-- Explicit prior model, not fitted to benchmark targets. P(observed|canonical).
-- Keep the old decoder's legal single-edit support; budget only literal queries.
local M={}
local syll=require('frost_correction.syllables')
local prior={nasal=.42,neighbour=.25,omission=.20,swap=.10,secondary_nasal=.03}
local pos={}
for row,s in ipairs({'qwertyuiop','asdfghjkl','zxcvbnm'}) do
 for i=1,#s do pos[s:sub(i,i)]={i+(row==2 and .25 or row==3 and .75 or 0),row} end
end
function M.score(observed,v)
 local probability=prior[v.kind] or .01
 if v.kind=='neighbour' then
  for i=1,#observed do
   local a,b=observed:sub(i,i),v.input:sub(i,i)
   if a~=b and pos[a] and pos[b] then
    local p,q=pos[a],pos[b]
    probability=probability*math.exp(-.5*((p[1]-q[1])^2+(p[2]-q[2])^2))
   end
  end
 end
 -- More syllables create more possible error locations; prefer compact parses.
 return math.log(probability)-.65*math.max(0,(v.cost or 1)-1)
end
function M.limited(input,v)
 -- Keep the principal nasal channel on the full decoder. Less plausible
 -- channels still run, with bounded native beam/number of sentences.
 return v.kind~='nasal' and M.score(input,v)<-3
end
function M.select(input,variants,limit,legacy_limit)
 local support={}
 for i=1,math.min(legacy_limit or 32,#variants) do support[i]=variants[i] end
 -- Invalid spelling has weak evidence: preserve the established recall search.
 local reachable={[0]=true}
 for i=1,#input do for k=2,6 do
  local j=i-k
  if j>=0 and reachable[j] and syll[input:sub(j+1,i)] then reachable[i]=true;break end
 end end
 if not reachable[#input] then return support end
 local ranked={}
 for _,v in ipairs(support) do ranked[#ranked+1]={value=v,score=M.score(input,v)} end
 table.sort(ranked,function(a,b)
  if a.score~=b.score then return a.score>b.score end
  return a.value.input<b.value.input
 end)
 local selected={}
 for i=1,math.min(limit,#ranked) do selected[ranked[i].value]=true end
 -- Nasal confusion is core coverage, not a discretionary low-probability tail.
 for _,v in ipairs(support) do if v.kind=='nasal' then selected[v]=true end end
 -- Existing promotion logic depends on query order; do not conflate that
 -- ranking change with the channel's choice of search support.
 local out={}
 for _,v in ipairs(support) do if selected[v] then out[#out+1]=v end end
 return out
end
return M
