import{o as e,r as t}from"./rolldown-runtime-DLMaRju-.js";import{n,t as r}from"./jsx-runtime-CvftCknt.js";import{t as i}from"./createLucideIcon-Cp5gDHSp.js";import{t as a}from"./circle-check-big-lAOiCYlt.js";import{t as o}from"./fingerprint-pattern-tfkID5VF.js";import{$ as s,i as c}from"./privy-context-Bxv3Wh-5-Cuby72dr.js";import{n as l}from"./modal-context-CzyPCE1h-CI6R4GsA.js";import{c as u,r as d,s as f}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{t as p}from"./ScreenLayout-nGD4p5K0-CHY5CldX.js";import{f as m,s as h}from"./errors-BQ3N-RVt-CZPAWCgC.js";import{r as g}from"./useWallets-Cy8VgsCY-DGh3BGP9.js";import{n as _,t as v}from"./TodoList-DnyULl18-Bh_qRpf2.js";var y=i(`trash-2`,[[`path`,{d:`M10 11v6`,key:`nco0om`}],[`path`,{d:`M14 11v6`,key:`outv1u`}],[`path`,{d:`M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6`,key:`miytrc`}],[`path`,{d:`M3 6h18`,key:`d0wm0j`}],[`path`,{d:`M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2`,key:`e791ji`}]]),b=t({DoubleIconWrapper:()=>j,LinkButton:()=>N,LinkPasskeyScreen:()=>A,LinkPasskeyView:()=>C,default:()=>A}),x=r(),S=e(n(),1),C=({passkeys:e,name:t,isLoading:n,errorReason:r,success:i,expanded:s,onLinkPasskey:c,onUnlinkPasskey:l,onExpand:u,onBack:d,onClose:f})=>i?(0,x.jsx)(p,{title:`Passkeys updated`,icon:a,iconVariant:`success`,primaryCta:{label:`Done`,onClick:f},onClose:f,watermark:!0}):s?(0,x.jsx)(p,{icon:o,title:`Your passkeys`,onBack:d,onClose:f,watermark:!0,children:(0,x.jsx)(O,{passkeys:e,expanded:s,onUnlink:l,onExpand:u})}):(0,x.jsxs)(p,{icon:o,title:`Set up passkey verification`,subtitle:`Verify with passkey`,primaryCta:{label:`Add new passkey`,onClick:c,loading:n},onClose:f,watermark:!0,helpText:r||void 0,children:[e.length===0?(0,x.jsx)(k,{}):(0,x.jsx)(w,{children:(0,x.jsx)(O,{passkeys:e,expanded:s,onUnlink:l,onExpand:u})}),t?(0,x.jsxs)(T,{children:[(0,x.jsx)(E,{children:`New Passkey Name`}),(0,x.jsx)(D,{children:t})]}):null]}),w=u.div`
  margin-bottom: 0.75rem;
`,T=u.div`
  margin-top: 0.25rem;
`,E=u.div`
  color: var(--privy-color-foreground-2);
  font-size: 0.75rem;
  font-weight: 500;
  line-height: 1rem;
  margin-bottom: 0.25rem;
`,D=u.div`
  color: var(--privy-color-foreground);
  font-size: 0.875rem;
  line-height: 1.25rem;
`,O=({passkeys:e,expanded:t,onUnlink:n,onExpand:r})=>{let[i,a]=(0,S.useState)([]),o=t?e.length:2;return(0,x.jsxs)(`div`,{children:[(0,x.jsx)(F,{children:`Your passkeys`}),(0,x.jsxs)(P,{children:[e.slice(0,o).map((e=>{return(0,x.jsxs)(R,{children:[(0,x.jsxs)(`div`,{children:[(0,x.jsx)(I,{children:(t=e,t.authenticatorName?t.createdWithBrowser?`${t.authenticatorName} on ${t.createdWithBrowser}`:t.authenticatorName:t.createdWithBrowser?t.createdWithOs?`${t.createdWithBrowser} on ${t.createdWithOs}`:`${t.createdWithBrowser}`:`Unknown device`)}),(0,x.jsxs)(L,{children:[`Last used:`,` `,(e.latestVerifiedAt??e.firstVerifiedAt)?.toLocaleString()??`N/A`]})]}),(0,x.jsx)(B,{disabled:i.includes(e.credentialId),onClick:()=>(async e=>{a((t=>t.concat([e]))),await n(e),a((t=>t.filter((t=>t!==e))))})(e.credentialId),children:i.includes(e.credentialId)?(0,x.jsx)(d,{}):(0,x.jsx)(y,{size:16})})]},e.credentialId);var t})),e.length>2&&!t&&(0,x.jsx)(N,{onClick:r,children:`View all`})]})]})},k=()=>(0,x.jsxs)(v,{style:{color:`var(--privy-color-foreground)`},children:[(0,x.jsx)(_,{children:`Verify with Touch ID, Face ID, PIN, or hardware key`}),(0,x.jsx)(_,{children:`Takes seconds to set up and use`}),(0,x.jsx)(_,{children:`Use your passkey to verify transactions and login to your account`})]}),A={component:()=>{let{user:e}=c(),{unlink:t}=g(),{linkWithPasskey:n,closePrivyModal:r}=s(),{data:i}=l(),a=e?.linkedAccounts.filter((e=>e.type===`passkey`)),[o,u]=(0,S.useState)(!1),[d,f]=(0,S.useState)(``),[p,_]=(0,S.useState)(!1),[v,y]=(0,S.useState)(!1);return(0,S.useEffect)((()=>{a.length===0&&y(!1)}),[a.length]),(0,x.jsx)(C,{passkeys:a,name:i?.passkeyAuthModalData?.name,isLoading:o,errorReason:d,success:p,expanded:v,onLinkPasskey:()=>{u(!0),n({name:i?.passkeyAuthModalData?.name}).then((()=>_(!0))).catch((e=>{if(e instanceof m){if(e.privyErrorCode===h.CANNOT_LINK_MORE_OF_TYPE)return void f(`Cannot link more passkeys to account.`);if(e.privyErrorCode===h.PASSKEY_NOT_ALLOWED)return void f(`Passkey request timed out or rejected by user.`)}f(`Unknown error occurred.`)})).finally((()=>{u(!1)}))},onUnlinkPasskey:async e=>(u(!0),await t({credentialId:e}).then((()=>_(!0))).catch((e=>{e instanceof m&&e.privyErrorCode===h.MISSING_MFA_CREDENTIALS?f(`Cannot unlink a passkey enrolled in MFA`):f(`Unknown error occurred.`)})).finally((()=>{u(!1)}))),onExpand:()=>y(!0),onBack:()=>y(!1),onClose:()=>r()})}},j=u.div`
  display: flex;
  align-items: center;
  justify-content: center;
  width: 180px;
  height: 90px;
  border-radius: 50%;
  svg + svg {
    margin-left: 12px;
  }
  > svg {
    z-index: 2;
    color: var(--privy-color-accent) !important;
    stroke: var(--privy-color-accent) !important;
    fill: var(--privy-color-accent) !important;
  }
`,M=f`
  && {
    width: 100%;
    font-size: 0.875rem;
    line-height: 1rem;

    /* Tablet and Up */
    @media (min-width: 440px) {
      font-size: 14px;
    }

    display: flex;
    gap: 12px;
    justify-content: center;

    padding: 6px 8px;
    background-color: var(--privy-color-background);
    transition: background-color 200ms ease;
    color: var(--privy-color-accent) !important;

    :focus {
      outline: none;
      box-shadow: none;
    }
  }
`,N=u.button`
  ${M}
`,P=u.div`
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.8rem;
  padding: 0.5rem 0 0;
  flex-grow: 1;
  width: 100%;
`,F=u.div`
  line-height: 20px;
  height: 20px;
  font-size: 1em;
  font-weight: 450;
  display: flex;
  justify-content: flex-start;
  width: 100%;
`,I=u.div`
  font-size: 1em;
  line-height: 1.3em;
  font-weight: 500;
  color: var(--privy-color-foreground-2);
  padding: 0.2em 0;
`,L=u.div`
  font-size: 0.875rem;
  line-height: 1rem;
  color: var(--privy-color-foreground-2);
  padding: 0.2em 0;
`,R=u.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1em;
  gap: 10px;
  font-size: 0.875rem;
  line-height: 1rem;
  text-align: left;
  border-radius: 8px;
  border: 1px solid var(--privy-color-border-default) !important;
  width: 100%;
  height: 5em;
`,z=f`
  :focus,
  :hover,
  :active {
    outline: none;
  }
  display: flex;
  width: 2em;
  height: 2em;
  justify-content: center;
  align-items: center;
  svg {
    color: var(--privy-color-error);
  }
  svg:hover {
    color: var(--privy-color-foreground-3);
  }
`,B=u.button`
  ${z}
`;export{j as n,b as r,N as t};