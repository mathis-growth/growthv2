import { assinatura,evolutionMensagem,zernioMensagem,statusMensagem,urlPublica,hmacValido } from '../../supabase/functions/atendimento/core.ts';
function eq(a: unknown,b: unknown) { if(JSON.stringify(a)!==JSON.stringify(b))throw new Error(JSON.stringify({a,b})); }
Deno.test('assinatura sanitiza marcação e não aceita nome vazio',()=>{
 eq(assinatura('Roger *Silva*\n','Olá','whatsapp'),'*Roger Silva:* Olá');
 eq(assinatura('Roger','Olá','instagram'),'Roger: Olá');
 let failed=false;try{assinatura('','oi','whatsapp');}catch{failed=true;}eq(failed,true);
});
Deno.test('grupo conserva autor, contato e id externo',()=>{
 const x=evolutionMensagem({key:{id:'m1',remoteJid:'123@g.us',participant:'456@s.whatsapp.net'},pushName:'Maria',message:{conversation:'oi'},messageTimestamp:1793275200});
 eq(x?.conversa.grupo,true);eq(x?.mensagem.participante,'456@s.whatsapp.net');eq(x?.mensagem.autor_nome,'Maria');
 eq(evolutionMensagem({key:{id:'x',remoteJid:'status@broadcast'},message:{conversation:'x'}}),null);
});
Deno.test('mensagens de mídia persistem como recuperáveis; sem URL pública no registro',()=>{
 const x=evolutionMensagem({key:{id:'x',remoteJid:'123@s.whatsapp.net'},message:{imageMessage:{url:'https://cdn.test/a',mimetype:'image/jpeg',caption:'Foto'}}});
 eq(x?.mensagem.anexos[0].pendente,true);eq(x?.mensagem.texto,'Foto');
});
Deno.test('Zernio usa o id nativo para deduplicar webhook e histórico',()=>{
 const x=zernioMensagem({event:'message.received',message:{id:'zernio-id',platformMessageId:'wamid',text:'Oi',sender:{id:'contato'}},conversation:{id:'cv'}});
 eq(x?.mensagem.id,'wamid');eq(zernioMensagem({event:'reaction.received'}),null);
 const sent=zernioMensagem({event:'message.sent',message:{id:'x',text:'Resposta',sender:{name:'Empresa',id:'empresa'}},conversation:{id:'cv'}});
 eq(sent?.conversa.nome,undefined);eq(sent?.conversa.endereco,undefined);
});
Deno.test('status não retrocede com webhook atrasado',()=>{eq(statusMensagem('lida','enviada'),'lida');eq(statusMensagem('incerto','entregue'),'entregue');});
Deno.test('URL de servidor rejeita destinos internos e credenciais',()=>{
 for(const s of ['http://example.com','https://localhost','https://127.0.0.1','https://10.1.1.1','https://192.168.1.2','https://172.16.1.1','https://user:key@example.com','https://example.com?k=key','https://[::1]']){let failed=false;try{urlPublica(s);}catch{failed=true;}eq(failed,true);}
 eq(urlPublica('https://evo.example.com').hostname,'evo.example.com');
});
Deno.test('assinatura HMAC exige corpo original e segredo correto',async()=>{
 const raw='{"message":"olá"}',key=await crypto.subtle.importKey('raw',new TextEncoder().encode('segredo'),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 const bytes=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(raw)));const sig=[...bytes].map(n=>n.toString(16).padStart(2,'0')).join('');
 eq(await hmacValido(raw,sig,'segredo'),true);eq(await hmacValido(raw+' ',sig,'segredo'),false);eq(await hmacValido(raw,sig,'outro'),false);
});
