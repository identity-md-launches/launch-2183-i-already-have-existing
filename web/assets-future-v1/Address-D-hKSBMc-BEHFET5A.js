import{o as e}from"./rolldown-runtime-DLMaRju-.js";import{n as t,t as n}from"./jsx-runtime-CvftCknt.js";import{t as r}from"./check-B8o8ZNpi.js";import{t as i}from"./copy-HVDRzuYa.js";import{c as a}from"./Loader-UAZqxsnw-BjnvLK0W.js";import{o}from"./ModalFooter-CmGY3GN5-D-y9DoW2.js";import{p as s}from"./storage-Ufl800Ne-BglSpeAE.js";var c=n(),l=e(t(),1),u=({address:e,showCopyIcon:t,url:n,className:a})=>{let[u,m]=(0,l.useState)(!1);function h(t){t.stopPropagation(),navigator.clipboard.writeText(e).then((()=>m(!0))).catch(console.error)}return(0,l.useEffect)((()=>{if(u){let e=setTimeout((()=>m(!1)),3e3);return()=>clearTimeout(e)}}),[u]),(0,c.jsxs)(d,n?{children:[(0,c.jsx)(p,{title:e,className:a,href:`${n}/address/${e}`,target:`_blank`,children:s(e)}),t&&(0,c.jsx)(o,{onClick:h,size:`sm`,style:{gap:`0.375rem`},children:(0,c.jsxs)(c.Fragment,u?{children:[`Copied`,(0,c.jsx)(r,{size:16})]}:{children:[`Copy`,(0,c.jsx)(i,{size:16})]})})]}:{children:[(0,c.jsx)(f,{title:e,className:a,children:s(e)}),t&&(0,c.jsx)(o,{onClick:h,size:`sm`,style:{gap:`0.375rem`,fontSize:`14px`},children:(0,c.jsxs)(c.Fragment,u?{children:[`Copied`,(0,c.jsx)(r,{size:14})]}:{children:[`Copy`,(0,c.jsx)(i,{size:14})]})})]})},d=a.span`
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
`,f=a.span`
  font-size: 14px;
  font-weight: 500;
  color: var(--privy-color-foreground);
`,p=a.a`
  font-size: 14px;
  color: var(--privy-color-foreground);
  text-decoration: none;

  &:hover {
    text-decoration: underline;
  }
`;export{u as t};