# Skills complementares para o time do Growth

Este pacote acrescenta três agentes e duas skills aos agentes existentes. Ele complementa, não substitui, Frank, Ulisses, Renata, Marina, Lara, Breno, Vitor e Isabela.

## Conteúdo

- `camila/`: Operações do Growth e configuração segura de campanhas.
- `bia/`: CRM, jornadas e automações de e-mail e mensagens.
- `nina/`: produto, experiência e implementação de melhorias na interface.
- `isabela/skills/analisar-dados-do-growth/`: análise integrada dos dados internos do Growth.
- `ulisses/skills/pesquisa-de-mercado/`: pesquisa de mercado com fontes verificáveis.
- `compartilhadas/`: requisitos de leitura de dados e segurança que devem ser vinculados a todos os agentes.

## Integração ao pacote atual

Copie as pastas dos novos agentes para a raiz de perfis do seu runtime. Para Isabela e Ulisses, copie somente as novas pastas de skills para os perfis existentes. Mantenha as skills já instaladas.

Antes de ativar:

1. Preencha nos `SOUL.md` os dados da empresa, do dono, do público, do tom de voz e das regras comerciais.
2. Configure as skills compartilhadas no mecanismo de skills do runtime, e associe-as aos oito perfis atuais e aos três novos. Use `consultar-growth` apenas quando houver conector autorizado para a base do Growth.
3. Defina os conectores reais disponíveis para interface, Supabase, anúncios e canais. As skills não presumem nomes de ferramentas nem inventam acesso.
4. Revise as regras antigas de conexão. O pacote recebido instrui aceitar tokens enviados em mensagens, inclusive em grupos. Essa instrução conflita com o padrão seguro desta proposta; substitua-a por conexão em fluxo protegido/cofre de secrets antes de operar contas reais.
5. Comece com leitura e rascunhos. Habilite gravação ou publicação apenas após validar permissões, aprovações e escopo por workspace.

## Handoffs sugeridos

- Ulisses entrega estratégia e pesquisa para Camila configurar a campanha.
- Renata e Lara entregam textos e peças para Marina, Breno e Bia usarem nos canais previstos.
- Bia prepara os fluxos; Camila confere se estão associados ao evento, campanha, formulário ou produto correto.
- Nina recebe problemas de interface e devolve diagnóstico ou alteração revisável.
- Isabela mede resultados usando a base interna e as plataformas conectadas; envia achados para Ulisses planejar o próximo ciclo.
- Frank continua como único orquestrador e ponto de aprovação do dono.

## Regra geral

As instruções deste pacote descrevem comportamento, não concedem acesso técnico. Cada integração precisa ser provisionada com escopo mínimo, autenticação segura e registro de auditoria. Se uma ferramenta necessária não estiver conectada, o agente informa o bloqueio e entrega o próximo passo sem alegar que executou a ação.
