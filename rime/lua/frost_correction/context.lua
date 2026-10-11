-- Only strong corpus evidence may promote the independent model alternative.
local M={}
local Dual=require('frost_correction.dual')
local Fast=require('frost_correction.fast')
M.init=Dual.init
M.fini=Dual.fini
function M.func(t,env)
 local iter,state,control=t:iter();local first=iter(state,control)
 if not first then return end
 local ctx=env.engine.context;local seg=ctx.composition:back();local input=ctx.input
 local genuine=first:get_genuine()
 local protected=genuine:to_phrase() and not genuine:to_sentence()
 local shadow,promote
 if not protected and seg and seg.start==0 and seg._end==#input and first._end==seg._end and input:match('^[a-z]+$') then
  local alternative
  local corrected=input
  if first.comment=='≈' then
   local spelling=(genuine.comment or ''):gsub('[^a-z]','')
   if #spelling>=4 then corrected=spelling end
  end
  local translated=env.alt.primary:query(corrected,seg)
  if translated then for c in translated:iter() do alternative=c;break end end
  if alternative and alternative._end==seg._end+#corrected-#input and alternative.text~=first.text and alternative.text~='' then
   shadow=ShadowCandidate(alternative,'model_alternative',alternative.text,corrected~=input and '≈' or alternative.comment,true)
   if corrected~=input then shadow._end=seg._end;shadow.preedit=input;alternative:get_genuine().preedit=input end
   if corrected==input and (alternative.comment or ''):match('^［.*］$') and alternative.comment:gsub('[^a-z]','')==input then shadow.comment='' end
   local evidence=env.alt.context_model and env.alt.context_model:contrast(first.text,alternative.text)
   promote=evidence and evidence>=6
   shadow.quality=first.quality+(promote and 0.01 or -0.01)
  end
 end
 if promote then yield(shadow);yield(first)
 else yield(first);if shadow then yield(shadow) end end
 for candidate in iter,state,first do yield(candidate) end
end
return M
