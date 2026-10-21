# Roteiro falado do vídeo (a Rebecka grava cada bloco). Cada cena: id, título na tela, o que aparece, e a fala.
CENAS = [
 ('00', 'Abertura', 'Cartão "Growths"', [
  "Oi, eu sou a Rebecka, da Mathisa. Hoje eu vou te mostrar por dentro o Growths, a ferramenta que a gente usa para enxergar o crescimento dos nossos clientes. E que, a partir de agora, os nossos clientes também passam a acessar, para olhar os próprios dados."]),
 ('01', 'O negócio numa tela só', 'Dashboard: funil, vendas, caixa, lucro, campanhas ativas e CAC', [
  "Essa é a primeira tela. Aqui está o negócio inteiro: quantas pessoas estão no funil, quantas viraram cliente, quanto vendeu, quanto entrou no caixa e quanto sobrou de lucro.",
  "Logo abaixo ficam as campanhas que estão rodando, cada uma com a meta de leads e de vendas, o investimento, o custo por cliente e o retorno."]),
 ('02', 'Criando uma campanha', 'Campanhas → Nova campanha: nome, modelo, estratégia, produto, datas, orçamento e metas', [
  "Tudo começa na campanha. Eu clico em nova campanha, dou um nome, escolho se é um lançamento ou um perpétuo, a estratégia e o produto.",
  "Coloco as datas, o orçamento e as metas: quantos leads, quantas vendas, quanto eu aceito pagar por lead e por cliente. Salvou, a campanha já nasce com as etapas da estratégia e com o projeto da equipe.",
  "Aqui é uma campanha que já está rodando. No planejamento, eu vejo o que foi planejado ao lado do realizado, e o sistema avisa o que está abaixo da meta."]),
 ('03', 'Rastreamento: de onde vem cada lead', 'Links e tracking, Captação e metas, Leads por origem e a ficha do lead', [
  "Agora, o rastreamento. Cada anúncio tem o seu link com UTM, gerado aqui. Então eu sei exatamente qual criativo trouxe cada pessoa.",
  "Os leads entram sozinhos, do formulário da página, da Respondi ou do Meta, e caem na campanha certa, por canal, com meta de leads por dia.",
  "Em leads por origem, eu vejo qual anúncio trouxe mais leads, quantos se qualificaram e quantos compraram.",
  "E se eu abro uma pessoa, aparece a jornada dela: por onde entrou, cada ponto de contato e o que comprou."]),
 ('04', 'Anúncios', 'Mídia paga: investimento, CPL, CTR, CAC e ROAS por canal, por dia e por criativo; Integrações', [
  "Na mídia paga, eu acompanho o investimento, o custo por lead, a taxa de clique, o custo por cliente e o retorno, por canal e por dia.",
  "E o sistema avisa quais criativos estão cansando e qual vale escalar.",
  "E agora o Growths conecta direto com o Meta e com o Google: anúncios, Instagram e YouTube entram sozinhos, sem planilha."]),
 ('05', 'Os cálculos: de onde vem cada número', 'Árvore dos números: CAC → investimento → canal → anúncio; Lucro → despesas → conta → lançamento', [
  "Uma coisa que eu faço questão: nenhum número aqui é caixa-preta. Eu clico no CAC, e o sistema mostra a conta: investimento dividido por clientes.",
  "Clico no investimento, e ele abre por canal. Clico no canal, aparecem os anúncios. E assim eu vou descendo até o dado de origem.",
  "Vale para o financeiro também: clico no lucro, vejo as despesas, a conta e o lançamento que gerou aquele valor."]),
 ('06', 'Finanças', 'Dashboard financeiro, Custos e margens, ponto de equilíbrio e Comissões', [
  "No financeiro, eu tenho o caixa de hoje, o que vai entrar, o que vai sair e a projeção dos próximos trinta dias.",
  "Em custos e margens, aparece o lucro de verdade do mês, a margem e quanto falta para a meta. O ponto de equilíbrio mostra quanto precisa vender para empatar.",
  "E as comissões: vendedor, coprodutor e estrategista, cada um com a sua regra. O sistema calcula sozinho a cada venda e, no fim do mês, vira conta a pagar."]),
 ('07', 'Growth', 'Growth Model, cenários, Ciclo de Growth e Resultados', [
  "E a parte que eu mais gosto: o Growth. O real fica travado, e no cenário eu mexo. Se eu subo o preço do curso, receita, imposto, margem e lucro recalculam na hora.",
  "Cada ideia vira um cenário, e o cenário aprovado vai para o ciclo de Growth, priorizado por impacto, confiança e facilidade.",
  "No fim, eu comparo o que foi projetado com o que aconteceu, e registro o aprendizado: escalar, repetir ou descartar."]),
 ('08', 'Encerramento', 'Cartão final', [
  "Esse é o Growths. Dados à vista, de onde vem cada número e o que fazer com ele. Se você quer enxergar o seu crescimento assim, fala com a gente."]),
]
def palavras(c): return sum(len(f.split()) for f in c[3])
if __name__ == '__main__':
    tot = 0
    for c in CENAS:
        s = palavras(c) / 2.35; tot += s
        print(c[0], c[1], palavras(c), 'palavras ≈ %.0fs' % s)
    print('total ≈ %.0f s (%.1f min)' % (tot, tot / 60))
