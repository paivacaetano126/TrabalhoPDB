# Apresentação: Do artigo ao banco de dados: estruturas do PDB citadas na literatura

**Disciplina:** FCM 2026 (Prof. Dr. Thomas Nogueira Vilches)  
**Equipe:**  
- **José Victor Orlandi** (apresentador: gráficos, relatório e apresentação)  
- **Ricardo de Paiva Caetano** (seleção de artigos, PDFs, regex e scraping)  
- **Pedro Yuji Yashima** (modelagem relacional SQL e integração no tidyverse)  

**Tempo estimado de apresentação:** 12 a 15 minutos  

---

## Estrutura dos slides

| Slide | Título | Conteúdo | Figura |
|:---:|---|---|:---:|
| **1** | Capa | Identificação do projeto, disciplina e equipe | — |
| **2** | Contexto e pergunta | Por que minerar PDBs citados na literatura? | Fluxo conceitual |
| **3** | As duas revistas | Dicotomia experimental (IUCrJ) vs computacional (PLoS CB) | Comparativo de escopos |
| **4** | Arquitetura do pipeline | Do PDF ao banco relacional em PostgreSQL | Diagrama do pipeline |
| **5** | Desafios de engenharia | S3 bucket, heurísticas regex, scraping com rate-limit | Exemplos de ruído |
| **6** | Modelo relacional | Schema 3FN, chaves por identidade, tabelas associativas | Relações SQL |
| **7** | Resultado 1: Origem | Depósito inédito vs reaproveitamento (34,1% vs 0%) | `fig1_origem_estruturas.png` |
| **8** | Resultado 2: Idade | A inércia de validação computacional (4,4 vs 12,6 anos) | `fig2_distribuicao_idade.png` |
| **9** | Resultado 3: Resolução | Raio X sub-2.0 Å e proporção de Crio-ME | `fig3_resolucao_metodos.png` |
| **10** | Resultado 4: Alvos | Proteínas mais citadas: Beta-lactamases e integrinas | `fig4_top_uniprot_proteinas.png` |
| **11** | Volume e densidade | Concentração de estruturas por publicação | `fig5_mencoes_por_artigo.png` |
| **12** | Conclusões | Síntese dos dados e reprodutibilidade | Repositório do projeto |

---

## Slide 1: Capa

### Conteúdo visual
- **Título:** Do artigo ao banco de dados: estruturas do PDB citadas na literatura
- **Subtítulo:** Análise comparativa entre periódicos experimentais (IUCrJ) e computacionais (PLoS Computational Biology) em 2026
- **Disciplina:** Tópicos em Informática em Saúde e Bancos de Dados (FCM 2026)
- **Docente:** Prof. Dr. Thomas Nogueira Vilches
- **Equipe:** José Victor Orlandi, Ricardo de Paiva Caetano, Pedro Yuji Yashima

> ### Roteiro de fala (José Victor)
> *"Bom dia a todos, bom dia professor Thomas. Meu nome é José Victor e vou apresentar o trabalho desenvolvido junto com o Ricardo Caetano e o Pedro Yashima. Nosso projeto investiga o caminho que vai do artigo científico até o banco de dados relacional, mapeando quais estruturas do Protein Data Bank estão sendo de fato citadas na literatura recente de 2026. A ideia foi verificar se periódicos experimentais e computacionais lidam com essas coordenadas da mesma forma ou se desempenham papéis diferentes no ecossistema da biologia estrutural."*

---

## Slide 2: Contexto e motivação

### Conteúdo visual
- O acervo do PDB ultrapassa 220 mil estruturas depositadas desde 1971.
- O catálogo oficial registra o que existe, mas não indica a frequência de uso atual pela comunidade.
- Certas estruturas nunca foram citadas após o depósito, enquanto outras servem de modelo contínuo para simulações e ensaios farmacológicos.
- A citação direta no texto completo do artigo reflete o consumo prático dessas coordenadas.

