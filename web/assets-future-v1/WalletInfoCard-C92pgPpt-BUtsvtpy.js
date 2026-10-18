import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{t as r}from"./check-B8o8ZNpi.js";import{t as i}from"./copy-HVDRzuYa.js";import{c as a}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{o}from"./ModalFooter-CmGY3GN5-D-y9DoW2.js";import{t as s}from"./ErrorMessage-D8VaAP5m-CS06WdNK.js";import{t as c}from"./shared-FM0rljBt-D-wAu1V6.js";import{t as l}from"./Address-D-hKSBMc-BEHFET5A.js";import{t as u}from"./LabelXs-oqZNqbm_-DLlwZvt7.js";var d=n(),f=e(t(),1),p=a(c)`
  && {
    padding: 0.75rem;
    height: 56px;
  }
`,m=a.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
`,h=a.div`
  display: flex;
  flex-direction: column;
  gap: 0;
`,g=a.div`
  font-size: 12px;
  line-height: 1rem;
  color: var(--privy-color-foreground-3);
`,_=a(u)`
  text-align: left;
  margin-bottom: 0.5rem;
`,v=a(s)`
  margin-top: 0.25rem;
`,y=a(o)`
  && {
    gap: 0.375rem;
    font-size: 14px;
  }
`,b=({errMsg:e,balance:t,address:n,className:a,title:o,showCopyButton:s=!1})=>{let[c,u]=(0,f.useState)(!1);return(0,f.useEffect)((()=>{if(c){let e=setTimeout((()=>u(!1)),3e3);return()=>clearTimeout(e)}}),[c]),(0,d.jsxs)(`div`,{children:[o&&(0,d.jsx)(_,{children:o}),(0,d.jsx)(p,{className:a,$state:e?`error`:void 0,children:(0,d.jsxs)(m,{children:[(0,d.jsxs)(h,{children:[(0,d.jsx)(l,{address:n,showCopyIcon:!1}),t!==void 0&&(0,d.jsx)(g,{children:t})]}),s&&(0,d.jsx)(y,{onClick:function(e){e.stopPropagation(),navigator.clipboard.writeText(n).then((()=>u(!0))).catch(console.error)},size:`sm`,children:(0,d.jsxs)(d.Fragment,c?{children:[`Copied`,(0,d.jsx)(r,{size:14})]}:{children:[`Copy`,(0,d.jsx)(i,{size:14})]})})]})}),e&&(0,d.jsx)(v,{children:e})]})};export{b as t};