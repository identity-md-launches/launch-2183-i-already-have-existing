import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{t as r}from"./createLucideIcon-Cp5gDHSp.js";import{t as i}from"./check-B8o8ZNpi.js";import{t as a}from"./circle-x-CL_U3n9V.js";import{t as o}from"./hourglass-D308JFDA.js";import{i as s}from"./privy-context-Bxv3Wh-5-Cuby72dr.js";import{g as c}from"./esm-DsxEYfBg.js";import{n as l}from"./modal-context-CzyPCE1h-CI6R4GsA.js";import{c as u}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{t as d}from"./ScreenLayout-nGD4p5K0-CHY5CldX.js";import{t as f}from"./esm-CG_aiq74.js";import{d as p}from"./use-headless-crypto-deposit-DXuA2PzO-CUueyR-6.js";import{t as m}from"./lib-CB0iRLqZ.js";import{t as h}from"./InfoBanner-Cb3p1z12-DWrD6YP1.js";import{t as g}from"./CopyableText-CQapvaMr-D2qfp0B5.js";import{n as _,r as v,t as y}from"./SelectSourceAsset-BsJpnIhX-DHKD1UVZ.js";var b=r(`user-check`,[[`path`,{d:`m16 11 2 2 4-4`,key:`9rsbq5`}],[`path`,{d:`M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2`,key:`1yyitq`}],[`circle`,{cx:`9`,cy:`7`,r:`4`,key:`nufk8`}]]),x=n(),S=e(t(),1),C=e(m(),1),w=e=>{try{return e.location.origin}catch{return}},T=({data:e,onClose:t})=>(0,x.jsx)(d,{showClose:!0,onClose:t,title:`Initiate bank transfer`,subtitle:`Use the details below to complete a bank transfer from your bank.`,primaryCta:{label:`Done`,onClick:t},watermark:!1,footerText:`Exchange rates and fees are set when you authorize and determine the amount you receive. You'll see the applicable rates and fees for your transaction separately`,children:(0,x.jsx)(E,{children:(p[e.deposit_instructions.asset]||[]).map((([t,n],r)=>{let i=e.deposit_instructions[t];if(!i||Array.isArray(i))return null;let a=t===`asset`?i.toUpperCase():i,o=a.length>100?`${a.slice(0,9)}...${a.slice(-9)}`:a;return(0,x.jsxs)(D,{children:[(0,x.jsx)(O,{children:n}),(0,x.jsx)(g,{value:a,includeChildren:C.isMobile,children:(0,x.jsx)(k,{children:o})})]},r)}))})}),E=u.ol`
  border-color: var(--privy-color-border-default);
  border-width: 1px;
  border-radius: var(--privy-border-radius-mdlg);
  border-style: solid;
  display: flex;
  flex-direction: column;

  && {
    padding: 0 1rem;
  }
`,D=u.li`
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 0;

  &:not(:first-of-type) {
    border-top: 1px solid var(--privy-color-border-default);
  }

  & > {
    :nth-child(1) {
      flex-basis: 30%;
    }

    :nth-child(2) {
      flex-basis: 60%;
    }
  }
`,O=u.span`
  color: var(--privy-color-foreground);
  font-kerning: none;
  font-variant-numeric: lining-nums proportional-nums;
  font-feature-settings: 'calt' off;

  /* text-xs/font-regular */
  font-size: 0.75rem;
  font-style: normal;
  font-weight: 400;
  line-height: 1.125rem; /* 150% */

  text-align: left;
  flex-shrink: 0;
`,k=u.span`
  color: var(--privy-color-foreground);
  font-kerning: none;
  font-feature-settings: 'calt' off;

  /* text-sm/font-medium */
  font-size: 0.875rem;
  font-style: normal;
  font-weight: 500;
  line-height: 1.375rem; /* 157.143% */

  text-align: right;
  word-break: break-all;
`,A=({onClose:e})=>(0,x.jsx)(d,{showClose:!0,onClose:e,icon:a,iconVariant:`error`,title:`Something went wrong`,subtitle:`We couldn't complete account setup. This isn't caused by anything you did.`,primaryCta:{label:`Close`,onClick:e},watermark:!0}),j=({onClose:e,reason:t})=>{let n=t?t.charAt(0).toLowerCase()+t.slice(1):void 0;return(0,x.jsx)(d,{showClose:!0,onClose:e,icon:a,iconVariant:`error`,title:`Identity verification failed`,subtitle:n?`We can't complete identity verification because ${n}. Please try again or contact support for assistance.`:`We couldn't verify your identity. Please try again or contact support for assistance.`,primaryCta:{label:`Close`,onClick:e},watermark:!0})},M=({onClose:e,email:t})=>(0,x.jsx)(d,{showClose:!0,onClose:e,icon:o,title:`Identity verification in progress`,subtitle:`We're waiting for Persona to approve your identity verification. This usually takes a few minutes, but may take up to 24 hours.`,primaryCta:{label:`Done`,onClick:e},watermark:!0,children:(0,x.jsxs)(h,{theme:`light`,children:[`You'll receive an email at `,t,` once approved with instructions for completing your deposit.`]})}),N=({onClose:e,onAcceptTerms:t,isLoading:n})=>(0,x.jsx)(d,{showClose:!0,onClose:e,icon:b,title:`Verify your identity to continue`,subtitle:`Finish verification with Persona — it takes just a few minutes and requires a government ID.`,helpText:(0,x.jsxs)(x.Fragment,{children:[`This app uses Bridge to securely connect accounts and move funds. By clicking "Accept," you agree to Bridge's`,` `,(0,x.jsx)(`a`,{href:`https://www.bridge.xyz/legal`,target:`_blank`,rel:`noopener noreferrer`,children:`Terms of Service`}),` `,`and`,` `,(0,x.jsx)(`a`,{href:`https://www.bridge.xyz/legal/row-privacy-policy/bridge-building-limited`,target:`_blank`,rel:`noopener noreferrer`,children:`Privacy Policy`}),`.`]}),primaryCta:{label:`Accept and continue`,onClick:t,loading:n},watermark:!0}),P=({onClose:e})=>(0,x.jsx)(d,{showClose:!0,onClose:e,icon:i,iconVariant:`success`,title:`Identity verified successfully`,subtitle:`We've successfully verified your identity. Now initiate a bank transfer to view instructions.`,primaryCta:{label:`Initiate bank transfer`,onClick:()=>{},loading:!0},watermark:!0}),F=({opts:e,onClose:t,onBack:n,onEditSourceAsset:r,onSelectAmount:i,isLoading:a})=>(0,x.jsxs)(d,{showClose:!0,onClose:t,showBack:!!n,onBack:n,headerTitle:`Buy ${e.destination.asset.toLocaleUpperCase()}`,primaryCta:{label:`Continue`,onClick:i,loading:a},watermark:!0,children:[(0,x.jsx)(y,{currency:e.source.selectedAsset,inputMode:`decimal`,autoFocus:!0}),(0,x.jsx)(_,{selectedAsset:e.source.selectedAsset,onEditSourceAsset:r})]}),I=({onClose:e,onBack:t,onAcceptTerms:n,onSelectAmount:r,onSelectSource:i,onEditSourceAsset:a,opts:o,state:s,email:c,isLoading:l})=>s.status===`select-amount`?(0,x.jsx)(F,{onClose:e,onBack:t,onSelectAmount:r,onEditSourceAsset:a,opts:o,isLoading:l}):s.status===`select-source-asset`?(0,x.jsx)(v,{onSelectSource:i,opts:o,isLoading:l}):s.status===`kyc-prompt`?(0,x.jsx)(N,{onClose:e,onAcceptTerms:n,opts:o,isLoading:l}):s.status===`kyc-incomplete`?(0,x.jsx)(M,{onClose:e,email:c}):s.status===`kyc-success`?(0,x.jsx)(P,{onClose:e}):s.status===`kyc-error`?(0,x.jsx)(j,{onClose:e,reason:s.reason}):s.status===`account-details`?(0,x.jsx)(T,{onClose:e,data:s.data}):s.status===`create-customer-error`||s.status===`get-customer-error`?(0,x.jsx)(A,{onClose:e}):null,L={component:()=>{let{user:e}=s(),t=l().data;if(!t?.FundWithBankDepositScreen)throw Error(`Missing data`);let{onSuccess:n,onFailure:r,onBack:i,opts:a,createOrUpdateCustomer:o,getCustomer:u,getOrCreateVirtualAccount:d}=t.FundWithBankDepositScreen,[p,m]=(0,S.useState)(a),[h,g]=(0,S.useState)({status:`select-amount`}),[_,v]=(0,S.useState)(null),[y,b]=(0,S.useState)(!1),C=(0,S.useRef)(null),T=(0,S.useCallback)((async()=>{let e;b(!0),v(null);try{e=await u({kycRedirectUrl:window.location.origin})}catch(e){if(!e||typeof e!=`object`||!(`status`in e)||e.status!==404)return g({status:`get-customer-error`}),v(e),void b(!1)}if(!e)try{e=await o({hasAcceptedTerms:!1,kycRedirectUrl:window.location.origin})}catch(e){g({status:`create-customer-error`}),v(e),b(!1);return}if(!e)return g({status:`create-customer-error`}),v(Error(`Unable to create customer`)),void b(!1);if(e.status===`not_started`&&e.kyc_url)return g({status:`kyc-prompt`,kycUrl:e.kyc_url}),void b(!1);if(e.status===`not_started`)return g({status:`get-customer-error`}),v(Error(`Unexpected user state`)),void b(!1);if(e.status===`rejected`)return g({status:`kyc-error`,reason:e.rejection_reasons?.[0]?.reason}),v(Error(`User KYC rejected.`)),void b(!1);if(e.status===`incomplete`)return g({status:`kyc-incomplete`}),void b(!1);if(e.status!==`active`)return g({status:`get-customer-error`}),v(Error(`Unexpected user state`)),void b(!1);e.status;try{let e=await d({destination:p.destination,provider:p.provider,source:{asset:p.source.selectedAsset}});g({status:`account-details`,data:e})}catch(e){g({status:`create-customer-error`}),v(e),b(!1);return}}),[p]),E=(0,S.useCallback)((async()=>{if(v(null),b(!0),h.status!==`kyc-prompt`)return v(Error(`Unexpected state`)),void b(!1);let e=f({location:h.kycUrl});if(await o({hasAcceptedTerms:!0}),!e)return v(Error(`Unable to begin kyc flow.`)),b(!1),void g({status:`create-customer-error`});C.current=new AbortController;let t=await(async(e,t)=>{let n=await c({operation:async()=>({done:w(e)===window.location.origin,closed:e.closed}),until:({done:e,closed:t})=>e||t,delay:0,interval:500,attempts:360,signal:t});return n.status===`aborted`?(e.close(),{status:`aborted`}):n.status===`max_attempts`?{status:`timeout`}:n.result.done?(e.close(),{status:`redirected`}):{status:`closed`}})(e,C.current.signal);if(t.status===`aborted`)return;if(t.status===`closed`)return void b(!1);t.status;let n=await c({operation:()=>u({}),until:e=>e.status===`active`||e.status===`rejected`,delay:0,interval:2e3,attempts:60,signal:C.current.signal});if(n.status!==`aborted`){if(n.status===`max_attempts`)return g({status:`kyc-incomplete`}),void b(!1);if(n.status,n.result.status===`rejected`)return g({status:`kyc-error`,reason:n.result.rejection_reasons?.[0]?.reason}),v(Error(`User KYC rejected.`)),void b(!1);if(n.result.status!==`active`)return g({status:`kyc-incomplete`}),void b(!1);e.closed||e.close(),n.result.status;try{g({status:`kyc-success`});let e=await d({destination:p.destination,provider:p.provider,source:{asset:p.source.selectedAsset}});g({status:`account-details`,data:e})}catch(e){g({status:`create-customer-error`}),v(e)}finally{b(!1)}}}),[g,v,b,o,d,h,p,C]),D=(0,S.useCallback)((e=>{g({status:`select-amount`}),m({...p,source:{...p.source,selectedAsset:e}})}),[g,m]),O=(0,S.useCallback)((()=>{g({status:`select-source-asset`})}),[g]);return(0,x.jsx)(I,{onClose:(0,S.useCallback)((async()=>{C.current?.abort(),!p.showBackButton||h.status!==`select-amount`&&h.status!==`select-source-asset`?_?r(_):await n():r(Error(`User cancelled funding`))}),[_,C,r,n,p.showBackButton,h.status]),onBack:i,opts:p,state:h,isLoading:y,email:e.email.address,onAcceptTerms:E,onSelectAmount:T,onSelectSource:D,onEditSourceAsset:O})}};export{L as FundWithBankDepositScreen,L as default};