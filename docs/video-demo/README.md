# Vídeo de demonstração do Growths

Material para gerar o vídeo de demonstração (redes sociais). O vídeo (`growths-demo.mp4`, 1920×1080, 7 min) não fica no repositório por causa do tamanho.

- `roteiro.md`: o roteiro com as falas, para gravar a voz (um arquivo por cena).
- `roteiro.py`: as falas, cena a cena (a fonte do roteiro).
- `gravar.py`: grava cada cena com o Playwright na tela real (`python3 gravar.py [00 01 …]`).
- `front_video.py`: abre a tela ligada ao banco local `video` (PostgREST na porta 3302).
- `seed_video.sql` e `seed_receita.sql`: dados fictícios da Escola Aurora usados **só no banco do vídeo**: cenários, experimentos, equipe com comissões e vendas extras para o negócio aparecer saudável.
- `roteiro-reels.md`, `reels.py` e `junta_reel.sh`: a versão vertical para Reels (1080×1920, 1:40): roteiro, gravação e montagem.
- `junta.sh`: junta as cenas num MP4 só. `folha.sh`: folha de quadros para revisar uma cena. `gera_roteiro.py`: monta o `roteiro.md` com os tempos reais das cenas.
