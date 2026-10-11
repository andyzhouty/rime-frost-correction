-- Hide redundant spelling annotations; retain history/correction/semantic hints.
local M={}
function M.func(t,env)
 local input=env.engine.context.input:gsub("[ ']+",'')
 for c in t:iter()do
  local comment=c.comment or ''
  local spelling=comment:match('^［([a-z ]+)］$')or comment:match('^%[([a-z ]+)%]$')
  if spelling and spelling:gsub(' ','')==input then
   -- A merged candidate can fall back to its underlying comment when empty.
   c=ShadowCandidate(c,c.type,c.text,' ',false)
  end
  yield(c)
 end
end
return M
