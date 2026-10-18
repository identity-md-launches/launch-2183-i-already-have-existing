import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{t as r}from"./createLucideIcon-Cp5gDHSp.js";import{t as i}from"./check-B8o8ZNpi.js";import{t as a}from"./chevron-down-Bie_7Zqx.js";import{t as o}from"./hourglass-D308JFDA.js";import{t as s}from"./triangle-alert-BpmH-1xT.js";import{c}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{a as l}from"./ModalFooter-CmGY3GN5-D-y9DoW2.js";import{t as u}from"./ScreenLayout-nGD4p5K0-CHY5CldX.js";import{p as d}from"./storage-Ufl800Ne-BglSpeAE.js";import{_ as f,a as p,b as m,g as h,h as g,n as _,s as v,t as y,v as b,y as x}from"./styles-BRWlD4eG-iJY95DM4.js";import{a as S,c as C,d as ee,f as te,g as w,h as T,i as E,o as D,p as O,r as k,s as A,t as j,u as M,y as N}from"./floating-ui.react-C2iB3jgH.js";import{n as P}from"./CopyableText-CQapvaMr-D2qfp0B5.js";import{t as F}from"./QrCode-HPSrpHat-CtMKDCor.js";var I=r(`chevron-up`,[[`path`,{d:`m18 15-6-6-6 6`,key:`153udz`}]]),L=r(`info`,[[`circle`,{cx:`12`,cy:`12`,r:`10`,key:`1mglay`}],[`path`,{d:`M12 16v-4`,key:`1dtifu`}],[`path`,{d:`M12 8h.01`,key:`e9boi3`}]]),R=r(`qr-code`,[[`rect`,{width:`5`,height:`5`,x:`3`,y:`3`,rx:`1`,key:`1tu5fj`}],[`rect`,{width:`5`,height:`5`,x:`16`,y:`3`,rx:`1`,key:`1v8r4q`}],[`rect`,{width:`5`,height:`5`,x:`3`,y:`16`,rx:`1`,key:`1x03jg`}],[`path`,{d:`M21 16h-3a2 2 0 0 0-2 2v3`,key:`177gqh`}],[`path`,{d:`M21 21v.01`,key:`ents32`}],[`path`,{d:`M12 7v3a2 2 0 0 1-2 2H7`,key:`8crl2c`}],[`path`,{d:`M3 12h.01`,key:`nlz23k`}],[`path`,{d:`M12 3h.01`,key:`n36tog`}],[`path`,{d:`M12 16v.01`,key:`133mhm`}],[`path`,{d:`M16 12h1`,key:`1slzba`}],[`path`,{d:`M21 12v.01`,key:`1lwtk9`}],[`path`,{d:`M12 21v-1`,key:`1880an`}]]),z=e(t(),1),B=n(),V=class extends z.Component{static getDerivedStateFromError(){return{hasError:!0}}componentDidCatch(e,t){this.props.onError(e)}componentDidUpdate(e){e.resetKey!==this.props.resetKey&&this.state.hasError&&this.setState({hasError:!1})}render(){return this.state.hasError?null:this.props.children}constructor(...e){super(...e),this.state={hasError:!1}}};function H(e,t,n){let r=Number(e);return!Number.isFinite(r)||r===0?`1 ${t} ≈ ${e} ${n}`:r>=.01?`1 ${t} ≈ ${U(r)} ${n}`:`${U(1/r)} ${t} ≈ 1 ${n}`}function U(e){return e>=1e3?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:0}).format(Math.round(e)):e>=100?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:1}).format(e):e>=1?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:2}).format(e):new Intl.NumberFormat(`en-US`,{maximumFractionDigits:4}).format(e)}function W(e,t){let n=Number(e);if(!Number.isFinite(n)||n===0)return e;let r=t==null?n:n/10**t;return r>=1e3?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:2}).format(r):r>=1?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:4}).format(r):r>=1e-4?new Intl.NumberFormat(`en-US`,{maximumFractionDigits:6}).format(r):new Intl.NumberFormat(`en-US`,{maximumSignificantDigits:4}).format(r)}function G({address:e,caip2:t,config:n}){for(let r of n.currencies){let n=r.chains.find((n=>n.caip2===t&&n.address.toLowerCase()===e.toLowerCase()));if(n)return{symbol:r.symbol.toUpperCase(),decimals:n.decimals}}return{symbol:e,decimals:void 0}}function K(e,t){let n=t[e];return n?.displayName??n?.display_name??e}function q(e,t){return e.chains.filter((e=>!0===e.can_be_relay_deposit_source)).map((e=>{let n=t.chains[e.caip2];return n?{caip2:e.caip2,displayName:n.displayName,iconUrl:n.iconUrl,vmType:n.vmType,currencyAddress:e.address,currencyDecimals:e.decimals}:null})).filter((e=>e!==null))}function J(e,t){if(!e.chains[t.destinationChain])return`Unsupported destination chain: "${t.destinationChain}". Check that the chain is in CAIP-2 format (e.g. "eip155:8453") and is supported for deposit addresses.`;let n=t.destinationCurrency.toLowerCase();return e.currencies.some((e=>e.chains.some((e=>e.caip2===t.destinationChain&&e.address.toLowerCase()===n))))?null:`Unsupported destination currency "${t.destinationCurrency}" on chain "${t.destinationChain}". Check that this token address is supported on the specified chain.`}var Y=new Set([`ROUTE_UNAVAILABLE`,`UNEXPECTED_STATE`,`TIMEOUT_WAITING_FOR_NEXT_ORDER`,`TIMEOUT_ORDER_COMPLETION`,`DEPOSIT_FAILED`,`DEPOSIT_REFUNDED`,`USER_EXITED`,`AMOUNT_TOO_LOW`,`INSUFFICIENT_LIQUIDITY`,`UNSUPPORTED_CHAIN`,`UNSUPPORTED_CURRENCY`,`UNSUPPORTED_ROUTE`,`NO_SWAP_ROUTES_FOUND`,`NO_INTERNAL_SWAP_ROUTES_FOUND`,`NO_QUOTES`,`SANCTIONED_WALLET_ADDRESS`,`REFUND_WALLET_CREATION_FAILED`,`DEPOSIT_ADDRESSES_NOT_ENABLED`,`NOT_AUTHENTICATED`]);function X(e){return Y.has(e)}function Z(e){return X(e)?e:`UNKNOWN_ERROR`}var ne=({trackingUrl:e,onViewBlockExplorer:t,onClose:n})=>{let r=e&&t?()=>{t(),window.open(e,`_blank`,`noopener,noreferrer`)}:void 0;return(0,B.jsx)(u,{icon:o,iconVariant:`subtle`,title:`Transfer in progress`,subtitle:`Your deposit was received and the transfer is now processing.`,showClose:!0,onClose:n,secondaryCta:r?{label:`View on block explorer ↗`,onClick:r}:void 0,watermark:!1,children:(0,B.jsxs)(f,{children:[(0,B.jsxs)(p,{children:[(0,B.jsx)(h,{$status:`done`,children:(0,B.jsx)(i,{size:14,color:`var(--privy-color-icon-success)`,strokeWidth:2})}),(0,B.jsx)(_,{children:`Deposit received`})]}),(0,B.jsx)(v,{}),(0,B.jsxs)(p,{children:[(0,B.jsx)(h,{$status:`active`,children:(0,B.jsx)(re,{})}),(0,B.jsx)(_,{children:`Bridging`})]}),(0,B.jsx)(v,{}),(0,B.jsxs)(p,{children:[(0,B.jsx)(h,{$status:`pending`}),(0,B.jsx)(_,{children:`Funds arrived`})]})]})})},re=c.span`
  width: 0.75rem;
  height: 0.75rem;
  border: 2px solid var(--privy-color-foreground-3);
  border-bottom-color: transparent;
  border-radius: 50%;
  display: inline-block;
  animation: spin 1s linear infinite;

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
`;function ie({address:e,onClick:t}){let[n,r]=(0,z.useState)(!1);return(0,B.jsx)(B.Fragment,{children:n?(0,B.jsx)(ae,{onClick:()=>r(!1),style:{marginTop:`1.5rem`},children:(0,B.jsx)(F,{url:e,size:312,hideLogo:!0})}):(0,B.jsxs)(oe,{title:`Click to copy address`,onClick:t,style:{marginTop:`1.5rem`},children:[(0,B.jsxs)(se,{children:[(0,B.jsx)(ce,{children:`Deposit address`}),(0,B.jsx)(le,{children:e})]}),(0,B.jsx)(ue,{children:(0,B.jsx)(de,{type:`button`,onClick:e=>{e.stopPropagation(),r(!0)},children:(0,B.jsx)(R,{size:16,color:`var(--privy-color-icon-muted)`})})})]})})}var ae=c.div`
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  overflow: hidden;
`,oe=c.div`
  display: flex;
  border-radius: var(--privy-border-radius-md);
  background: var(--privy-color-background-clicked);
  padding: 1rem;
  cursor: pointer;
  gap: 0.5rem;
`,se=c.div`
  flex: 1;
  min-width: 0;
  text-align: left;
`,ce=c.div`
  font-size: 0.75rem;
  color: var(--privy-color-icon-muted);
  line-height: 1rem;
  margin-bottom: 0.25rem;
`,le=c.div`
  word-break: break-all;
  font-size: 0.875rem;
  font-family: ui-monospace, monospace;
  font-weight: 500;
  line-height: 1.375rem;
  color: var(--privy-color-foreground);
`,ue=c.div`
  width: 1.5rem;
  flex-shrink: 0;
  display: flex;
  justify-content: center;
  padding-top: 0.25rem;
`,de=c.button`
  && {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 1.5rem;
    height: 1.5rem;
    border: none;
    background: transparent;
    cursor: pointer;
    outline: none;
    box-shadow: none;
    border-radius: var(--privy-border-radius-xs);

    &:hover {
      background: var(--privy-color-background);
    }

    &:focus,
    &:focus-visible {
      outline: none;
      box-shadow: none;
    }
  }
`,Q=e=>/^0x/i.test(e)||e.length>16;function fe({quote:e,selectedCurrency:t,selectedChain:n,destinationSymbol:r,destinationChainName:i,destinationAsset:o}){let[c,l]=(0,z.useState)(!1),u=t.symbol.toUpperCase(),f=n.displayName,p=(0,z.useRef)(null);return(0,B.jsxs)(pe,{children:[(0,B.jsxs)(me,{onClick:(0,z.useCallback)((()=>{let e=document.getElementById(`privy-modal-content`);e&&(p.current&&clearTimeout(p.current),e.style.transition=`none`,p.current=setTimeout((()=>{e.style.transition=``,p.current=null}),160)),l((e=>!e))}),[]),children:[(0,B.jsxs)(he,{children:[t.logoURI&&(0,B.jsx)(y,{src:t.logoURI,alt:u,style:{width:`2rem`,height:`2rem`}}),n.iconUrl&&(0,B.jsx)(ge,{src:n.iconUrl,alt:f})]}),(0,B.jsxs)(_e,{children:[(0,B.jsx)(ve,{children:`You send`}),(0,B.jsxs)(ye,{children:[u,` on `,f]})]}),(0,B.jsx)(be,{children:(0,B.jsx)(c?I:a,{size:16})})]}),(0,B.jsx)(Ce,{$expanded:c,children:(0,B.jsx)(we,{children:(0,B.jsxs)($,{children:[e.indicative_rate&&(0,B.jsxs)(m,{children:[(0,B.jsx)(x,{children:`Conversion rate`}),(0,B.jsxs)(b,{style:{display:`flex`,alignItems:`center`,gap:`0.25rem`},children:[H(e.indicative_rate,u,r.toUpperCase()),(0,B.jsx)(Te,{content:`Estimated rate based on current market conditions. Final execution price may vary depending on transfer size and routing.`})]})]}),(0,B.jsxs)(m,{children:[(0,B.jsx)(x,{children:`Receive`}),(0,B.jsxs)(b,{children:[r&&!Q(r)?r.toUpperCase():Q(o)?d(o):o.toUpperCase(),i?` on ${i}`:``]})]}),e.slippage_bps!=null&&(0,B.jsxs)(m,{children:[(0,B.jsx)(x,{children:`Max slippage`}),(0,B.jsxs)(b,{children:[(e.slippage_bps/100).toFixed(1),`%`]})]}),e.refund_address&&(0,B.jsxs)(m,{children:[(0,B.jsx)(x,{children:`Refund address`}),(0,B.jsx)(b,{children:(0,B.jsx)(P,{value:e.refund_address,iconOnly:!0,iconSize:11,children:d(e.refund_address,4,4)})})]})]})})}),(0,B.jsxs)(xe,{children:[(0,B.jsx)(s,{size:16,color:`var(--privy-color-icon-muted)`,style:{flexShrink:0}}),(0,B.jsxs)(Se,{children:[`Only send `,(0,B.jsx)(`strong`,{children:u}),` on `,(0,B.jsx)(`strong`,{children:f}),`. Other assets may be lost.`]})]})]})}var pe=c.div`
  border-radius: var(--privy-border-radius-md);
  border: 1px solid var(--privy-color-foreground-4);
  overflow: hidden;
`,me=c.button`
  && {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    background: transparent;
    border: none;
    cursor: pointer;
    color: var(--privy-color-foreground);
    outline: none;
    box-shadow: none;

    &:focus,
    &:focus-visible {
      outline: none;
      box-shadow: none;
    }
  }
`,he=c.span`
  position: relative;
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
`,ge=c(g)`
  && {
    position: absolute;
    top: -0.125rem;
    right: -0.25rem;
    width: 0.75rem;
    height: 0.75rem;
    box-sizing: content-box;
    border: 1.5px solid var(--privy-color-background);
    background-color: var(--privy-color-background);
  }
`,_e=c.div`
  display: flex;
  flex-direction: column;
  align-items: flex-start;
`,ve=c.span`
  font-size: 0.75rem;
  color: var(--privy-color-foreground-3);
  line-height: 1rem;
`,ye=c.span`
  font-size: 0.875rem;
  font-weight: 500;
  line-height: 1.25rem;
`,be=c.span`
  margin-left: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: var(--privy-border-radius-full);
  background-color: var(--privy-color-background-clicked);
  color: var(--privy-color-foreground-3);
`,$=c.div`
  display: flex;
  flex-direction: column;
  padding: 0 1rem 0.75rem;

  & > * {
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--privy-color-foreground-4);
  }

  & > *:last-child {
    border-bottom: none;
  }
`,xe=c.div`
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 0.75rem 0.75rem;
  padding: 0.625rem 0.75rem;
  border-radius: var(--privy-border-radius-sm);
  background: var(--privy-color-background-2);
`,Se=c.span`
  font-size: 0.8125rem;
  line-height: 1.25rem;
  color: var(--privy-color-icon-muted);
  text-align: left;
`,Ce=c.div`
  display: grid;
  grid-template-rows: ${({$expanded:e})=>e?`1fr`:`0fr`};
  transition: grid-template-rows 150ms ease-out;
`,we=c.div`
  overflow: hidden;
`;function Te({content:e}){let[t,n]=(0,z.useState)(!1),{refs:r,floatingStyles:i,context:a}=D({open:t,onOpenChange:n,placement:`top`,whileElementsMounted:N,middleware:[T(6),O(),w({padding:8})]}),o=C(a,{move:!1,handleClose:k()}),s=A(a),{getReferenceProps:c,getFloatingProps:l}=M([o,s,E(a),S(a),ee(a,{role:`tooltip`})]),{isMounted:u,styles:d}=te(a,{duration:150});return(0,B.jsxs)(B.Fragment,{children:[(0,B.jsx)(`button`,{ref:r.setReference,type:`button`,"aria-label":`More information about conversion rate`,style:{display:`inline-flex`,alignItems:`center`,justifyContent:`center`,padding:0,border:`none`,background:`none`,color:`var(--privy-color-icon-muted)`,cursor:`pointer`},...c(),children:(0,B.jsx)(L,{size:14})}),u&&(0,B.jsx)(j,{root:document.getElementById(`privy-modal-content`)??void 0,children:(0,B.jsx)(Ee,{ref:r.setFloating,style:{...i,...d},...l(),children:e})})]})}var Ee=c.div`
  max-width: 13rem;
  padding: 0.5rem 0.625rem;
  border-radius: var(--privy-border-radius-sm, 0.375rem);
  background: var(--privy-color-foreground);
  color: var(--privy-color-background);
  font-size: 0.6875rem;
  line-height: 1rem;
  font-weight: 400;
  text-align: left;
  z-index: 10;
`,De=({quote:e,selectedCurrency:t,selectedChain:n,destinationSymbol:r,destinationChainName:a,destinationAsset:o,onBack:s,onClose:c})=>{let[d,f]=(0,z.useState)(!1),p=t?.symbol?.toUpperCase()??`funds`,m=n?.displayName??``,h=async()=>{d||(await navigator.clipboard.writeText(e.deposit_address),f(!0),setTimeout((()=>f(!1)),2e3))};return(0,B.jsxs)(u,{title:`Send ${p}${m?` on ${m}`:``}`,subtitle:`Send funds to the address below. Conversion and routing handled by Relay.`,showBack:!0,onBack:s,showClose:!0,onClose:c,watermark:!1,children:[(0,B.jsx)(fe,{quote:e,selectedCurrency:t,selectedChain:n,destinationSymbol:r,destinationChainName:a,destinationAsset:o}),(0,B.jsx)(ie,{address:e.deposit_address,onClick:h}),(0,B.jsx)(l,{style:{marginTop:`1rem`,marginBottom:`0.5rem`,...d?{backgroundColor:`var(--privy-color-icon-success)`,borderColor:`var(--privy-color-icon-success)`}:{}},onClick:h,children:d?(0,B.jsxs)(B.Fragment,{children:[`Copied `,(0,B.jsx)(i,{size:16,style:{marginLeft:`0.25rem`}})]}):`Copy address`}),(0,B.jsx)(Oe,{children:`Routing and bridging are handled by Relay. Privy does not control execution timing, liquidity, or transaction outcomes.`})]})},Oe=c.p`
  && {
    margin: 0.5rem 0 0;
    font-size: 0.6875rem;
    line-height: 1.125rem;
    color: var(--privy-color-icon-muted);
    text-align: center;
  }
`;export{De as a,Z as c,V as i,ne as l,G as n,W as o,K as r,q as s,J as t,R as u};