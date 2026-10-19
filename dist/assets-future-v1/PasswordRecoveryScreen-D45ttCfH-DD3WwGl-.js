import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{$ as r,a as i,i as a}from"./privy-context-Bxv3Wh-5-Cuby72dr.js";import{n as o}from"./modal-context-CzyPCE1h-CI6R4GsA.js";import{c as s,s as c}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{a as l}from"./ModalFooter-CmGY3GN5-D-y9DoW2.js";import{t as u}from"./Screen-DZNhZC2N-qpvtz8l2.js";import{p as d}from"./errors-BQ3N-RVt-CZPAWCgC.js";import{A as f}from"./index-CqvyXQur-DV07a8Dd.js";import{a as p,h as m,i as h,p as g,s as _}from"./shared-CFJrjgWW-BBuMbVpb.js";import{t as v}from"./ShieldCheckIcon-DGN1Pl73.js";import{a as y}from"./Layouts-BMRfo5hw-BXZv4R83.js";var b=n(),x=e(t(),1),S={component:()=>{let[e,t]=(0,x.useState)(!0),{authenticated:n,user:s}=a(),{walletProxy:c,closePrivyModal:l,createAnalyticsEvent:S,client:E}=r(),{navigate:D,data:O,onUserCloseViaDialogOrKeybindRef:k}=o(),[A,j]=(0,x.useState)(void 0),[M,N]=(0,x.useState)(``),[P,F]=(0,x.useState)(!1),{entropyId:I,entropyIdVerifier:L,onCompleteNavigateTo:R,onSuccess:z,onFailure:B}=O.recoverWallet,V=(e=`User exited before their wallet could be recovered`)=>{l({shouldCallAuthOnSuccess:!1}),B(typeof e==`string`?new d(e):e)};return k.current=V,(0,x.useEffect)((()=>{if(!n)return V(`User must be authenticated and have a Privy wallet before it can be recovered`)}),[n]),(0,b.jsxs)(u,{children:[(0,b.jsx)(u.Header,{icon:v,title:`Enter your password`,subtitle:`Please provision your account on this new device. To continue, enter your recovery password.`,showClose:!0,onClose:V}),(0,b.jsx)(u.Body,{children:(0,b.jsx)(C,{children:(0,b.jsxs)(`div`,{children:[(0,b.jsxs)(h,{children:[(0,b.jsx)(p,{type:e?`password`:`text`,onChange:e=>(e=>{e&&j(e)})(e.target.value),disabled:P,style:{paddingRight:`2.3rem`}}),(0,b.jsx)(m,{style:{right:`0.75rem`},children:e?(0,b.jsx)(g,{onClick:()=>t(!1)}):(0,b.jsx)(_,{onClick:()=>t(!0)})})]}),!!M&&(0,b.jsx)(w,{children:M})]})})}),(0,b.jsxs)(u.Footer,{children:[(0,b.jsx)(u.HelpText,{children:(0,b.jsxs)(y,{children:[(0,b.jsx)(`h4`,{children:`Why is this necessary?`}),(0,b.jsx)(`p`,{children:`You previously set a password for this wallet. This helps ensure only you can access it`})]})}),(0,b.jsx)(u.Actions,{children:(0,b.jsx)(T,{loading:P||!c,disabled:!A,onClick:async()=>{F(!0);let e=await E.getAccessToken(),t=i(s,I);if(!e||!t||A===null)return V(`User must be authenticated and have a Privy wallet before it can be recovered`);try{S({eventName:`embedded_wallet_recovery_started`,payload:{walletAddress:t.address}}),await c?.recover({accessToken:e,entropyId:I,entropyIdVerifier:L,recoveryPassword:A}),N(``),R?D(R):l({shouldCallAuthOnSuccess:!1}),z?.(t),S({eventName:`embedded_wallet_recovery_completed`,payload:{walletAddress:t.address}})}catch(e){f(e)?N(`Invalid recovery password, please try again.`):N(`An error has occurred, please try again.`)}finally{F(!1)}},$hideAnimations:!I&&P,children:`Recover your account`})}),(0,b.jsx)(u.Watermark,{})]})]})}},C=s.div`
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
`,w=s.div`
  line-height: 20px;
  height: 20px;
  font-size: 13px;
  color: var(--privy-color-error);
  text-align: left;
  margin-top: 0.5rem;
`,T=s(l)`
  ${({$hideAnimations:e})=>e&&c`
      && {
        /* Remove animations because the recoverWallet task on the iframe partially
           blocks the renderer, so the animation stutters and doesn't look good */
        transition: none;
      }
    `}
`;export{S as PasswordRecoveryScreen,S as default};