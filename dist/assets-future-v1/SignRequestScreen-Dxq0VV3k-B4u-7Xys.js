import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{P as r,y as i}from"./getAddress-yOC5k4Wk.js";import{r as a}from"./esm-n2lWo7kz.js";import{t as o}from"./createLucideIcon-Cp5gDHSp.js";import{$ as s,i as c,j as l,r as u}from"./privy-context-Bxv3Wh-5-Cuby72dr.js";import{O as d}from"./esm-DsxEYfBg.js";import{n as f}from"./modal-context-CzyPCE1h-CI6R4GsA.js";import{c as p}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{t as m}from"./ScreenLayout-nGD4p5K0-CHY5CldX.js";import{a as h,l as g}from"./SolanaWalletConnector-CtU87Bd6-DciLLQR1.js";import{r as _}from"./Layouts-BMRfo5hw-BXZv4R83.js";import{t as v}from"./CopyToClipboard-i_OQSBJr-D_GDYkRo.js";import{n as y,t as b}from"./JsonTree-BHzNC-ic-BD2CORNN.js";var x=o(`square-pen`,[[`path`,{d:`M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7`,key:`1m0v6g`}],[`path`,{d:`M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z`,key:`ohrbg2`}]]),S=n(),C=e(t(),1),w=p.img`
  && {
    height: ${e=>e.size===`sm`?`65px`:`140px`};
    width: ${e=>e.size===`sm`?`65px`:`140px`};
    border-radius: 16px;
    margin-bottom: 12px;
  }
`,T=e=>{if(!r(e))return e;try{let t=i(e);return t.includes(`�`)?e:t}catch{return e}},E=e=>{try{let t=a.decode(e),n=new TextDecoder().decode(t);return n.includes(`�`)?e:n}catch{return e}},D=e=>{let{types:t,primaryType:n,...r}=e.typedData;return(0,S.jsxs)(S.Fragment,{children:[(0,S.jsx)(M,{data:r}),(0,S.jsx)(v,{text:(i=e.typedData,JSON.stringify(i,null,2)),itemName:`full payload to clipboard`}),` `]});var i},O=({method:e,messageData:t,copy:n,iconUrl:r,isLoading:i,success:a,walletProxyIsLoading:o,errorMessage:s,isCancellable:c,onSign:l,onCancel:u,onClose:d})=>(0,S.jsx)(m,{title:n.title,subtitle:n.description,showClose:!0,onClose:d,icon:x,iconVariant:`subtle`,helpText:s?(0,S.jsx)(j,{children:s}):void 0,primaryCta:{label:n.buttonText,onClick:l,disabled:i||a||o,loading:i},secondaryCta:c?{label:`Not now`,onClick:u,disabled:i||a||o}:void 0,watermark:!0,children:(0,S.jsxs)(_,{children:[r?(0,S.jsx)(w,{style:{alignSelf:`center`},size:`sm`,src:r,alt:`app image`}):null,(0,S.jsxs)(A,{children:[e===`personal_sign`&&(0,S.jsx)(N,{children:T(t)}),e===`eth_signTypedData_v4`&&(0,S.jsx)(D,{typedData:t}),e===`solana_signMessage`&&(0,S.jsx)(N,{children:E(t)})]})]})}),k={component:()=>{let{authenticated:e}=c(),{initializeWalletProxy:t,closePrivyModal:n}=s(),{navigate:r,data:i,onUserCloseViaDialogOrKeybindRef:a}=f(),[o,p]=(0,C.useState)(!0),[m,_]=(0,C.useState)(``),[v,y]=(0,C.useState)(),[b,x]=(0,C.useState)(null),[w,T]=(0,C.useState)(!1);(0,C.useEffect)((()=>{e||r(`LandingScreen`)}),[e]),(0,C.useEffect)((()=>{t(l).then((e=>{p(!1),e||(_(`An error has occurred, please try again.`),y(new g(new h(m,d.E32603_DEFAULT_INTERNAL_ERROR.eipCode))))}))}),[]);let{method:E,data:D,confirmAndSign:k,onSuccess:A,onFailure:j,uiOptions:M}=i.signMessage,N={title:M?.title||`Sign message`,description:M?.description||`Signing this message will not cost you any fees.`,buttonText:M?.buttonText||`Sign and continue`},P=e=>{e?A(e):j(v||new g(new h(`The user rejected the request.`,d.E4001_USER_REJECTED_REQUEST.eipCode))),n({shouldCallAuthOnSuccess:!1}),setTimeout((()=>{x(null),_(``),y(void 0)}),200)};return a.current=()=>{P(b)},(0,S.jsx)(O,{method:E,messageData:D,copy:N,iconUrl:M?.iconUrl&&typeof M.iconUrl==`string`?M.iconUrl:void 0,isLoading:w,success:b!==null,walletProxyIsLoading:o,errorMessage:m,isCancellable:M?.isCancellable,onSign:async()=>{T(!0),_(``);try{let e=await k();x(e),T(!1),setTimeout((()=>{P(e)}),u)}catch(e){console.error(e),_(`An error has occurred, please try again.`),y(new g(new h(m,d.E32603_DEFAULT_INTERNAL_ERROR.eipCode))),T(!1)}},onCancel:()=>P(null),onClose:()=>P(b)})}},A=p.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 16px;
`,j=p.p`
  && {
    margin: 0;
    width: 100%;
    text-align: center;
    color: var(--privy-color-error-dark);
    font-size: 14px;
    line-height: 22px;
  }
`,M=p(b)`
  margin-top: 0;
`,N=p(y)`
  margin-top: 0;
`;export{k as SignRequestScreen,k as default,O as SignRequestView};