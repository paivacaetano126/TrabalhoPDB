# ==============================================================================
# R/05_graficos.R
# Visualização de Dados e Análise Comparativa das Estruturas PDB Citadas
# Trabalho da disciplina FCM 2026 (Prof. Thomas Nogueira Vilches)
# Autores: José Victor Orlandi, Ricardo de Paiva Caetano, Pedro Yuji Yashima
# Responsável por esta etapa: José Victor Orlandi
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
})

# Garante diretório de trabalho na raiz do repositório
if (file.exists("dados/artigos_selecionados.csv")) {
  raiz <- getwd()
} else if (file.exists("../dados/artigos_selecionados.csv")) {
  setwd("..")
  raiz <- getwd()
} else if (file.exists("C:/Users/vitor/.gemini/antigravity/scratch/TrabalhoPDB/dados/artigos_selecionados.csv")) {
  setwd("C:/Users/vitor/.gemini/antigravity/scratch/TrabalhoPDB")
  raiz <- getwd()
}

# Garante diretório de saída para as figuras
dir_figuras <- "figuras"
if (!dir.exists(dir_figuras)) {
  dir.create(dir_figuras, recursive = TRUE)
}

# ------------------------------------------------------------------------------
# 1. Carregamento e Preparação dos Dados
# ------------------------------------------------------------------------------

artigos    <- read.csv("dados/artigos_selecionados.csv", stringsAsFactors = FALSE)
mencoes    <- read.csv("saida/mencoes_pdb.csv", stringsAsFactors = FALSE)
estruturas <- read.csv("saida/estruturas.csv", stringsAsFactors = FALSE)
entidades  <- read.csv("saida/entidades.csv", stringsAsFactors = FALSE)

nao_achou  <- if (file.exists("saida/codigos_nao_encontrados.csv")) {
  read.csv("saida/codigos_nao_encontrados.csv", stringsAsFactors = FALSE)
} else {
  tibble(codigo_pdb = character())
}

# Base consolidada a nível de menção (artigo <-> estrutura)
df_mencoes <- mencoes %>%
  left_join(artigos %>% select(pmcid, revista, doi_artigo = doi, data_publicacao, titulo_artigo = titulo), by = "pmcid") %>%
  left_join(estruturas, by = "codigo_pdb") %>%
  mutate(
    encontrada = case_when(
      codigo_pdb %in% nao_achou$codigo_pdb ~ FALSE,
      codigo_pdb %in% estruturas$codigo_pdb & is.na(metodo) ~ FALSE,
      codigo_pdb %in% estruturas$codigo_pdb ~ TRUE,
      TRUE ~ FALSE
    ),
    data_publicacao = as.Date(data_publicacao),
    data_deposito   = as.Date(data_deposito),
    ano_deposito    = as.integer(format(data_deposito, "%Y")),
    idade_anos      = as.numeric((data_publicacao - data_deposito) / 365.25),
    origem = case_when(
      !encontrada ~ "Não encontrada",
      !is.na(doi_estrutura) & tolower(doi_estrutura) == tolower(doi_artigo) ~ "Depositada pelo próprio artigo",
      TRUE ~ "Reaproveitada da literatura"
    ),
    metodo_simplificado = case_when(
      grepl("X-RAY", metodo, ignore.case = TRUE) ~ "Difração de Raio X",
      grepl("ELECTRON MICROSCOPY", metodo, ignore.case = TRUE) ~ "Criomicroscopia Eletrônica",
      grepl("NMR", metodo, ignore.case = TRUE) ~ "RMN",
      is.na(metodo) ~ "Não informado",
      TRUE ~ "Outro método"
    )
  )

# Base única por estrutura no contexto da revista
df_estruturas_unicas <- df_mencoes %>%
  filter(encontrada) %>%
  distinct(revista, codigo_pdb, .keep_all = TRUE)

# Paleta de cores consistente e elegante
cores_revista <- c(
  "IUCrJ" = "#2b5c8f",              # Azul sóbrio / experimental
  "PLoS Comput Biol" = "#d95f02"   # Laranja terracota / computacional
)