> ### Roteiro de fala (José Victor)
> *"Para situar o problema: o PDB tem mais de 220 mil entradas. Mas a base de dados isolada funciona como um arquivo histórico cumulativo. Ela mostra o que foi depositado ao longo de cinquenta anos, sem dizer o que a comunidade está usando hoje. Muitas estruturas foram depositadas uma única vez e não voltaram a ser citadas. Outras viraram referências obrigatórias para simulações e testes de ancoramento molecular. A forma mais direta de medir esse uso real é analisar os artigos científicos publicados recentemente."*

---

## Slide 3: O desenho experimental

### Conteúdo visual
- **IUCrJ (União Internacional de Cristalografia):**
  - Periódico focado em determinação experimental de estruturas (raios X, Crio-ME, RMN).
  - Hipótese: periódico gerador de novas coordenadas.
- **PLoS Computational Biology:**
  - Periódico focado em bioinformática, modelagem matemática e simulações.
  - Hipótese: periódico consumidor de estruturas já depositadas.
- **Amostra:** Os 10 artigos mais novos de 2026 de cada periódico com ao menos 3 códigos PDB citados (total de 20 artigos).

> ### Roteiro de fala (José Victor)
> *"Para testar essa hipótese, selecionamos duas revistas complementares: a IUCrJ, voltada à cristalografia e biofísica experimental, e a PLoS Computational Biology, focada em bioinformática e modelagem. Selecionamos os 10 artigos mais recentes de 2026 de cada uma que continham pelo menos 3 códigos PDB no texto, totalizando 20 manuscritos para análise."*

---

## Slide 4: Arquitetura do pipeline

### Conteúdo visual
- **Fluxo completo dos scripts em R:**
  1. `00_selecionar_artigos.R`: consulta à API da Europe PMC (acesso aberto e anotações PDB)
  2. `01_baixar_pdfs.R`: download dos arquivos completos pelo bucket S3 público do PubMed Central
  3. `02_extrair_pdb.R`: mineração de texto nos PDFs via `pdftools` com expressões regulares e heurísticas de proximidade
  4. `03_scraping_pdb.R`: coleta de metadados no RCSB PDB via `rvest` com controle de taxa
  5. `04_banco_sql.R`: modelagem e carga em PostgreSQL (schema `pdb`, 3FN)
  6. `05_graficos.R`: visualizações com `ggplot2` e testes de hipótese

> ### Roteiro de fala (José Victor)
> *"O pipeline foi totalmente construído em R de forma modular. O primeiro script busca as publicações na API da Europe PMC; o segundo baixa os PDFs diretamente do bucket aberto da AWS; o terceiro extrai os códigos PDB do texto; o quarto coleta os metadados no portal do RCSB; o quinto estrutura e carrega os dados no PostgreSQL; e o sexto gera os gráficos e as análises estatísticas. Cada etapa roda de forma independente."*

---

## Slide 5: Desafios práticos de engenharia

### Conteúdo visual
- **Download dos PDFs:** O site do PubMed Central restringe downloads automatizados; contornamos utilizando o repositório público da AWS S3 (`pmc-oa-opendata.s3.amazonaws.com`).
- **Filtragem de ruído nos códigos de 4 caracteres:**
  - A regex alfanumérica pura captura anos (2026), aparelhos de laboratório (`LC-20AD`) e unidades (`100ms`).
  - Solução: exigência de pelo menos uma letra nas 3 últimas posições e presença de termos de contexto (*PDB, accession, coordinates*) até 6 linhas acima.
- **Raspagem responsável:** Intervalo de 2 segundos entre chamadas ao RCSB, registro de códigos inexistentes (404) e identificação de depósitos embargados (`5WH0`).

> ### Roteiro de fala (José Victor)
> *"Durante a implementação, lidamos com algumas questões técnicas importantes. Como o portal do PMC barra downloads em lote, buscamos os arquivos pelo bucket aberto na AWS. Além disso, um código PDB tem apenas quatro caracteres alfanuméricos. Uma regex simples captura anos e modelos de equipamentos, como a bomba LC-20AD citada na metodologia. Nós resolvemos isso exigindo ao menos uma letra nas três posições finais e checando a presença de termos como 'PDB' e 'entry' na vizinhança do texto. No scraping, mantivemos pausas de dois segundos entre requisições para respeitar o servidor do RCSB."*

