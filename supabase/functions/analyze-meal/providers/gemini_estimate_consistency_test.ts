import { normalizeGeminiEstimateResponse } from './normalize_v2.ts';
import { ProviderConfig, VisionProviderError } from './types.ts';
const config:ProviderConfig={provider:'gemini',model:'synthetic',apiKey:'synthetic',endpoint:'https://example.invalid'};
function parse(values:Record<string,number>,unit='g',quantity=100) {
  const nutrients=Object.fromEntries(Object.entries(values).map(([key,value])=>[key,{value,unit:'g'}]));
  const content={response_locale:'en',candidates:[{name:'Visible meal',confidence:.8,evidence:'Visible meal portion',
    amount:quantity,unit,alternatives:[],uncertainty:null,warnings:[],dish_identity:null,visible_components:[],
    estimate:{basis:{quantity,unit},nutrients,uncertainty:null}}]};
  return normalizeGeminiEstimateResponse({candidates:[{content:{parts:[{text:JSON.stringify(content)}]}}]},config,'en');
}
for(const [label,values] of [
  ['macro mass240g in100g basis',{protein:80,carbohydrates:80,fat:80}],
  ['saturated fat without total fat',{fat:0,saturatedFat:10}],
  ['fiber and sugar exceeding total carbohydrate',{carbohydrates:10,fiber:8,sugar:9}],
] as const) {
  Deno.test(`rejects ${label}`,()=>{
    let rejected=false;try{parse(values);}catch(error){rejected=error instanceof VisionProviderError && error.code==='malformed_response';}
    if(!rejected)throw new Error(`Accepted ${label}`);
  });
}
Deno.test('rounding, sparse unknown and trans overlap are retained without invented values',()=>{
  const rounded=parse({protein:30,carbohydrates:40,fat:31, fiber:5,sugar:35.1,saturatedFat:5,
    monounsaturatedFat:20,polyunsaturatedFat:5,transFat:3}).candidates[0].estimate.nutrients;
  if(rounded.calories!==null || rounded.fat!==31 || rounded.transFat!==3)throw new Error('Values were fabricated or changed');
  const sparse=parse({sodium:100},'piece',1).candidates[0].estimate.nutrients;
  if(sparse.protein!==null)throw new Error('Missing value invented');
});
Deno.test('count or volume has no invented gram mass budget',()=>{
  for(const unit of ['piece','ml'])parse({protein:80,carbohydrates:80,fat:80},unit,1);
});
Deno.test('known macro subset alone cannot exceed gram mass',()=>{
  let rejected=false;try{parse({protein:80,carbohydrates:80});}catch(error){rejected=error instanceof VisionProviderError;}
  if(!rejected)throw new Error('Unknown fat cannot hide an impossible known macro mass');
});