cores_origem <- c(
  "Depositada pelo próprio artigo" = "#1b9e77",
  "Reaproveitada da literatura"    = "#7570b3"
)

tema_trabalho <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a1a1a", margin = margin(b = 6)),
      plot.subtitle = element_text(size = 10, color = "#4a4a4a", margin = margin(b = 10)),
      plot.caption = element_text(size = 8.5, color = "#666666", face = "italic", margin = margin(t = 8)),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(color = "#e5e5e5", linewidth = 0.4),
      panel.grid.major.y = element_line(color = "#e5e5e5", linewidth = 0.4),
      axis.title = element_text(face = "bold", size = 10.5, color = "#222222"),
      axis.text = element_text(size = 9.5, color = "#333333"),
      legend.position = "top",
      legend.title = element_text(face = "bold", size = 9.5),
      legend.text = element_text(size = 9),
      strip.text = element_text(face = "bold", size = 11, color = "#111111"),
      strip.background = element_rect(fill = "#f0f2f5", color = NA)
    )
}

# ------------------------------------------------------------------------------
# Figura 1: Origem das Estruturas (Depósito Novo vs Reaproveitamento)
# ------------------------------------------------------------------------------
cat("Gerando Figura 1: Origem das estruturas por revista...\n")

dados_fig1 <- df_estruturas_unicas %>%
  count(revista, origem) %>%
  group_by(revista) %>%
  mutate(
    total = sum(n),
    pct = n / total,
    rotulo = sprintf("%d (%.1f%%)", n, pct * 100)
  ) %>%
  ungroup()

fig1 <- ggplot(dados_fig1, aes(x = revista, y = n, fill = origem)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65, color = "black", linewidth = 0.25) +
  geom_text(
    aes(label = rotulo),
    position = position_dodge(width = 0.75),
    vjust = -0.5,
    size = 3.6,
    fontface = "bold"
  ) +
  scale_fill_manual(values = cores_origem, name = "Origem da Estrutura:") +
  scale_y_continuous(limits = c(0, max(dados_fig1$n) * 1.18), expand = c(0, 0)) +
  labs(
    title = "Origem das Estruturas PDB Citadas: Perfil Experimental vs Computacional",
    subtitle = "Comparação da taxa de depósito de novas coordenadas vs. reuso de dados preexistentes (Fisher p = 2.4e-5)",
    x = "Revista",
    y = "Número de Estruturas Únicas",
    caption = "Fonte: Dados minerados via Europe PMC e RCSB PDB (FCM 2026 / Vilches). n = 122 estruturas únicas analisadas."
  ) +
  tema_trabalho()

ggsave(file.path(dir_figuras, "fig1_origem_estruturas.png"), fig1, width = 8, height = 5.2, dpi = 300)
ggsave(file.path(dir_figuras, "fig1_origem_estruturas.pdf"), fig1, width = 8, height = 5.2)

# ------------------------------------------------------------------------------
# Figura 2: Idade das Estruturas Citadas (Anos entre Depósito e Artigo)
# ------------------------------------------------------------------------------
cat("Gerando Figura 2: Distribuição de idade das estruturas...\n")

dados_fig2 <- df_mencoes %>%
  filter(encontrada, !is.na(idade_anos))

medianas_idade <- dados_fig2 %>%
  group_by(revista) %>%
  summarise(mediana = median(idade_anos), media = mean(idade_anos))

