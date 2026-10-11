-- Read-only access to the published Octagram/Darts grammar format.
-- This supplies local phrase evidence, not calibrated sentence probabilities.
local M={}
local function encoded(text)
 local out={}
 for _,u in utf8.codes(text) do
  if u<128 then out[#out+1]=string.char(u==0 and 224 or u)
  elseif u>=0x4000 and u<0xa000 then
   if u&255~=0 then out[#out+1]=string.char(64+(u>>8),u&255)
   else out[#out+1]=string.char(225,64+(u>>8)) end
  else
   local chunks={}
   repeat table.insert(chunks,1,(u&127)|128);u=u>>7 until u==0
   out[#out+1]=string.char(224|#chunks)..string.char(table.unpack(chunks))
  end
 end
 return table.concat(out)
end
function M.open(path)
 local f=io.open(path,'rb');if not f then return nil end
 local header=f:read(44)
 if not header or #header<44 or header:sub(1,17)~='Rime::Grammar/1.0' then f:close();return nil end
 local n,offset=string.unpack('<I4I4',header,37)
 local size=f:seek('end')
 if n==0 or offset+40+n*4>size then f:close();return nil end
 return setmetatable({file=f,n=n,offset=offset+40,pages={},page_count=0,cache={},cache_count=0},{__index=M})
end
function M:unit(i)
 if i<0 or i>=self.n then return nil end
 local page=i//1024;local data=self.pages[page]
 if not data then
  if self.page_count>=128 then self.pages={};self.page_count=0 end
  self.file:seek('set',self.offset+page*4096);data=self.file:read(math.min(4096,(self.n-page*1024)*4))
  if not data then return nil end
  self.pages[page]=data;self.page_count=self.page_count+1
 end
 return string.unpack('<I4',data,(i%1024)*4+1)
end
function M:lookup(text)
 local cached=self.cache[text];if cached~=nil then return cached~=false and cached or nil end
 local node=0;local u=self:unit(node);local value
 for c in encoded(text):gmatch('.') do
  node=node~((u>>10)<<((u&512)>>6))~c:byte();u=self:unit(node)
  if not u or u&0x800000ff~=c:byte() then u=nil;break end
 end
 if u and u&256~=0 then
  local leaf=self:unit(node~((u>>10)<<((u&512)>>6)))
  if leaf then value=(leaf&0x7fffffff)/10000 end
 end
 if self.cache_count>=4096 then self.cache={};self.cache_count=0 end
 self.cache[text]=value or false;self.cache_count=self.cache_count+1
 return value
end
local function chars(text)
 local out={};for _,u in utf8.codes(text) do out[#out+1]=utf8.char(u) end;return out
end
function M:contrast(base,target,strict)
 local a,b=chars(base),chars(target)
 if #a~=#b or #a<4 or #a>24 then return nil end
 local changes=0
 for i=1,#a do if a[i]~=b[i] then changes=changes+1 end end
 if changes==0 or changes>2 then return nil end
 -- Refuse a newly repeated nearby character introduced by correction.
 for i=1,#b do
  for j=i+1,math.min(#b,i+3) do
   if b[i]==b[j] and (a[i]~=b[i] or a[j]~=b[j]) and a[i]~=a[j] then return nil end
  end
 end
 local covered={};local starts={};local evidence=0
 -- A five-to-eight-character match must cover every changed character.
 for n=5,math.min(8,#b) do
  for i=1,#b-n+1 do
   local all=true;local touched=false
   for j=1,#b do
    if a[j]~=b[j] then
     touched=true;if j<i or j>=i+n or strict and j<#b and j==i+n-1 then all=false end
    end
   end
   if touched and all then
    local x=table.concat(a,'',i,i+n-1);local y=table.concat(b,'',i,i+n-1)
    local av=self:lookup(x) or 0;local bv=self:lookup(y)
    if bv and bv-av>=6 then evidence=math.max(evidence,bv-av) end
   end
  end
 end
 if evidence>0 then return evidence end
 -- Otherwise demand corroborating windows with distinct starting positions;
 -- a single frequent fragment is insufficient, and all edits must be covered.
 for n=3,4 do
  for i=1,#b-n+1 do
   local x=table.concat(a,'',i,i+n-1);local y=table.concat(b,'',i,i+n-1)
   if x~=y then
    local av=self:lookup(x) or 0;local bv=self:lookup(y)
    if bv and bv-av>=6 then
     starts[i]=true;evidence=math.max(evidence,bv-av)
     for j=i,i+n-1 do if a[j]~=b[j] and (not strict or j==#b or j<i+n-1) then covered[j]=true end end
    end
   end
  end
 end
 local count=0;for _ in pairs(starts) do count=count+1 end
 if count<2 then return nil end
 for j=1,#b do if a[j]~=b[j] and not covered[j] then return nil end end
 return evidence
end
function M:close()self.file:close() end
return M