---

## Slide 6: Modelagem relacional no PostgreSQL

### Conteúdo visual
- Schema dedicado: `pdb`
- Convenções da disciplina: prefixos `ref_` para tabelas de domínio e `tab_` para tabelas de dados.
- Chaves primárias por identidade (`GENERATED ALWAYS AS IDENTITY`).
- Relação N:M entre entidades estruturais e códigos UniProt resolvida pela tabela associativa `tab_entidade_uniprot`.
- Carga automatizada no R com a função `trocar_id()` para tratamento das chaves estrangeiras.

> ### Roteiro de fala (José Victor)
> *"Na parte de banco de dados, o Pedro estruturou o modelo na Terceira Forma Normal, seguindo o padrão das aulas com prefixos ref_ e tab_. Um ponto relevante foi o relacionamento entre cadeias proteicas e identificadores UniProt: certas estruturas contêm múltiplos domínios ou são construções quiméricas, enquanto anticorpos muitas vezes não possuem registro no UniProt. A tabela associativa tab_entidade_uniprot garantiu que esses casos fossem representados sem perda de integridade."*

---

## Slide 7: Resultado 1: Depósito inédito vs reaproveitamento

### Conteúdo visual
- **Figura 1:** Comparativo da taxa de depósito por revista
- **IUCrJ:** 34,1% das estruturas citadas foram depositadas pelos próprios autores (30 estruturas inéditas).
- **PLoS Comput Biol:** 0,0% de depósitos inéditos: 100% das estruturas foram reutilizadas de trabalhos anteriores.
- **Teste estatístico:** Teste exato de Fisher com $p = 2,43 \times 10^{-5}$.

> ### Roteiro de fala (José Victor)
> *"Passando aos resultados, a primeira figura mostra a comparação entre estruturas depositadas pelo próprio artigo e estruturas reutilizadas da literatura, verificada pelo cruzamento dos DOIs. Na IUCrJ, 34,1% das estruturas citadas eram novos depósitos descritos naquele manuscrito. Na PLoS Computational Biology, essa taxa foi zero: todas as estruturas identificadas eram dados prévios reutilizados. O teste de Fisher confirmou a diferença com p-valor de 2,4 vezes 10 a menos 5, comprovando a atuação da revista computacional como usuária secundária dessas coordenadas."*

---

## Slide 8: Resultado 2: Idade das estruturas citadas

### Conteúdo visual
- **Figura 2:** Distribuição da idade das estruturas (anos entre o depósito original e a publicação em 2026)
- **Mediana temporal:**
  - IUCrJ: **4,4 anos** (concentração expressiva em dados pós-2020)
  - PLoS Comput Biol: **12,6 anos** (com estruturas datadas de 1986)
- **Teste de Wilcoxon:** $W = 503$, $p = 2,61 \times 10^{-8}$.

> ### Roteiro de fala (José Victor)
> *"O segundo dado diz respeito à idade dessas estruturas no momento da citação. Calculamos o intervalo entre a data de depósito no PDB e a publicação em 2026. A mediana na IUCrJ foi de 4,4 anos, enquanto na PLoS Computational Biology foi de 12,6 anos, chegando a estruturas depositadas em 1986. Isso acontece porque a bioinformática necessita de alvos consolidados e historicamente validados por dados experimentais de afinidade e cinética para calibrar seus algoritmos de simulação e docking."*

---

## Slide 9: Resultado 3: Métodos experimentais e resolução

### Conteúdo visual
- **Figura 3:** Resolução estrutural em difração de raios X e Criomicroscopia Eletrônica
- **Raios X:** Resolução mediana superior na IUCrJ (1,70 Å vs 2,21 Å na PLoS; Wilcoxon $p = 0,0025$).
- **Criomicroscopia Eletrônica:**
  - IUCrJ: Representa 34,9% das estruturas catalogadas (mediana 2,89 Å).
  - PLoS Comput Biol: Representa 18,2% dos alvos (mediana 3,65 Å).

