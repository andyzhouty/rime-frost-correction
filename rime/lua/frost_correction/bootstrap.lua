local M = {}
function M.init(env)
  if env.engine.schema.config:get_bool('correction/generational_gc') then
    local ok = pcall(collectgarbage, 'generational')
    if not ok then log.warning('Generational GC requires Lua 5.4; original GC retained') end
  end
end
function M.func() return 2 end -- kNoop: normal processors continue.
return M
