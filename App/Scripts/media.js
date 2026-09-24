(function(){
 const out=[],seen=new Set();let frames=0,videos=0;
 function add(value,base){if(typeof value!=='string'||!value)return;try{let u=new URL(value,base).href;if(/^https?:/i.test(u)&&/\.(m3u8|mp4|mpd)(\?|#|$)/i.test(u)&&!seen.has(u)){seen.add(u);out.push(u);}}catch(e){}}
 function inspect(w,depth){if(depth>3)return;try{
  const doc=w.document,base=w.location.href;frames++;
  doc.querySelectorAll('video,source').forEach(v=>{videos++;add(v.currentSrc,base);add(v.src,base);if(v.tagName==='VIDEO'){v.muted=true;try{const p=v.play();if(p)p.catch(()=>{});}catch(e){}}});
  Object.keys(w).filter(k=>/^player_/.test(k)).forEach(k=>{try{let p=w[k],u=p.url;if(p.encrypt==2)u=decodeURIComponent(atob(u));else if(p.encrypt==1)u=decodeURIComponent(u);add(u,base);}catch(e){}});
  try{w.performance.getEntriesByType('resource').forEach(r=>add(r.name,base));}catch(e){}
  doc.querySelectorAll('iframe').forEach(f=>{try{inspect(f.contentWindow,depth+1);}catch(e){}});
 }catch(e){}}
 inspect(window,0);return JSON.stringify({urls:out,frames,videos});
})()