> ### Roteiro de fala (José Victor)
> *"Ao analisar os métodos biofísicos, vimos que as estruturas cristalográficas por raios X citadas na IUCrJ têm resolução significativamente melhor, com mediana de 1,70 Å contra 2,21 Å na PLoS. Além disso, a Criomicroscopia Eletrônica já responde por mais de um terço das estruturas na revista experimental, com resolução mediana de 2,89 Å. Na computação, a presença de Crio-ME ainda é menor, refletindo a preferência de algoritmos clássicos por coordenadas rígidas de difração de alta resolução."*

---

## Slide 10: Resultado 4: Proteínas e alvos mais citados

### Conteúdo visual
- **Figura 4:** Identificadores UniProt mais frequentes na amostra
- **Beta-lactamase CTX-M-15 (`G3G192`):** alvo com maior número de citações (11 estruturas em 2 artigos).
- **Outros alvos com múltiplos depósitos:**
  - Integrina alfa-M / CD11b (`P11215`): inflamação e adesão leucocitária
  - Glicoproteína Spike do SARS-CoV-2 (`P0DTC2`): 7 estruturas determinadas por Crio-ME
  - L-asparaginase 2 (`P00805`): enzima terapêutica com 10 estruturas
  - Complexo MAT2A/MAT2B (`P31153`): alosteria no metabolismo de metionina

> ### Roteiro de fala (José Victor)
> *"No nível molecular, mapeado pelo UniProt, a proteína mais recorrente foi a Beta-lactamase CTX-M-15, com 11 estruturas diferentes citadas em dois artigos. Esse resultado reflete o esforço de pesquisa em torno da resistência bacteriana a antibióticos. Também encontramos alvos terapêuticos relevantes, como a integrina CD11b, a L-asparaginase e estruturas da proteína Spike do SARS-CoV-2."*

---

## Slide 11: Volume de citações por artigo individual

### Conteúdo visual
- **Figura 5:** Menções e diversidade estrutural por publicação
- **PLoS Comput Biol:** Artigos com citações pontuais, referenciando de 3 a 5 estruturas de partida.
- **IUCrJ:** Manuscritos densos, ultrapassando 20 códigos PDB em um único artigo.
- **Contexto:** Triagens de múltiplos fragmentos cristalográficos e artigos de revisão metodológica de maquinarias macromoleculares.

> ### Roteiro de fala (José Victor)
> *"A distribuição de citações por artigo individual mostra comportamentos bem distintos. Enquanto a PLoS Computational Biology costuma citar entre 3 e 5 estruturas específicas usadas como ponto de partida da modelagem, publicações da IUCrJ chegam a citar mais de 20 códigos PDB. Isso ocorre quando os autores publicam triagens de fragmentos químicos ou revisões técnicas detalhando grandes complexos biológicos."*

---

## Slide 12: Conclusões

### Conteúdo visual
- **Engenharia de dados:** Pipeline funcional e reprodutível conectando APIs, nuvem (S3), mineração de texto e PostgreSQL normalizado (3FN).
- **Achado científico:** Evidência quantitativa da especialização entre revistas: periódicos experimentais produzem novos dados de alta resolução recente, enquanto periódicos computacionais reutilizam alvos consolidados da literatura.
- **Reprodutibilidade:** Código completo, esquemas SQL e bases disponíveis no repositório GitHub.

> ### Roteiro de fala (José Victor)
> *"Para concluir: cumprimos os objetivos da disciplina, construindo um pipeline que automatiza a coleta, a extração, a raspagem e a persistência em banco relacional. Os dados mostram a complementaridade entre as duas áreas: a pesquisa experimental assume a elucidação de novas coordenadas de alta precisão, enquanto a bioinformática transforma estruturas consolidadas em plataformas duradouras para testes e simulações. Agradeço a atenção de todos e estamos à disposição para dúvidas!"*
