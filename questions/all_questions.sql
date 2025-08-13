/* ==============================================================
   Q01 – TOP 5 cursos com mais inscrições **ativas**
   Retorne: id_curso · nome · total_inscritos
=================================================================*/
-- SUA QUERY AQUI

SELECT 
    c.id_curso,
    c.nome,
    COUNT(i.id_inscricao) AS total_inscritos
FROM f_inscricoes i
JOIN d_cursos c ON i.id_curso = c.id_curso
WHERE i.status = 'ativo'
GROUP BY c.id_curso, c.nome
ORDER BY total_inscritos DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;


/* ==============================================================
   Q02 – Taxa de conclusão por curso
   Para cada curso, calcule:
     • total_inscritos
     • total_concluidos   (status = 'concluída')
     • taxa_conclusao (%) = concluídos / inscritos * 100
   Ordene descendentemente pela taxa de conclusão.
=================================================================*/
-- SUA QUERY AQUI

SELECT
    c.id_curso,
    c.nome,
    COUNT(i.id_inscricao) AS total_inscritos,
    SUM(CASE WHEN i.status = 'concluido' THEN 1 ELSE 0 END) AS total_concluidos,
    CASE 
        WHEN COUNT(i.id_inscricao) = 0 THEN 0
        ELSE CAST(SUM(CASE WHEN i.status = 'concluido' THEN 1 ELSE 0 END) AS FLOAT) 
             / COUNT(i.id_inscricao) * 100
    END AS taxa_conclusao
FROM f_inscricoes i
JOIN d_cursos c ON i.id_curso = c.id_curso
GROUP BY c.id_curso, c.nome
ORDER BY taxa_conclusao DESC;


/* ==============================================================
   Q03 – Tempo médio (dias) para concluir cada **nível** de curso
   Definições:
     • Início = data_insc   (tabela inscricoes)
     • Fim    = maior data em progresso onde porcentagem = 100
   Calcule a média de dias entre início e fim,
   agrupando por cursos.nivel (ex.: Básico, Avançado).
=================================================================*/
-- SUA QUERY AQUI

WITH conclusao_aluno_curso AS (
    SELECT
        i.id_aluno,
        i.id_curso,
        i.data_inscricao,
        MAX(CASE WHEN p.percentual = 100 THEN p.data_ultima_atividade ELSE NULL END) AS data_conclusao
    FROM f_inscricoes i
    LEFT JOIN f_progresso p
        ON i.id_aluno = p.id_aluno
        AND p.id_modulo IN (
            SELECT id_modulo FROM d_modulos WHERE id_curso = i.id_curso
        )
    GROUP BY i.id_aluno, i.id_curso, i.data_inscricao
)
SELECT
    c.nivel,
    AVG(DATEDIFF(DAY, conc.data_inscricao, conc.data_conclusao)) AS tempo_medio_dias
FROM conclusao_aluno_curso conc
JOIN d_cursos c ON conc.id_curso = c.id_curso
WHERE conc.data_conclusao IS NOT NULL
GROUP BY c.nivel
ORDER BY tempo_medio_dias;

/* ==============================================================
   Q04 – TOP 10 módulos com maior **taxa de abandono**
   - Considere abandono quando porcentagem < 20 %
   - Inclua apenas módulos com pelo menos 20 alunos
   Retorne: id_modulo · titulo · abandono_pct
   Ordene do maior para o menor.
=================================================================*/
-- SUA QUERY AQUI

SELECT
    p.id_modulo,
    m.titulo,
    CAST(100.0 * SUM(CASE WHEN p.percentual < 20 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS abandono_pct
FROM f_progresso p
JOIN d_modulos m ON p.id_modulo = m.id_modulo
GROUP BY p.id_modulo, m.titulo
HAVING COUNT(*) >= 20
ORDER BY abandono_pct DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

/* ==============================================================
   Q05 – Crescimento de inscrições (janela móvel de 3 meses)
   1. Para cada mês calendário (YYYY-MM), conte inscrições.
   2. Calcule a soma móvel de 3 meses (mês atual + 2 anteriores) → rolling_3m.
   3. Calcule a variação % em relação à janela anterior.
   Retorne: ano_mes · inscricoes_mes · rolling_3m · variacao_pct
=================================================================*/
-- SUA QUERY AQUI


WITH inscricoes_por_mes AS (
    SELECT
        FORMAT(data_inscricao, 'yyyy-MM') AS ano_mes,
        COUNT(*) AS inscricoes_mes
    FROM f_inscricoes
    GROUP BY FORMAT(data_inscricao, 'yyyy-MM')
),
janela_movel_3m AS (
    SELECT
        ano_mes,
        inscricoes_mes,
        SUM(inscricoes_mes) OVER (
            ORDER BY ano_mes
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS janela_movel_3m
    FROM inscricoes_por_mes
),
variacao AS (
    SELECT
        ano_mes,
        inscricoes_mes,
        janela_movel_3m,
        LAG(janela_movel_3m) OVER (ORDER BY ano_mes) AS janela_movel_3m_anterior
    FROM janela_movel_3m
)
SELECT
    ano_mes,
    inscricoes_mes,
    janela_movel_3m,
    CASE 
        WHEN janela_movel_3m_anterior IS NULL THEN NULL
        WHEN janela_movel_3m_anterior = 0 THEN NULL
        ELSE ROUND(((janela_movel_3m - janela_movel_3m_anterior) * 100.0) / janela_movel_3m_anterior, 2)
    END AS variacao_pct
FROM variacao
ORDER BY ano_mes;
