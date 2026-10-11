local Base=require('frost_correction.eneng_repair')
local M={valid=Base.valid}
local syll={};for k,v in pairs(require('frost_correction.syllables')) do syll[k]=v end
syll.a=true;syll.o=true;syll.e=true
local function count(input)
 local reachable={[0]=0}
 for i=1,#input do for k=1,6 do
  local j=i-k
  if j>=0 and reachable[j] and syll[input:sub(j+1,i)] then
   reachable[i]=math.min(reachable[i] or 99,reachable[j]+1)
  end
 end end
 return reachable[#input]
end
M.whole_valid=function(input)return count(input)~=nil end
function M.variants(input)
 local out={};local seen={}
 for _,v in ipairs(Base.variants(input)) do out[#out+1]=v;seen[v.input]=true end
 if not Base.valid(input) then
  local added={}
  for i=1,#input-1 do
   if input:sub(i,i)~=input:sub(i+1,i+1) then
    local v=input:sub(1,i-1)..input:sub(i+1,i+1)..input:sub(i,i)..input:sub(i+2)
    local cost=count(v)
    if cost and not seen[v] then
     seen[v]=true;added[#added+1]={input=v,kind='boundary_swap',cost=cost,length=2}
    end
   end
  end
  table.sort(added,function(a,b)if a.cost~=b.cost then return a.cost<b.cost end;return a.input<b.input end)
  for i=1,math.min(16,#added) do out[#out+1]=added[i] end
 end
 return out
end
return M