fig2 <- ggplot(dados_fig2, aes(x = revista, y = idade_anos, fill = revista)) +
  geom_violin(alpha = 0.35, color = NA, trim = FALSE) +
  geom_boxplot(width = 0.28, outlier.shape = NA, alpha = 0.85, color = "#222222", linewidth = 0.6) +
  geom_jitter(width = 0.12, alpha = 0.55, size = 1.9, color = "#222222") +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 3.2, fill = "yellow", color = "black") +
  annotate(
    "text", x = 1, y = medianas_idade$mediana[medianas_idade$revista == "IUCrJ"] + 2.2,
    label = sprintf("Mediana: %.1f anos\n(Média: %.1f)", 
                    medianas_idade$mediana[medianas_idade$revista == "IUCrJ"],
                    medianas_idade$media[medianas_idade$revista == "IUCrJ"]),
    size = 3.3, fontface = "italic", color = "#1a3b5c"
  ) +
  annotate(
    "text", x = 2, y = medianas_idade$mediana[medianas_idade$revista == "PLoS Comput Biol"] + 3.2,
    label = sprintf("Mediana: %.1f anos\n(Média: %.1f)", 
                    medianas_idade$mediana[medianas_idade$revista == "PLoS Comput Biol"],
                    medianas_idade$media[medianas_idade$revista == "PLoS Comput Biol"]),
    size = 3.3, fontface = "italic", color = "#8c3d00"
  ) +
  scale_fill_manual(values = cores_revista, guide = "none") +
  scale_y_continuous(breaks = seq(0, 45, by = 5)) +
  labs(
    title = "Idade das Estruturas PDB no Momento da Citação no Artigo",
    subtitle = "Intervalo em anos entre o depósito original no RCSB e a publicação do artigo (Wilcoxon W = 503, p = 2.6e-8)",
    x = "Revista",
    y = "Idade da Estrutura (Anos)",
    caption = "Losangos amarelos representam médias amostrais. Linha central do boxplot indica a mediana."
  ) +
  tema_trabalho()

ggsave(file.path(dir_figuras, "fig2_distribuicao_idade.png"), fig2, width = 8, height = 5.5, dpi = 300)
ggsave(file.path(dir_figuras, "fig2_distribuicao_idade.pdf"), fig2, width = 8, height = 5.5)

# ------------------------------------------------------------------------------
# Figura 3: Métodos Experimentais e Resolução Estrutural
# ------------------------------------------------------------------------------
cat("Gerando Figura 3: Métodos e resolução estrutural...\n")

dados_fig3a <- df_estruturas_unicas %>%
  filter(metodo_simplificado %in% c("Difração de Raio X", "Criomicroscopia Eletrônica")) %>%
  count(revista, metodo_simplificado) %>%
  group_by(revista) %>%
  mutate(
    pct = n / sum(n),
    rotulo = sprintf("%d (%.1f%%)", n, pct * 100)
  )

p3a <- ggplot(dados_fig3a, aes(x = revista, y = n, fill = metodo_simplificado)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65, color = "black", linewidth = 0.25) +
  geom_text(aes(label = rotulo), position = position_dodge(width = 0.75), vjust = -0.4, size = 3.2, fontface = "bold") +
  scale_fill_manual(values = c("Difração de Raio X" = "#4393c3", "Criomicroscopia Eletrônica" = "#9970ab"), name = "Método:") +
  scale_y_continuous(limits = c(0, max(dados_fig3a$n) * 1.15)) +
  labs(
    title = "(A) Proporção de Métodos Experimentais",
    x = "Revista",
    y = "Número de Estruturas Únicas"
  ) +
  tema_trabalho() +
  theme(legend.position = "bottom")

dados_fig3b <- df_estruturas_unicas %>%
  filter(metodo_simplificado %in% c("Difração de Raio X", "Criomicroscopia Eletrônica"), !is.na(resolucao))

p3b <- ggplot(dados_fig3b, aes(x = metodo_simplificado, y = resolucao, fill = revista)) +
  geom_boxplot(position = position_dodge(width = 0.75), width = 0.6, outlier.shape = 21, alpha = 0.85) +
  scale_fill_manual(values = cores_revista, name = "Revista:") +
  scale_y_continuous(breaks = seq(1, 5, by = 0.5)) +
  labs(
    title = "(B) Resolução Estrutural por Método e Revista",
    x = "Método",
    y = "Resolução (Å) — Menor é melhor"
  ) +
  tema_trabalho() +
  theme(legend.position = "bottom")

