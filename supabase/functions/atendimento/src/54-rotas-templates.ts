  if (b.action?.startsWith('templates-')) {
    const ch=await channel(String(b.canal_id||''),ws);
    if(ch.canal!=='whatsapp'||ch.provedor!=='zernio'||!ch.ativo)
      throw Error('Templates Meta exigem um WhatsApp oficial conectado pela Zernio.');
    const accountId=ch.externo_id;
    if(b.action==='templates-list') {
      const result=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(accountId));
      const templates=result.templates||result.data?.templates||[];
      const mappings=await q(db.from('atd_template_mapeamentos').select('template_name,idioma,mapeamentos').eq('workspace_id',ws).eq('canal_id',ch.id)).catch(()=>[]);
      return json({templates:templates.map((t:any)=>({...t,mapeamentos:mappings.find((m:any)=>m.template_name===t.name&&m.idioma===t.language)?.mapeamentos||{}}))});
    }
    if(b.action==='templates-mapping-save') {
      const nome=String(b.template_name||'').trim(),idioma=String(b.idioma||'').trim(),raw=b.mapeamentos;
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(idioma)||!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Template ou mapeamentos inválidos.');
      const keys=['primeiro_nome','nome','email','telefone','campanha','produto','utm_campaign','capturado_em','valor_venda','data_venda','pesquisa'];
      const normalized:any={};
      for(const event of ['cadastro','venda','pesquisa']){
        const values=raw[event];
        if(!Array.isArray(values)||values.length>20||values.some((v:any)=>typeof v!=='string'||(!keys.includes(v)&&!/^extra:[a-z0-9_-]{1,80}$/.test(v))))throw Error('Mapeamento de variáveis inválido.');
        normalized[event]=values;
      }
      await q(db.from('atd_template_mapeamentos').upsert({workspace_id:ws,canal_id:ch.id,template_name:nome,idioma,mapeamentos:normalized,atualizado_em:new Date().toISOString()},{onConflict:'workspace_id,canal_id,template_name,idioma'}));
      return json({ok:true});
    }
    if(b.action==='templates-send'){
      if(!ctx.editar)throw Error('Sem permissão para enviar mensagens.');
      const cv=await q(db.from('atd_conversas').select('*').eq('id',b.conversa_id).eq('workspace_id',ws).single());
      if(cv.canal_id!==ch.id||cv.grupo)throw Error('Selecione uma conversa individual deste canal.');
      const opening=String(cv.externo_id).startsWith('pending:');
      if(!ch.ativo||ch.status!=='conectado')throw Error('O WhatsApp oficial não está conectado.');
      if(!ctx.nome)throw Error('Cadastre seu nome na equipe antes de enviar.');
      const nome=String(b.template_name||''),idioma=String(b.idioma||''),params=Array.isArray(b.parametros)?b.parametros.map((x:any)=>String(x||'').trim()):[];
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(idioma)||params.length>20||params.some((x:string)=>!x||x.length>1024))throw Error('Template ou variáveis inválidos.');
      const listed=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(ch.externo_id));
      const templates=listed.templates||listed.data?.templates||[];
      const tpl=templates.find((t:any)=>t.name===nome&&t.language===idioma&&t.status==='APPROVED');
      if(!tpl)throw Error('O template não está aprovado ou não corresponde a esta conta e idioma.');
      const components=tpl.components||[],header=components.find((c:any)=>String(c.type).toUpperCase()==='HEADER'),body=components.find((c:any)=>String(c.type).toUpperCase()==='BODY'),footer=components.find((c:any)=>String(c.type).toUpperCase()==='FOOTER'),buttons=components.find((c:any)=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[];
      const slots:any[]=[];
      const addSlots=(text:string,kind:string,index=-1)=>{
        const matches=[...String(text||'').matchAll(/\{\{(\d+)\}\}/g)],numbers=[...new Set(matches.map((x:any)=>Number(x[1])))].sort((a:number,b:number)=>a-b);
        if(numbers.some((n:number,i:number)=>n!==i+1))throw Error('As variáveis do template precisam seguir a ordem {{1}}, {{2}} etc.');
        numbers.forEach(marker=>slots.push({kind,index,marker}));
      };
      const headerFormat=String(header?.format||'TEXT').toUpperCase();
      if(headerFormat==='TEXT')addSlots(header?.text,'header');
      addSlots(body?.text,'body');
      buttons.forEach((button:any,index:number)=>{if(String(button.type).toUpperCase()==='URL')addSlots(button.url,'url',index);});
      if(slots.length>20||params.length!==slots.length||params.some((x:string)=>!x||x.length>1024))throw Error('Preencha os campos variáveis na ordem indicada pelo template.');
      const buttonParams=Array.isArray(b.button_params)?b.button_params.map((x:any)=>({index:Number(x.index),subType:String(x.subType||''),value:String(x.value||'').trim()})):[];
      if(buttonParams.length>10||buttonParams.some((x:any)=>!Number.isInteger(x.index)||x.index<0||x.index>=buttons.length||!x.value||x.value.length>1024))throw Error('Os valores enviados para os botões são inválidos.');
      for(const bp of buttonParams){const type=String(buttons[bp.index]?.type||'').toUpperCase(),expected=type==='COPY_CODE'?'copy_code':type==='FLOW'?'flow':null;if(!expected||bp.subType!==expected)throw Error('O tipo de valor não corresponde ao botão aprovado.');}
      let headerMedia:any=null;
      if(['IMAGE','VIDEO','DOCUMENT'].includes(headerFormat)){
        const incoming=b.header_media;
        if(incoming){
          const type=String(incoming.type||'').toLowerCase(),mode=incoming.link?'link':incoming.id?'id':'',value=String(incoming.link||incoming.id||'').trim();
          if(type!==headerFormat.toLowerCase()||!mode||value.length>4000)throw Error('A mídia precisa corresponder ao tipo de cabeçalho aprovado.');
          if(mode==='link'){
            try{const u=new URL(value),probe=new URL(value);probe.search='';probe.hash='';urlPublica(probe.toString());if(u.protocol!=='https:'||u.username||u.password)throw Error();}
            catch{throw Error('Informe uma URL HTTPS pública para a mídia.');}
          }
          headerMedia={type,...(mode==='link'?{link:value}:{id:value})};
        }
        if(!opening&&!headerMedia)throw Error('Informe a URL pública ou o ID da mídia para enviar este cabeçalho.');
      }else if(b.header_media)throw Error('Este template não aceita mídia no cabeçalho.');
      const sendComponents:any[]=[];
      for(const kind of ['header','body']){
        const part=kind==='header'?header:body;if(!part)continue;
        const partSlots=slots.filter(s=>s.kind===kind);
        if(kind==='header'&&headerFormat!=='TEXT'){
          if(headerMedia){const media=headerMedia.link?{link:headerMedia.link}:{id:headerMedia.id};sendComponents.push({type:'header',parameters:[{type:headerFormat.toLowerCase(),[headerFormat.toLowerCase()]:media}]});}
        }else if(partSlots.length){sendComponents.push({type:kind,parameters:partSlots.map(s=>({type:'text',text:params[slots.indexOf(s)]}))});}
      }
      const urlSlots=slots.filter(s=>s.kind==='url');
      for(const slot of urlSlots)sendComponents.push({type:'button',sub_type:'url',index:String(slot.index),parameters:[{type:'text',text:params[slots.indexOf(slot)]}]});
      let bodyPreview=String(body?.text||'');
      slots.forEach((slot,i)=>{if(slot.kind==='body')bodyPreview=bodyPreview.replaceAll(`{{${slot.marker}}}`,params[i]);});
      let headerPreview=headerFormat==='TEXT'?String(header?.text||''):'';
      slots.forEach((slot,i)=>{if(slot.kind==='header')headerPreview=headerPreview.replaceAll(`{{${slot.marker}}}`,params[i]);});
      const preview=[headerPreview,bodyPreview,footer?.text,buttons.map((button:any)=>button.text).filter(Boolean).join(' · ')].filter(Boolean).join('\n');
      const rid=String(b.requisicao_id||'');
      if(!/^[0-9a-f-]{36}$/i.test(rid))throw Error('Identificador de envio inválido.');
      const [pending]=await q(db.from('atd_mensagens').upsert({workspace_id:ws,conversa_id:cv.id,requisicao_id:rid,direcao:'enviada',texto:assinatura(ctx.nome,preview,ch.canal),autor_id:user.id,autor_nome:ctx.nome,status:'enviando'}, {onConflict:'workspace_id,requisicao_id',ignoreDuplicates:true}).select());
      if(!pending)return json({ok:true,repetida:true});
      let attempted=false;
      try{
        attempted=true;
        if(opening&&ch.canal==='whatsapp'){
          const participantId=String(cv.endereco||'').replace(/\D/g,'');
          if(participantId.length<10||participantId.length>15)throw new Error('Telefone do contato inválido para o WhatsApp oficial.');
        }
        const result=opening
          ?await zernio(zp(),'/inbox/conversations','POST',{accountId:ch.externo_id,participantId:String(cv.endereco||'').replace(/\D/g,''),templateName:nome,templateLanguage:idioma,templateParams:params,...(buttonParams.length?{templateButtonParams:buttonParams}:{}),...(headerMedia?{headerMedia}:{})})
          :await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(cv.externo_id)+'/messages','POST',{accountId:ch.externo_id,template:{elements:[{name:nome,language:idioma,components:sendComponents}]},...(buttonParams.length?{templateButtonParams:buttonParams}:{})});
        const external=String(result.data?.messageId||result.messageId||'');
        if(!external)throw new Error('A Zernio não confirmou o identificador da mensagem.');
        if(opening){
          const remoteConversation=String(result.data?.conversationId||result.conversationId||'');
          if(!remoteConversation)throw new Error('A Zernio não confirmou a sessão da conversa.');
          await q(db.from('atd_conversas').update({externo_id:remoteConversation}).eq('id',cv.id).eq('workspace_id',ws).eq('externo_id',cv.externo_id));
        }
        await q(db.rpc('atd_confirmar_envio',{p_mensagem:pending.id,p_externo:external}));
        return json({ok:true});
      }catch(e){
        const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408);
        await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:known?(e as Error).message:'Envio sem confirmação. Confira o histórico do provedor antes de tentar novamente.'}).eq('id',pending.id));
        return json({erro:known?(e as Error).message:'Envio sem confirmação. Atualize o histórico antes de reenviar.'},502);
      }
    }
    if(b.action==='templates-create'||b.action==='templates-update') {
      const nome=String(b.nome||'').trim(),language=String(b.idioma||'pt_BR').trim(),category=String(b.categoria||'');
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(language)
        ||!['UTILITY','MARKETING'].includes(category))throw Error('Nome, categoria ou idioma inválidos.');
      const raw=Array.isArray(b.componentes)?b.componentes:[];
      if(!raw.some((c:any)=>String(c.type||'').toLowerCase()==='body'))throw Error('O template precisa ter uma mensagem no corpo.');
      if(raw.filter((c:any)=>String(c.type||'').toLowerCase()==='header').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='body').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='footer').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='buttons').length>1)throw Error('O template contém componentes repetidos.');
      const variaveis=(texto:string,exemplos:any[],nomeCampo:string)=>{
        const matches=[...texto.matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1])),count=Math.max(0,...matches);
        const values=Array.isArray(exemplos)?exemplos.map((v:unknown)=>String(v||'').trim()):[];
        if(count>10||matches.some(n=>n<1)||new Set(matches).size!==count||values.length!==count||values.some((x:string)=>!x||x.length>200))throw Error(`${nomeCampo}: informe um exemplo para cada variável {{1}}, {{2}} etc.`);
        return count?values:null;
      };
      const components:any[]=[];
      for(const c of raw){
        const type=String(c.type||'').toLowerCase();
        if(type==='header'){
          const format=String(c.format||'').toLowerCase();
          if(format==='text'){
            const text=String(c.text||'').trim(),example=variaveis(text,c.examples,'Cabeçalho');
            if(!text||text.length>60)throw Error('O cabeçalho de texto deve ter até 60 caracteres.');
            components.push({type:'header',format:'text',text,...(example?{example:{header_text:[example]}}:{})});
          }else if(['image','video','document'].includes(format)){
            let link='';try{link=urlPublica(String(c.example_url||'')).toString();}catch{throw Error('Informe uma URL HTTPS pública de exemplo para a mídia do cabeçalho.');}
            components.push({type:'header',format,example:{header_handle:[link]}});
          }else throw Error('Formato de cabeçalho inválido.');
        }else if(type==='body'){
          const text=String(c.text||'').trim(),example=variaveis(text,c.examples,'Mensagem');
          if(!text||text.length>1024)throw Error('A mensagem deve ter de 1 a 1.024 caracteres.');
          components.push({type:'body',text,...(example?{example:{body_text:[example]}}:{})});
        }else if(type==='footer'){
          const text=String(c.text||'').trim();if(!text||text.length>60||/\{\{/.test(text))throw Error('O rodapé deve ter até 60 caracteres e não aceita variáveis.');
          components.push({type:'footer',text});
        }else if(type==='buttons'){
          const buttons=Array.isArray(c.buttons)?c.buttons:[];
          if(!buttons.length||buttons.length>3)throw Error('Adicione de 1 a 3 botões.');
          const mapped=buttons.map((button:any)=>{
            const bt=String(button.type||'').toLowerCase(),text=String(button.text||'').trim();
            if(!['quick_reply','url','phone_number','copy_code','flow'].includes(bt))throw Error('Tipo de botão não suportado.');
            if(bt==='copy_code'){
              const example=String(button.example||'').trim();if(category!=='MARKETING'||!example||example.length>60)throw Error('O botão Copiar código exige um template de Marketing e um exemplo de cupom.');
              return {type:'copy_code',example};
            }
            if(!text||text.length>(bt==='flow'?20:25))throw Error('Cada botão precisa de um texto dentro do limite permitido.');
            if(bt==='quick_reply')return {type:'quick_reply',text};
            if(bt==='phone_number'){
              const phone=String(button.phone_number||'').trim();if(!/^\+[1-9]\d{6,14}$/.test(phone))throw Error('Informe o telefone do botão com DDI, no formato +5511999999999.');
              return {type:'phone_number',text,phone_number:phone};
            }
            if(bt==='flow'){
              const flowId=String(button.flow_id||'').trim(),screen=String(button.navigate_screen||'').trim(),action=String(button.flow_action||'navigate');
              if(!/^\d{5,30}$/.test(flowId)||!screen||screen.length>60||!['navigate','data_exchange'].includes(action))throw Error('O botão de formulário exige ID, ação e tela inicial válidos.');
              return {type:'flow',text,flow_id:flowId,flow_cta:text,flow_action:action,...(action==='navigate'?{navigate_screen:screen}:{})};
            }
            const url=String(button.url||'').trim(),vars=[...url.matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1])),count=Math.max(0,...vars);
            let parsed:URL;try{parsed=new URL(url.replace(/\{\{\d+\}\}/g,'exemplo'));}catch{throw Error('Informe uma URL válida para o botão.');}
            if(!['https:','http:'].includes(parsed.protocol)||parsed.username||parsed.password||count>1||(count&&vars.some(n=>n!==1)))throw Error('A URL do botão deve ser http(s) e pode ter apenas uma variável {{1}}.');
            const result:any={type:'url',text,url};
            if(count){const example=String(button.example||'').trim();if(!example||example.length>200)throw Error('Informe um exemplo para a variável dinâmica do botão de link.');result.example=[example];}
            return result;
          });
          const quick=mapped.filter((x:any)=>x.type==='quick_reply').length,cta=mapped.length-quick;
          if(quick&&cta||quick>3||cta>2)throw Error('Use até 3 botões de resposta rápida ou até 2 botões de link/telefone.');
          components.push({type:'buttons',buttons:mapped});
        }else throw Error('Tipo de componente não suportado.');
      }
      if(b.action==='templates-create') {
        const result=await zernio(zp(),'/whatsapp/templates','POST',{accountId,name:nome,language,category,components});
        return json({template:result.template,ok:true});
      }
      const templateId=String(b.template_id||'');
      if(!/^\d{5,30}$/.test(templateId))throw Error('ID do template inválido.');
      const result=await zernio(zp(),'/whatsapp/templates/id/'+encodeURIComponent(templateId),'PATCH',{accountId,components});
      return json({template:result.template,ok:true});
    }
    if(b.action==='templates-delete') {
      const id=String(b.template_id||'');
      if(!/^\d{5,30}$/.test(id))throw Error('ID do template inválido.');
      await zernio(zp(),'/whatsapp/templates/id/'+encodeURIComponent(id)+'?accountId='+encodeURIComponent(accountId),'DELETE');
      if(b.template_name&&b.idioma)await q(db.from('atd_template_mapeamentos').delete().eq('workspace_id',ws).eq('canal_id',ch.id).eq('template_name',String(b.template_name)).eq('idioma',String(b.idioma)));
      return json({ok:true});
    }
  }
