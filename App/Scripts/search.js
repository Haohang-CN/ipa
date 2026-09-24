(function(){
 const query=__QUERY_JSON__[0];
 const same=s=>{try{const u=new URL(s,location.href);return /^(www\.)?kkys16\.com$/i.test(u.hostname)&&/^https?:$/.test(u.protocol)&&!u.username}catch(e){return false}};
 const visible=e=>!!(e&&e.getClientRects().length&&!e.disabled),txt=e=>(e&&(e.innerText||e.textContent)||'').trim();
 const inputs=[...document.querySelectorAll('input')];
 const score=e=>{if(e.disabled||/^(hidden|password|checkbox|radio|file|submit|button)$/i.test(e.type))return -1;let n=[e.name,e.id,e.placeholder,e.getAttribute('aria-label')].join(' ');if(/email|phone|user|login|密码|手机|邮箱/i.test(n))return -1;let s=/^(wd|q|keyword|searchword|search|query|key)$/i.test(e.name||'')?10:0;if(e.type==='search')s+=8;if(/search|keyword|搜索|片名|影片|视频名称|关键字|关键词/i.test(n))s+=6;if(!s)return -1;return s+(visible(e)?5:0)};
 const input=inputs.filter(e=>score(e)>=0).sort((a,b)=>score(b)-score(a))[0];
 const info={title:document.title,url:location.href,fields:inputs.filter(e=>score(e)>=0).map(e=>({name:e.name,id:e.id,type:e.type,placeholder:e.placeholder,method:e.form?e.form.method:'',action:e.form?e.form.action:''}))};
 const finish=(state,why)=>JSON.stringify({state,why,info});
 if(!input||!visible(input)){
  if(!window.__qingyingSearchOpened){const toggle=[...document.querySelectorAll('button,a,[role="button"],i,span')].find(e=>{let hints=[e.id,e.className,e.getAttribute('aria-label'),e.getAttribute('title'),txt(e)].join(' ');return visible(e)&&txt(e).length<25&&/search|搜索/i.test(hints)&&(!e.href||same(e.href))});if(toggle){window.__qingyingSearchOpened=true;toggle.click();return finish('retry','opened-search');}}
  if(!input)return finish('retry','no-search-input');
 }
 const form=input.form||input.closest('form');
 if(form&&form.action&&!same(form.action))return finish('unavailable','external-search-action');
 const before=location.href+'|'+[...document.querySelectorAll('a[href]')].map(a=>a.href).filter(s=>/(?:detail|movie|film|voddetail|video)[/\-][\w-]+/i.test(s)).join('|');
 Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,query);input.dispatchEvent(new Event('input',{bubbles:true}));input.dispatchEvent(new Event('change',{bubbles:true}));
 setTimeout(()=>{try{
  if(form){const submit=[...form.querySelectorAll('button,input[type="submit"],[role="button"]')].find(b=>visible(b)&&/搜索|search|submit/i.test([b.type,b.id,b.className,txt(b)].join(' ')));if(submit)submit.click();else if(form.requestSubmit)form.requestSubmit();else HTMLFormElement.prototype.submit.call(form);return;}
  const box=input.closest('[class*="search"],[id*="search"]')||input.parentElement;const submit=box&&[...box.querySelectorAll('button,a,[role="button"],i,span')].find(b=>visible(b)&&txt(b).length<25&&/搜索|search|submit/i.test([b.id,b.className,b.getAttribute('aria-label'),txt(b)].join(' '))&&(!b.href||same(b.href)));
  if(submit)submit.click();else{input.focus();for(const type of ['keydown','keypress','keyup'])input.dispatchEvent(new KeyboardEvent(type,{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));}
 }catch(e){window.__qingyingSearchError=String(e)}},100);
 return JSON.stringify({state:'submitted',before,info});
})()
