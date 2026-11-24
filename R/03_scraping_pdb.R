library(tidyverse)
library(rvest)

mencoes <- read.csv("saida/mencoes_pdb.csv")
codigos <- unique(mencoes$codigo_pdb)

# a pagina do rcsb ja vem montada no html, nao precisa do chromote aqui
site <- "https://www.rcsb.org/structure/"

# so busca o que ainda nao foi buscado (depois isso vira consulta no banco)
arq_estruturas <- "saida/estruturas.csv"
arq_entidades <- "saida/entidades.csv"
arq_nao_achou <- "saida/codigos_nao_encontrados.csv"

# tira o que nao e mais citado, senao o codigo velho vai pro banco
if (file.exists(arq_estruturas)) read.csv(arq_estruturas, colClasses = c(data_deposito = "Date")) %>%
  filter(codigo_pdb %in% codigos) %>% write.csv(arq_estruturas, row.names = FALSE)
if (file.exists(arq_entidades)) read.csv(arq_entidades, colClasses = "character") %>%
  filter(codigo_pdb %in% codigos) %>% write.csv(arq_entidades, row.names = FALSE)
if (file.exists(arq_nao_achou)) read.csv(arq_nao_achou) %>%
  filter(codigo_pdb %in% codigos) %>% write.csv(arq_nao_achou, row.names = FALSE)

ja_tem <- c()
if (file.exists(arq_estruturas)) ja_tem <- c(ja_tem, read.csv(arq_estruturas)$codigo_pdb)
if (file.exists(arq_nao_achou)) ja_tem <- c(ja_tem, read.csv(arq_nao_achou)$codigo_pdb)
fila <- setdiff(codigos, ja_tem)

message(length(fila), " codigos pra buscar")

# o rcsb escreve "&nbsp" sem ponto e virgula, sobra no texto
pega_campo <- function(page, seletor) {
  x <- page %>% html_element(seletor) %>% html_text2()
  x <- gsub("&nbsp;?", " ", x)
  trimws(str_remove(x, "^[^:]*:"), "both")
}

# cada proteina da estrutura tem uma tabela "Entity ID" com molecula, organismo e link pro uniprot
pega_entidades <- function(page, cod) {
  # page <- read_html(paste0(site, "7MJJ")); cod <- "7MJJ"
  tabelas <- page %>% html_elements("[id^='table_macromolecule-protein-entityId-']")

  map(tabelas, function(tab) {
    linhas <- html_table(tab, header = FALSE)
    cab <- which(linhas[[1]] == "Molecule")[1]
    if (is.na(cab)) return(NULL)
    campos <- setNames(as.character(linhas[cab + 1, ]), as.character(linhas[cab, ]))
    detalhes <- gsub("&nbsp;?", " ", campos["Details"])

    # quimera ou anticorpo pode ter mais de um uniprot ou nenhum
    uniprot <- tab %>% html_elements("a[href*='uniprot.org/uniprot/']") %>%
      html_attr("href") %>% str_extract("[^/]+$") %>% unique()

    tibble(codigo_pdb = cod,
           entidade = as.integer(str_extract(html_attr(tab, "id"), "\\d+$")),
           molecula = campos["Molecule"],
           organismo = campos["Organism"],
           uniprot = if (length(uniprot) > 0) paste(uniprot, collapse = ";") else NA,
           gene = str_trim(str_match(detalhes, "Gene Names:\\s*(.*?)\\s*(EC:|$)")[, 2]),
           ec = str_extract(detalhes, "(?<=EC:)\\s*[\\d.n-]+") %>% str_trim())
  }) %>% list_rbind()
}

dados <- map(fila, function(cod) {
  # cod <- fila[1]
  message("Baixando dados de: ", cod)
  Sys.sleep(2)

  # codigo que nao existe da 404 e o read_html para com erro
  page <- tryCatch(read_html(paste0(site, cod)), error = function(e) NULL)
  if (is.null(page)) return(tibble(codigo_pdb = cod, achou = FALSE))

  # codigo reservado e ainda nao liberado cai numa pagina "unreleased" sem titulo (o 25CN fez isso)
  titulo <- page %>% html_element("#structureTitle") %>% html_text2()
  if (is.na(titulo) | trimws(titulo) == "") return(tibble(codigo_pdb = cod, achou = FALSE))

  texto <- gsub("&nbsp;?", " ", html_text2(page))

  tibble(
    codigo_pdb = cod,
    achou = TRUE,
    nome = page %>% html_element("#structureTitle") %>% html_text2(),
    classificacao = pega_campo(page, "#header_classification"),
    organismo = pega_campo(page, "#header_organism"),
    metodo = pega_campo(page, "#exp_header_0_method"),
    # raio x e crio-me usam id diferente pra resolucao
    resolucao = pega_campo(page, "[id^='exp_header_0_'][id$='_resolution']"),
    data_deposito = str_extract(texto, "(?<=Deposited:)\\s*\\d{4}-\\d{2}-\\d{2}"),
    massa_kda = str_extract(pega_campo(page, "#contentStructureWeight"), "[\\d.,]+"),
    n_cadeias = str_extract(texto, "(?<=Unique protein chains: )\\d+"),
    doi_estrutura = pega_campo(page, "#pubmedDOI"),
    entidades = list(pega_entidades(page, cod))
  )
}) %>% list_rbind()

# fila vazia volta tibble sem coluna
if (nrow(dados) == 0) dados <- tibble(codigo_pdb = character(), achou = logical())

nao_achou <- dados %>% filter(!achou) %>% select(codigo_pdb)
if (nrow(nao_achou) > 0) {
  if (file.exists(arq_nao_achou)) nao_achou <- bind_rows(read.csv(arq_nao_achou), nao_achou)
  write.csv(nao_achou, arq_nao_achou, row.names = FALSE)
}

# se a rodada so teve codigo que nao existe, nao tem coluna nenhuma pra arrumar
if (any(dados$achou)) {
  dados <- dados %>% filter(achou)

  # uma linha por proteina de cada estrutura, vai pra outro arquivo
  # tudo como texto pra juntar com o que ja tinha sem brigar por tipo (uniprot so NA vira logical)
  entidades <- list_rbind(dados$entidades) %>% mutate(across(everything(), as.character))
  if (file.exists(arq_entidades)) entidades <- bind_rows(read.csv(arq_entidades, colClasses = "character"), entidades)
  if (nrow(entidades) > 0) write.csv(entidades, arq_entidades, row.names = FALSE)

  dados <- dados %>%
    select(-achou, -entidades) %>%
    mutate(resolucao = as.numeric(str_extract(resolucao, "[\\d.]+")),
           massa_kda = as.numeric(gsub(",", "", massa_kda)),
           n_cadeias = as.integer(n_cadeias),
           data_deposito = as.Date(trimws(data_deposito)),
           doi_estrutura = str_remove(doi_estrutura, "https://doi.org/"))

  # junta com o que ja tinha
  if (file.exists(arq_estruturas)) dados <- bind_rows(read.csv(arq_estruturas, colClasses = c(data_deposito = "Date")), dados)
  write.csv(dados, arq_estruturas, row.names = FALSE)
}