# Gráfico combinado ou facetado
fig3 <- ggplot(dados_fig3b, aes(x = revista, y = resolucao, fill = revista)) +
  geom_boxplot(width = 0.45, alpha = 0.85, outlier.size = 2) +
  geom_jitter(width = 0.15, alpha = 0.6, size = 1.8) +
  facet_wrap(~ metodo_simplificado, scales = "free_y") +
  scale_fill_manual(values = cores_revista, guide = "none") +
  labs(
    title = "Resolução das Estruturas Resolvidas por Raio X e Crio-ME",
    subtitle = "Estruturas citadas na IUCrJ exibem resolução cristalográfica superior (Raio X mediana 1.70 Å vs. 2.21 Å, p = 0.0025)",
    x = "Revista",
    y = "Resolução Estrutural (Å)",
    caption = "Valores menores de resolução indicam maior detalhamento atômico. Dados extraídos das páginas de entrada do RCSB PDB."
  ) +
  tema_trabalho()

ggsave(file.path(dir_figuras, "fig3_resolucao_metodos.png"), fig3, width = 8.5, height = 5.2, dpi = 300)
ggsave(file.path(dir_figuras, "fig3_resolucao_metodos.pdf"), fig3, width = 8.5, height = 5.2)

# ------------------------------------------------------------------------------
# Figura 4: Top Alvos Moleculares (UniProt) mais Frequentes
# ------------------------------------------------------------------------------
cat("Gerando Figura 4: Top proteínas e alvos moleculares...\n")

df_top_uniprot <- mencoes %>%
  left_join(artigos %>% select(pmcid, revista), by = "pmcid") %>%
  left_join(entidades, by = "codigo_pdb", relationship = "many-to-many") %>%
  filter(!is.na(uniprot), uniprot != "") %>%
  separate_rows(uniprot, sep = ";") %>%
  mutate(uniprot = trimws(uniprot)) %>%
  group_by(uniprot) %>%
  summarise(
    molecula = first(na.omit(molecula)),
    gene = first(na.omit(gene)),
    artigos_unicos = n_distinct(pmcid),
    estruturas_unicas = n_distinct(codigo_pdb),
    revistas = paste(unique(revista), collapse = " + "),
    .groups = "drop"
  ) %>%
  # Limpa nomes longos de moléculas para o gráfico
  mutate(
    rotulo_proteina = case_when(
      uniprot == "G3G192" ~ "Beta-lactamase CTX-M-15 (G3G192)",
      uniprot == "P11215" ~ "Integrina alfa-M / CD11b (P11215)",
      uniprot == "P00805" ~ "L-asparaginase 2 (P00805)",
      uniprot == "P0DTC2" ~ "Spike SARS-CoV-2 (P0DTC2)",
      uniprot == "I6NAW4" ~ "Copper nitrite reductase (I6NAW4)",
      uniprot == "P31153" ~ "MAT2A metionina adenosiltransferase (P31153)",
      uniprot == "P00698" ~ "Lisozima (P00698)",
      uniprot == "Q9NZL9" ~ "MAT2B subunidade regulatória (Q9NZL9)",
      uniprot == "P00811" ~ "AmpC Beta-lactamase (P00811)",
      uniprot == "B2UHR8" ~ "Nitrito redutase bacteriana (B2UHR8)",
      TRUE ~ paste0(substr(molecula, 1, 28), " (", uniprot, ")")
    )
  ) %>%
  arrange(desc(artigos_unicos), desc(estruturas_unicas)) %>%
  slice_head(n = 10)

fig4 <- ggplot(df_top_uniprot, aes(x = reorder(rotulo_proteina, estruturas_unicas), y = estruturas_unicas, fill = revistas)) +
  geom_col(width = 0.7, color = "black", linewidth = 0.25) +
  geom_text(aes(label = sprintf("%d est. (%d art.)", estruturas_unicas, artigos_unicos)),
            hjust = -0.1, size = 3.3, fontface = "bold") +
  coord_flip() +
  scale_y_continuous(limits = c(0, max(df_top_uniprot$estruturas_unicas) * 1.25), breaks = seq(0, 12, by = 2)) +
  scale_fill_manual(values = c("IUCrJ" = "#2b5c8f", "PLoS Comput Biol" = "#d95f02", "IUCrJ + PLoS Comput Biol" = "#7570b3"),
                    name = "Citada em:") +
  labs(
    title = "Proteínas e Alvos Moleculares mais Citados na Amostra",
    subtitle = "Contagem de estruturas distintas e artigos associados a cada identificador UniProt",
    x = "Proteína / Identificador UniProt",
    y = "Número de Estruturas Únicas Citadas",
    caption = "As beta-lactamases e integrinas representam os alvos recorrentes entre múltiplos artigos."
  ) +
  tema_trabalho() +
  theme(panel.grid.major.y = element_blank())

