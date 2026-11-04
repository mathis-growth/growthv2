// Conferência das assinaturas, sempre sobre os bytes originais do corpo.
const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, '0')).join('');
const b64 = (b: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(b)));
const igual = (a: string, b: string) => { if (a.length !== b.length) return false; let d = 0; for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i); return d === 0; };

async function hmac(alg: string, segredo: string, corpo: Uint8Array) {
  const k = await crypto.subtle.importKey('raw', new TextEncoder().encode(segredo), { name: 'HMAC', hash: alg }, false, ['sign']);
  return await crypto.subtle.sign('HMAC', k, corpo);
}
// Kiwify: HMAC-SHA1 em hexadecimal minúsculo, no parâmetro signature
export async function confereKiwify(segredo: string, corpo: Uint8Array, assinatura: string) {
  if (!segredo || !assinatura) return false;
  return igual(hex(await hmac('SHA-1', segredo, corpo)), assinatura.trim());
}
// Eduzz: HMAC-SHA256 no cabeçalho x-signature. A documentação não diz a codificação: aceita hexadecimal e base64.
export async function confereEduzz(segredo: string, corpo: Uint8Array, assinatura: string) {
  if (!segredo || !assinatura) return false;
  const a = assinatura.trim(), s = await hmac('SHA-256', segredo, corpo);
  return igual(hex(s), a.toLowerCase()) || igual(b64(s), a);
}
