-- Consult a read-only system-dictionary reference only for starred first words.
-- Keep the learned entry available; do not delete, mutate or disable learning.
local M={}
function M.init(env)
 env.reference=Component.Translator(env.engine,'history_reference','script_translator')
end
function M.func(t,env)
 local iter,state,control=t:iter();local first=iter(state,control)
 if not first then return end
 local ctx=env.engine.context;local input=ctx.input;local seg=ctx.composition:back()
 local replacement
 if first.type=='user_phrase' and first.comment=='*' and seg and seg.start==0 and seg._end==#input and first.start==0 and first._end==#input and input:match('^[a-z]+$') then
  local reference=env.reference:query(input,seg)
  if reference then
   local riter,rstate,rcontrol=reference:iter();local base=riter(rstate,rcontrol)
   if base and base.type=='phrase' and base.start==0 and base._end==#input and base.text~=first.text then
    local comment=base.comment or ''
    if comment:match('^［.*］$')and comment:gsub('[^a-z]','')==input then comment=''end
    replacement=ShadowCandidate(base,'history_reference',base.text,comment,true)
    replacement.quality=first.quality+0.001;replacement.preedit=input
   end
  end
 end
 if replacement then yield(replacement)end
 yield(first)
 for c in iter,state,first do if not replacement or c.text~=replacement.text then yield(c)end end
end
function M.fini(env)env.reference=nil end
return M
