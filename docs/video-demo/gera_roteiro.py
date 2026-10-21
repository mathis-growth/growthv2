import subprocess
from roteiro import CENAS
def dur(f):
    return float(subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f],capture_output=True,text=True).stdout)
def mmss(s): return '%d:%02d' % (int(s)//60, int(s)%60)
L = ['# Roteiro do vídeo de demonstração do Growths', '',
 'Vídeo: `growths-demo.mp4` (1920×1080, sem voz). Cada cena abaixo tem a hora em que começa no vídeo, quanto tempo dura e o que falar.', '',
 '## Como gravar', '',
 '- **Um arquivo por cena**, com o nome da cena: `cena_01.m4a`, `cena_02.m4a`… Pode gravar no celular (gravador de voz) ou direto no CapCut.',
 '- Lugar quieto, celular a um palmo da boca, sem música de fundo.',
 '- Deixe **2 segundos de silêncio** no começo e no fim de cada arquivo.',
 '- Errou? Pare, respire e repita a frase inteira. Eu corto as partes erradas.',
 '- Fale no seu ritmo de conversa. O tempo de cada cena é folgado: se a fala ficar mais curta, eu deixo a tela respirar; se ficar mais longa, eu estico a cena.',
 '- Pode trocar palavras para soar como você. Só mantenha a ordem dos assuntos, porque ela acompanha o que aparece na tela.', '',
 'Quando me mandar os áudios, eu junto a voz ao vídeo, coloco as legendas e, se você quiser, também corto versões verticais para Reels.', '',
 '## Cenas', '']
t = 0; tot_w = 0
for cid, tit, tela, falas in CENAS:
    d = dur('out/cena_%s.mp4' % cid)
    w = sum(len(f.split()) for f in falas); tot_w += w
    L += ['### %s · %s' % (cid, tit), '',
          '**No vídeo:** %s a %s (%s s) · **Na tela:** %s · **Fala:** cerca de %d s' % (mmss(t), mmss(t + d), round(d), tela, round(w / 2.35)), '']
    for f in falas: L += ['> ' + f, '']
    t += d
L += ['---', '', 'Duração total do vídeo: %s. Fala total: cerca de %s.' % (mmss(t), mmss(tot_w / 2.35))]
open('roteiro.md','w').write('\n'.join(L) + '\n'); print(mmss(t))
