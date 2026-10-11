-- One local keyboard edit, bounded queries; no input-specific vocabulary.
local M={}
local syll=require('frost_correction.syllables')
local map={}
local pos={}
for row,s in ipairs({{'qwertyuiop',0},{'asdfghjkl',.25},{'zxcvbnm',.75}}) do
 for i=1,#s[1] do pos[s[1]:sub(i,i)]={i+s[2],row} end
end
local function add(bad,good,kind)
 if #bad<1 then return end
 map[bad]=map[bad] or {};map[bad][good]=kind
end
for s in pairs(syll) do
 for i=1,#s do
  add(s:sub(1,i-1)..s:sub(i+1),s,'omission')
  local p=pos[s:sub(i,i)]
  if p then for c,q in pairs(pos) do
   if c~=s:sub(i,i) and (p[1]-q[1])^2+(p[2]-q[2])^2<=1.3^2 then add(s:sub(1,i-1)..c..s:sub(i+1),s,'neighbour') end
  end end
 end
 for i=1,#s-1 do if s:sub(i,i)~=s:sub(i+1,i+1) then add(s:sub(1,i-1)..s:sub(i+1,i+1)..s:sub(i,i)..s:sub(i+2),s,'swap') end end
 for _,pair in ipairs({{'an','ang'}}) do if s:sub(-#pair[1])==pair[1] then add(s..'g',s,'secondary_nasal') elseif s:sub(-#pair[2])==pair[2] then add(s:sub(1,-2),s,'secondary_nasal') end end
 if s:match('ing$') or s:match('eng$') then add(s:sub(1,-2),s,'nasal') elseif s:match('in$') or s:match('en$') then add(s..'g',s,'nasal') end
end
local cache={};local cached=0
function M.valid(input)
 local reachable={[0]=true}
 for i=1,#input do for k=2,6 do
  local j=i-k;if j>=0 and reachable[j] and syll[input:sub(j+1,i)] then reachable[i]=true;break end
 end end
 return reachable[#input] or false
end
function M.variants(input)
 if cache[input] then return cache[input] end
 local n=#input
 if n<4 or n>60 or not input:match('^[a-z]+$') then return {} end
 local prefix={[0]=0};local suffix={[n+1]=0}
 for i=1,n do for k=2,6 do
  local j=i-k;if j>=0 and prefix[j] and syll[input:sub(j+1,i)] then prefix[i]=math.min(prefix[i] or 99,prefix[j]+1) end
 end end
 for i=n,1,-1 do for k=2,6 do
  local j=i+k;if j<=n+1 and suffix[j] and syll[input:sub(i,j-1)] then suffix[i]=math.min(suffix[i] or 99,suffix[j]+1) end
 end end
 local found={}
 for i=1,n do if prefix[i-1] then
  for k=1,6 do local j=i+k
   if j<=n+1 and suffix[j] then
    local bad=input:sub(i,j-1)
    for good,kind in pairs(map[bad] or {}) do
     local v=input:sub(1,i-1)..good..input:sub(j)
     if v~=input then
      local cost=prefix[i-1]+suffix[j]+1
      local prev=found[v]
      if not prev or cost<prev.cost then found[v]={input=v,kind=kind,cost=cost,length=#good} end
     end
    end
   end
  end
 end end
 local out={};for _,v in pairs(found) do out[#out+1]=v end
 table.sort(out,function(a,b)
  if a.cost~=b.cost then return a.cost<b.cost end
  if a.kind~=b.kind then return a.kind=='nasal' or b.kind~='nasal' and a.kind=='neighbour' end
  if a.length~=b.length then return a.length>b.length end
  return a.input<b.input
 end)
 while #out>64 do out[#out]=nil end
 if cached>=256 then cache={};cached=0 end
 cache[input]=out;cached=cached+1;return out
end
return M
