(function(){
 const bad=/免费黄片|成人|色情|黄剧|抖阴|91视频|国产A片|裸聊|外围|赌场|博彩|娱乐城|投注|返水|葡京|棋牌|porn|sexcam/i;
 const root=location.origin, abs=s=>{if(!s||!s.trim())return '';try{return new URL(s,document.baseURI||location.href).href}catch(e){return ''}};
 const same=s=>{try{return /^(www\.)?kkys16\.com$/i.test(new URL(s,location.href).hostname)}catch(e){return false}};
 const text=e=>(e?(e.innerText||e.textContent||''):'').replace(/\s+/g,' ').trim();
 const safe=e=>{for(let n=e,j=0;n&&j<4&&n!==document.body;n=n.parentElement,j++){if(bad.test([n.id,n.className,n.getAttribute&&n.getAttribute('aria-label')].join(' ')))return false;}return true};
 const detail=s=>/(?:detail|movie|film|voddetail|video)[/\-][\w-]+/i.test(s);
 const play=s=>/(?:play|watch|vodplay)[/\-][\w-]+/i.test(s);
 const out={url:location.href,title:document.title,items:[],sections:[],rankTabs:[],categories:[],episodes:[],next:'',rank:'',search:'',description:'',cover:'',type:'',challenge:false};
 out.challenge=/verifying your browser|checking your browser|浏览器验证|人机验证|安全验证|Just a moment/i.test(document.title+' '+text(document.body).slice(0,1600));
 out.fingerprint=location.href+'|'+[...document.querySelectorAll('a[href]')].map(a=>a.href).filter(detail).join('|');
 out.empty=/没有找到|未找到相关|暂无相关|没有相关|搜索结果为空|共\s*0\s*(条|个|部)|no results/i.test(text(document.body));
 const generic=s=>!s||/^(查看更多|更多|查看详情|立即播放|播放|详情|可可影视(?:[\s-]*kekys\.com)?|kekys\.com|kkys16\.com)$/i.test(s.trim());
 const picture=img=>{if(!img)return '';const values=[];
 const loaded=img.complete&&img.naturalWidth>60&&!/loading|placeholder|default/i.test(img.currentSrc||img.getAttribute('src')||'');
 if(loaded){try{const canvas=document.createElement('canvas');canvas.width=160;canvas.height=Math.min(260,Math.round(160*img.naturalHeight/img.naturalWidth));canvas.getContext('2d').drawImage(img,0,0,canvas.width,canvas.height);const encoded=canvas.toDataURL('image/jpeg',.75);if(encoded.length<180000)return encoded;}catch(e){} }

 if(loaded&&/^https?:/i.test(img.currentSrc||''))return img.currentSrc;
 for(const key of ['data-poster','data-cover','data-image','data-original','data-src','data-lazy-src','data-lazy','data-url','data-echo','data-funlazy','data-srcset','srcset']){let v=img.getAttribute(key)||'';if(key.includes('srcset'))v=v.split(',')[0].trim().split(/\s+/)[0];values.push(v);}
 if(img.currentSrc&&!/loading|placeholder|default/i.test(img.currentSrc)&&/^https?:/i.test(img.currentSrc))values.push(img.currentSrc);values.push(img.getAttribute('src')||'');
 const style=(img.getAttribute('style')||'')+' '+(typeof getComputedStyle==='function'?getComputedStyle(img).backgroundImage:'');let match=style.match(/url\(\s*['"]?([^'"\)]+)['"]?\s*\)/i);if(match)values.unshift(match[1]);
 for(let v of values){v=v.trim();if(/^data:image\/(?:jpeg|png|webp);base64,/i.test(v)&&v.length<180000)return v;if(v&&!/^data:|^javascript:/i.test(v)&&!/loading|placeholder|default\.(png|jpg|gif)/i.test(v))return abs(v);}return '';};
 const cleanTitle=s=>s.replace(/^豆瓣[:：]?\s*\d+(?:\.\d+)?\s*分?\s*/,'').replace(/^(?:(?:HD|BD|DVD|1080P|720P|4K|正片|高清版|中字|国语|粤语|更新至\d+集)\s*)+/i,'').replace(/\s+(?:正片|高清版|HD中字)(?:\s*\/.*)?$/i,'').trim();
 const seen=new Map(),es=new Set(),cats=new Set(),routeNames=new Map();
 const currentPath=new URL(location.href).pathname;
 const currentMatch=currentPath.match(/(?:detail|movie|film|voddetail|video|play|watch|vodplay)[/\-](\d+)(?:[-./]|$)/i);
 const filmId=currentMatch?currentMatch[1]:'';
 const routeName=s=>s.replace(/\s*(?:全部|切换线路)\s*$/,'').trim();
 const validRoute=s=>s&&s.length<=20&&!/^(?:第?\s*\d+\s*[集话期部]?|播放线路|选集|正序|倒序|更多)$/.test(s)&&!bad.test(s);
 const episodeLabel=s=>/^(?:第?\s*\d+(?:[.-]\d+)?\s*(?:集|话|期|部)?(?:[上下])?|(?:HD|BD|DVD|4K|1080P|720P|正片|预告|特辑|花絮|全集|完结|特别篇|番外|SP|OVA|OAD|中字|国语|粤语|高清|完整版)[\w\u4e00-\u9fff .·-]{0,18})$/i.test(s);

 for(const a of document.querySelectorAll('a[href]')){
  let url=abs(a.getAttribute('href')),t=text(a),title=(a.getAttribute('title')||'').trim();
  if(!same(url)||!safe(a)||bad.test(t+' '+title+' '+url))continue;
  if(/^(电影|电视剧|剧集|动漫|综艺|短剧|纪录片|动画|国漫|日漫)$/.test(t)&&!cats.has(t)){out.categories.push({title:t,url});cats.add(t)}
  if(/^(排行榜|排行|热播榜|榜单|热榜)$/.test(t))out.rank=url;
  if(/^(电影|短剧|连续剧|电视剧|剧集|动漫|综艺)(周|月|日|总)?榜$/.test(t)&&!out.rankTabs.some(x=>x.url===url))out.rankTabs.push({title:t,url});
  if(/^(下一页|下页|下一頁|Next|›|»|>)$/i.test(t)||a.rel==='next')out.next=url;
  const localBox=a.closest('li,article,.module-item,.video-item,.vod-item,.stui-vodlist__box,.myui-vodlist__box');
  const parent=localBox||a.parentElement;
  const related=parent&&(!parent.querySelectorAll||[...parent.querySelectorAll('a[href]')].filter(x=>detail(abs(x.getAttribute('href')))).every(x=>new URL(abs(x.getAttribute('href'))).pathname===new URL(url).pathname));
  const itemKey=new URL(url).pathname;
  const img=a.querySelector('img')||(related&&parent&&parent.querySelector('img'));
  if(detail(url)&&!generic(t||title)||detail(url)&&img){
   const box=related?parent:null;
   const heading=box&&box.querySelector('.module-item-title,.video-name,.title,h2,h3,h4,[class*=title],[class*=name]');
   const candidates=[title,t,text(heading),img&&(img.alt||img.title)||''];
   let n=candidates.find(v=>v&&!generic(v)&&v.length<100&&!bad.test(v))||'';
   n=cleanTitle(n.replace(/\s*(立即播放|查看详情).*$/,'').trim());
   if(n&&!generic(n)&&!bad.test(n)){
    let pic=picture(img)||picture(a);if(!pic&&box){const candidate=box.querySelector('picture source,[data-original],[data-src],[style*=background]');pic=picture(candidate);}
    const score=cleanTitle(title)===n?4:cleanTitle(text(heading))===n?3:cleanTitle(t)===n?2:1;
    if(!seen.has(itemKey)){seen.set(itemKey,{index:out.items.length,score});out.items.push({url,title:n,cover:pic,remark:text(box&&box.querySelector('.module-item-note,.pic-text,.remarks,.video-note')),section:sectionTitle(a),actors:text(box&&box.querySelector('.actors,.actor')),heat:text(box&&box.querySelector('.hot,.hits,.popularity'))});}
    else {let old=seen.get(itemKey),item=out.items[old.index];if(score>old.score){item.title=n;old.score=score;}if(pic&&(!item.cover||pic.startsWith('data:image/')))item.cover=pic;}
   }
  }
  if(play(url)&&filmId&&episodeLabel(t)&&!es.has(url)){
   const route=new URL(url).pathname.match(/(?:play|watch|vodplay)\/(\d+)-(\d+)-/i);
   if(!route||route[1]!==filmId)continue;
   // History and recommendation widgets are not episode lists.
   if(a.closest('[class*="history"],[id*="history"],[class*="recommend"],[id*="recommend"]'))continue;
   const box=a.closest('[class*="play-list"],[class*="playlist"],[class*="episode"],[id*="playlist"],ul');
   let group='';
   for(let n=box,j=0;n&&j<4&&n!==document.body;n=n.parentElement,j++){
    if(!n.id||!/^[\w-]+$/.test(n.id))continue;
    const tab=document.querySelector('a[href="#'+n.id+'"],[data-target="#'+n.id+'"],[aria-controls="'+n.id+'"]');
    if(tab&&validRoute(routeName(text(tab)))){group=routeName(text(tab));break;}
   }
   const groupId='film-'+filmId+'-route-'+route[2];
   if(!routeNames.has(groupId))routeNames.set(groupId,group||'线路'+(routeNames.size+1));
   else if(group)routeNames.set(groupId,group);
   out.episodes.push({url,title:t,group:routeNames.get(groupId),groupId});es.add(url);
  }
 }
 for(const e of out.episodes)e.group=routeNames.get(e.groupId);
 for(const item of out.items){if(!item.section)continue;let section=out.sections.find(s=>s.title===item.section);if(!section){section={title:item.section,items:[]};out.sections.push(section);}section.items.push(item);}
 function sectionTitle(a){const box=a.closest('section,.module,.stui-pannel,.myui-panel,.vod-list,.index-list');if(!box)return '';const h=box.querySelector('.module-heading h2,.module-title,.stui-pannel__head h3,.myui-panel__head h3,h2,h3');const t=text(h);return t&&t.length<24&&!bad.test(t)?t:'';}
 const h=document.querySelector('h1,.detail-title,.video-title,.module-info-heading h1');if(h&&text(h))out.title=text(h);
 const d=document.querySelector('.module-info-introduction-content,.module-info-introduction,.detail-content,.detail-desc,.vod_content,.detail-sketch,.video-info-content,.vod-info-content,.stui-content__desc,.myui-content__describe,.detail .content,[itemprop="description"]');
 out.description=d?text(d):((document.querySelector('meta[property="og:description"],meta[name="description"]')||{}).content||'');
 const posterSelectors=['.module-info-poster img','.detail-pic img','.detail-poster img','.stui-content__thumb img','.myui-content__thumb img','[itemprop="image"]','meta[property="og:image"]','meta[name="twitter:image"]'];
 for(const selector of posterSelectors){const c=document.querySelector(selector);if(c){out.cover=c.content?abs(c.content):picture(c);out.coverLoaded=!!(c.complete&&c.naturalWidth>60&&!/loading|placeholder|default/i.test(c.currentSrc||c.getAttribute('src')||''));if(out.cover)break;}}
 if(!out.cover)for(const script of document.querySelectorAll('script[type="application/ld+json"]')){try{let data=JSON.parse(script.textContent);const rows=Array.isArray(data)?data:data['@graph']||[data];for(const row of rows){if(!/Movie|TVSeries|TVEpisode|VideoObject/.test(row['@type']||''))continue;let img=row.image||row.thumbnailUrl;if(Array.isArray(img))img=img[0];if(img&&typeof img==='object')img=img.url||img.contentUrl;if(typeof img==='string'){out.cover=abs(img);break;}}}catch(e){}if(out.cover)break;}

 for(const f of document.querySelectorAll('form')){
  const input=f.querySelector('input[name="wd"],input[name="q"],input[name="keyword"],input[name="searchword"]');
  if(input&&(f.method||'get').toLowerCase()==='get'){let action=abs(f.getAttribute('action')||location.pathname);if(same(action)){let u=new URL(action);for(const x of f.querySelectorAll('input[name]'))u.searchParams.set(x.name,x===input?'__QUERY__':x.value||'');out.search=u.href;break;}}
 }
 if(!out.search){let a=[...document.querySelectorAll('a[href]')].find(a=>same(a.href)&&/[?&](wd|q|keyword|searchword)=/i.test(a.href));if(a){let u=new URL(a.href);for(const k of ['wd','q','keyword','searchword'])if(u.searchParams.has(k))u.searchParams.set(k,'__QUERY__');out.search=u.href;}}
 for(const a of document.querySelectorAll('a[href]')){if(same(a.href)&&/^(电影|电视剧|剧集|动漫|综艺|短剧|纪录片|动画)$/.test(text(a))&&a.closest('.module-info,.detail-info,.vod-info,.video-info,.breadcrumb'))out.type=text(a);}
 out.posterLoaded=[...document.querySelectorAll('img')].filter(i=>i.complete&&i.naturalWidth>60&&!/loading|placeholder|default/i.test(i.currentSrc||'')).length;
 return JSON.stringify(out);
})()
