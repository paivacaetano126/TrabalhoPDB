library(tidyverse)
library(pdftools)

artigos <- read.csv("dados/artigos_selecionados.csv")

# codigo pdb: 1 digito de 1 a 9 + 3 caracteres, com pelo menos uma letra (senao pega ano, 2025 etc)
# a IUCrJ escreve em minusculo (9gt0) e a PLoS em maiusculo (6N29)
padrao_pdb <- "\\b[1-9](?=[a-z0-9]{0,2}[a-z])[a-z0-9]{3}\\b"

# so vale se tiver alguma dessas palavras perto
padrao_contexto <- "pdb|rcsb|protein data bank|entry|entries|accession|structure code"
janela <- 6

run_pdb <- function(x, conteudo) {
  # x <- 1 # indice

  pos <- grep(padrao_pdb, conteudo, ignore.case = TRUE, perl = TRUE)
  if (length(pos) == 0) return(NULL)

  # na IUCrJ os codigos depositados vem num bloco "PDB references: ... Supporting information"
  bloco <- c()
  ini <- grep("PDB references", conteudo)
  fim <- grep("Supporting information", conteudo)
  if (length(ini) > 0 & length(fim) > 0) bloco <- ini[1]:fim[fim > ini[1]][1]

  dados <- lapply(pos, function(j) {
    # olha umas linhas pra cima: lista de codigo quebra linha, tabela tem o "PDB" so no cabecalho
    vizinhas <- paste(conteudo[max(1, j - janela):min(length(conteudo), j + 1)], collapse = " ")
    if (!(j %in% bloco) & !str_detect(vizinhas, regex(padrao_contexto, ignore_case = TRUE))) return(NULL)

    # tira mapa de densidade (2mFo-DFc), senao vira o codigo 2MFO
    linha <- str_remove_all(conteudo[j], "\\d?m?F[oc]\\W{0,3}\\d?D?F[oc]")
    codigos <- str_extract_all(linha, regex(padrao_pdb, ignore_case = TRUE))[[1]]
    if (length(codigos) == 0) return(NULL)
    data.frame(codigo_pdb = codigos,
               contexto = str_squish(conteudo[j]))
  })
  dados <- Reduce(rbind, dados)
  if (is.null(dados)) return(NULL)

  # tira ordinal (2nd, 3rd) e unidade (10mJ, 100ms, 7fs)
  dados <- dados %>%
    mutate(codigo_pdb = toupper(codigo_pdb)) %>%
    filter(!str_detect(codigo_pdb, "^\\d+(ST|ND|RD|TH|MJ|MS|FS|NS|PS|NM|UM|MM|KDA|KGY|MGY|HZ|KEV|MG|ML|UL|K)$"))

  dados %>%
    group_by(codigo_pdb) %>%
    summarise(n_mencoes = n(), contexto = first(contexto)) %>%
    mutate(pmcid = artigos$pmcid[x], .before = 1)
}

mencoes <- lapply(1:nrow(artigos), function(x) {
  arquivo <- sprintf("pdfs/%02d_%s.pdf", artigos$id[x], artigos$pmcid[x])
  message("Lendo: ", arquivo)

  conteudo <- pdf_text(arquivo)
  conteudo <- str_split(conteudo, "\\n")
  conteudo <- Reduce(c, conteudo)

  run_pdb(x, conteudo)
})
mencoes <- Reduce(rbind, mencoes)

dir.create("saida", showWarnings = FALSE)
write.csv(mencoes, "saida/mencoes_pdb.csv", row.names = FALSE)

# quantos codigos por artigo
mencoes %>%
  count(pmcid, name = "n_codigos") %>%
  right_join(artigos %>% select(id, revista, pmcid), by = "pmcid") %>%
  arrange(id) %>%
  print()
