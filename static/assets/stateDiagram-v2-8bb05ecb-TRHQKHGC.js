import{a as V,b as Y,c as W,d as z,e as w,f as q,g as G,h as K}from"./chunk-OPNAUQ6F.js";import{a as U}from"./chunk-JOINRAHF.js";import"./chunk-LSZKUOXR.js";import"./chunk-SF6FGZXC.js";import{j as H}from"./chunk-4VIGWTJT.js";import{$a as h,Fa as l,I as rt,Ka as g,Ya as j,b as it,bb as J,c as ct,h as y}from"./chunk-AZTSVESG.js";import"./chunk-BZUL2CAN.js";import{h as R}from"./chunk-EP6THQJ3.js";var Mt=R(it(),1),Ht=R(ct(),1),Ut=R(rt(),1);var x="rect",N="rectWithTitle",lt="start",at="end",dt="divider",Et="roundedWithTitle",St="note",pt="noteGroup",_="statediagram",Tt="state",_t=`${_}-${Tt}`,X="transition",ut="note",bt="note-edge",ft=`${X} ${bt}`,Dt=`${_}-${ut}`,ht="cluster",At=`${_}-${ht}`,yt="cluster-alt",gt=`${_}-${yt}`,Z="parent",F="note",xt="state",O="----",$t=`${O}${F}`,Q=`${O}${Z}`,I="fill:none",tt="fill: #333",et="c",ot="text",st="normal",$={},E=0,Ct=function(t){let n=Object.keys(t);for(let e of n)t[e]},Rt=function(t,n){return n.db.extract(n.db.getRootDocV2()),n.db.getClasses()};function wt(t){return t==null?"":t.classes?t.classes.join(" "):""}function L(t="",n=0,e="",i=O){let c=e!==null&&e.length>0?`${i}${e}`:"";return`${xt}-${t}${c}-${n}`}var A=(t,n,e,i,c,r)=>{let o=e.id,u=wt(i[o]);if(o!=="root"){let p=x;e.start===!0&&(p=lt),e.start===!1&&(p=at),e.type!==w&&(p=e.type),$[o]||($[o]={id:o,shape:p,description:g.sanitizeText(o,h()),classes:`${u} ${_t}`});let s=$[o];e.description&&(Array.isArray(s.description)?(s.shape=N,s.description.push(e.description)):s.description.length>0?(s.shape=N,s.description===o?s.description=[e.description]:s.description=[s.description,e.description]):(s.shape=x,s.description=e.description),s.description=g.sanitizeTextOrArray(s.description,h())),s.description.length===1&&s.shape===N&&(s.shape=x),!s.type&&e.doc&&(l.info("Setting cluster for ",o,P(e)),s.type="group",s.dir=P(e),s.shape=e.type===q?dt:Et,s.classes=s.classes+" "+At+" "+(r?gt:""));let T={labelStyle:"",shape:s.shape,labelText:s.description,classes:s.classes,style:"",id:o,dir:s.dir,domId:L(o,E),type:s.type,padding:15};if(T.centerLabel=!0,e.note){let a={labelStyle:"",shape:St,labelText:e.note.text,classes:Dt,style:"",id:o+$t+"-"+E,domId:L(o,E,F),type:s.type,padding:15},d={labelStyle:"",shape:pt,labelText:e.note.text,classes:s.classes,style:"",id:o+Q,domId:L(o,E,Z),type:"group",padding:0};E++;let b=o+Q;t.setNode(b,d),t.setNode(a.id,a),t.setNode(o,T),t.setParent(o,b),t.setParent(a.id,b);let S=o,f=a.id;e.note.position==="left of"&&(S=a.id,f=o),t.setEdge(S,f,{arrowhead:"none",arrowType:"",style:I,labelStyle:"",classes:ft,arrowheadStyle:tt,labelpos:et,labelType:ot,thickness:st})}else t.setNode(o,T)}n&&n.id!=="root"&&(l.trace("Setting node ",o," to be child of its parent ",n.id),t.setParent(o,n.id)),e.doc&&(l.trace("Adding nodes children "),Gt(t,e,e.doc,i,c,!r))},Gt=(t,n,e,i,c,r)=>{l.trace("items",e),e.forEach(o=>{switch(o.stmt){case W:A(t,n,o,i,c,r);break;case w:A(t,n,o,i,c,r);break;case z:{A(t,n,o.state1,i,c,r),A(t,n,o.state2,i,c,r);let u={id:"edge"+E,arrowhead:"normal",arrowTypeEnd:"arrow_barb",style:I,labelStyle:"",label:g.sanitizeText(o.description,h()),arrowheadStyle:tt,labelpos:et,labelType:ot,thickness:st,classes:X};t.setEdge(o.state1.id,o.state2.id,u,E),E++}break}})},P=(t,n=Y)=>{let e=n;if(t.doc)for(let i=0;i<t.doc.length;i++){let c=t.doc[i];c.stmt==="dir"&&(e=c.value)}return e},Nt=async function(t,n,e,i){l.info("Drawing state diagram (v2)",n),$={},i.db.getDirection();let{securityLevel:c,state:r}=h(),o=r.nodeSpacing||50,u=r.rankSpacing||50;l.info(i.db.getRootDocV2()),i.db.extract(i.db.getRootDocV2()),l.info(i.db.getRootDocV2());let p=i.db.getStates(),s=new H({multigraph:!0,compound:!0}).setGraph({rankdir:P(i.db.getRootDocV2()),nodesep:o,ranksep:u,marginx:8,marginy:8}).setDefaultEdgeLabel(function(){return{}});A(s,void 0,i.db.getRootDocV2(),p,i.db,!0);let T;c==="sandbox"&&(T=y("#i"+n));let a=c==="sandbox"?y(T.nodes()[0].contentDocument.body):y("body"),d=a.select(`[id="${n}"]`),b=a.select("#"+n+" g");await U(b,s,["barb"],_,n);let S=8;j.insertTitle(d,"statediagramTitleText",r.titleTopMargin,i.db.getDiagramTitle());let f=d.node().getBBox(),k=f.width+S*2,v=f.height+S*2;d.attr("class",_);let m=d.node().getBBox();J(d,v,k,r.useMaxWidth);let B=`${m.x-S} ${m.y-S} ${k} ${v}`;l.debug(`viewBox ${B}`),d.attr("viewBox",B);let nt=document.querySelectorAll('[id="'+n+'"] .edgeLabel .label');for(let C of nt){let M=C.getBBox(),D=document.createElementNS("http://www.w3.org/2000/svg",x);D.setAttribute("rx",0),D.setAttribute("ry",0),D.setAttribute("width",M.width),D.setAttribute("height",M.height),C.insertBefore(D,C.firstChild)}},Lt={setConf:Ct,getClasses:Rt,draw:Nt},Wt={parser:V,db:G,renderer:Lt,styles:K,init:t=>{t.state||(t.state={}),t.state.arrowMarkerAbsolute=t.arrowMarkerAbsolute,G.clear()}};export{Wt as diagram};