ggsave(file.path(dir_figuras, "fig4_top_uniprot_proteinas.png"), fig4, width = 8.5, height = 5.2, dpi = 300)
ggsave(file.path(dir_figuras, "fig4_top_uniprot_proteinas.pdf"), fig4, width = 8.5, height = 5.2)

# ------------------------------------------------------------------------------
# Figura 5: Densidade e Menções a PDB por Artigo Individual
# ------------------------------------------------------------------------------
cat("Gerando Figura 5: Densidade de menções por artigo...\n")

dados_fig5 <- df_mencoes %>%
  group_by(revista, pmcid, titulo_artigo) %>%
  summarise(
    n_estruturas_unicas = n_distinct(codigo_pdb),
    total_mencoes = sum(n_mencoes),
    .groups = "drop"
  ) %>%
  arrange(revista, desc(n_estruturas_unicas)) %>%
  mutate(artigo_idx = row_number())

fig5 <- ggplot(dados_fig5, aes(x = reorder(pmcid, total_mencoes), y = total_mencoes, fill = revista)) +
  geom_col(width = 0.68, color = "black", linewidth = 0.25) +
  geom_point(aes(y = n_estruturas_unicas), shape = 21, fill = "white", color = "black", size = 2.4, stroke = 1) +
  facet_wrap(~ revista, scales = "free_y") +
  coord_flip() +
  scale_fill_manual(values = cores_revista, guide = "none") +
  labs(
    title = "Volume de Menções e Diversidade Estrutural por Artigo",
    subtitle = "Barras coloridas: total de menções no texto | Pontos brancos: estruturas PDB distintas",
    x = "Artigo (PMCID)",
    y = "Contagem",
    caption = "Artigos experimentais da IUCrJ chegam a concentrar dezenas de menções em torno de conjuntos de homólogos."
  ) +
  tema_trabalho()

ggsave(file.path(dir_figuras, "fig5_mencoes_por_artigo.png"), fig5, width = 8.5, height = 5.5, dpi = 300)
ggsave(file.path(dir_figuras, "fig5_mencoes_por_artigo.pdf"), fig5, width = 8.5, height = 5.5)

# ------------------------------------------------------------------------------
# Figura 6: Linha do Tempo Histórica dos Anos de Depósito (1985-2026)
# ------------------------------------------------------------------------------
cat("Gerando Figura 6: Linha do tempo dos depósitos...\n")

dados_fig6 <- df_estruturas_unicas %>%
  filter(!is.na(ano_deposito))

fig6 <- ggplot(dados_fig6, aes(x = ano_deposito, fill = revista)) +
  geom_histogram(binwidth = 2, position = "identity", alpha = 0.65, color = "white") +
  scale_fill_manual(values = cores_revista, name = "Revista:") +
  scale_x_continuous(breaks = seq(1985, 2026, by = 5)) +
  labs(
    title = "Janela Histórica das Estruturas PDB Citadas em 2026",
    subtitle = "Enquanto a IUCrJ concentra-se na produção recente (2020-2026), a PLoS CB recorre a alvos históricos (1986-2015)",
    x = "Ano de Depósito Original no RCSB PDB",
    y = "Número de Estruturas Citadas",
    caption = "Amostra selecionada a partir dos 10 artigos mais recentes de cada periódico em 2026."
  ) +
  tema_trabalho()

ggsave(file.path(dir_figuras, "fig6_linha_tempo_deposito.png"), fig6, width = 8.5, height = 5.0, dpi = 300)
ggsave(file.path(dir_figuras, "fig6_linha_tempo_deposito.pdf"), fig6, width = 8.5, height = 5.0)

cat("\n==================================================================\n")
cat("Sucesso! Todas as 6 figuras de alta resolução foram salvas em 'figuras/'!\n")
cat("==================================================================\n")
