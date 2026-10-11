-- Keep the main model's first choice, then one independent model alternative.
-- No phrase lists, target spellings, or sample-specific conditions.
local M={}
local Fast=require('frost_correction.fast')
function M.init(env)
 local config=env.engine.schema.config
 local saved=config:get_item('grammar')
 config:set_map('grammar',ConfigMap())
 config:set_string('grammar/language','zh-moqi')
 config:set_double('grammar/non_collocation_penalty',-4)
 env.alt={primary=Component.Translator(env.engine,'secondary_primary','script_translator'),
  context_model=require('frost_correction.context_model').open(rime_api.get_user_data_dir()..'/'..(env.engine.schema.config:get_string('correction/context_model') or 'wanxiang-lts-zh-hans')..'.gram')}
 config:set_item('grammar',saved)
end
function M.func(t,env)
 local iter,state,control=t:iter();local first=iter(state,control)
 if not first then return end
 local ctx=env.engine.context;local seg=ctx.composition:back();local input=ctx.input
 local genuine=first:get_genuine()
 local protected=genuine:to_phrase() and not genuine:to_sentence()
 yield(first)
 if not protected and seg and seg.start==0 and seg._end==#input and first._end==seg._end and input:match('^[a-z]+$') then
  local alternative
  local translated=env.alt.primary:query(input,seg)
  if translated then for c in translated:iter() do alternative=c;break end end
  if alternative and alternative._end==seg._end and alternative.text~=first.text and alternative.text~='' then
   local shadow=ShadowCandidate(alternative,'model_alternative',alternative.text,alternative.comment,true)
   shadow.quality=first.quality-0.01
   yield(shadow)
  end
 end
 for candidate in iter,state,first do yield(candidate) end
end
function M.fini(env)
 if env.alt and env.alt.context_model then env.alt.context_model:close() end
 env.alt=nil
end
return M
