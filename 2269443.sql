

-- nome procedimento : DBO_GESTAO_LOGISTICA.STP_ATUALIZA_TB_BASE_WMS_TEMP
BEGIN TRY

DELETE DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS_TEMP
INSERT INTO DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS_TEMP
SELECT EST.ARECOD,
       EST.CD_ENDERECO,
       EST.CD_PRODUTO,
       DESCRICAO='',
       EST.QT_ESTOQUE,
       EST.FTPCOD,
       EST.DAT_ULT_MOV,
       MOV.LODNUM,
       DATA_DE_EXPIRACAO = ''
FROM ORACORP..INTERFACE_WMS.V_ESTOQUE EST
LEFT JOIN
  (SELECT LODNUM AS LPN,
          ADDDTE AS DAT_ULT_MOV
   FROM ORACORP..WMS_APP_HIST.INVSUB) MOV ON EST.LODNUM = MOV.LPN
WHERE WH_ID = 'CEVQ'
  AND SUBSTRING(ARECOD, 1, 4) IN ('2032',
                                  '2033',
                                  '2034',
                                  '2035',
                                  '2036',
                                  '2037',
                                  '2038',
                                  '2001',
                                  '2004',
                                  'PBF2',
                                  'PBP2',
                                  'PBR2',
                                  '2042',
                                  '2028') 
END TRY 
BEGIN CATCH
	SELECT 'NOK TEMP WMS' AS MESSAGE 
END CATCH 
GO 

-- nome procedimento : DBO_GESTAO_LOGISTICA.STP_ATUALIZA_TB_BASE_WMS
BEGIN TRY
DELETE
FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS
INSERT INTO DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS
SELECT CAST((SUBSTRING (W.AREA, 1, 4)) AS VARCHAR(200)) AS COD_AREA,
       CAST(W.LOCAL_DE_ARMAZENAGEM AS VARCHAR(200)) AS ENDERECO,
       CAST(W.ITEM AS CHAR(20)) AS ITEM,
       CAST(NOM.NOM_SKU AS VARCHAR(200)) AS DESCRICAO,
       W.QUANTIDADE_DE_UNIDADES AS QTD,
       V.CD_FAMILIA AS FAMILIA,
       CAST(W.CODIGO_DE_PEGADA AS VARCHAR(20)) AS LASTRO,
       CAST(W.AREA AS VARCHAR(100)) AS AREA,
       CAST(COALESCE(L.TIPO_LOCAL, 'VERIFICAR') AS VARCHAR(100)) AS TIPO_LOCAL,
       CONVERT(DATETIME, W.DATA_ULTIMA_MOVIMENTACAO, 103) AS DATA_ULTIMA_MOVIMENTACAO,
       GETDATE() AS DAT_GERACAO,
       CAST(W.LPN AS VARCHAR(15)) AS LPN,
       E.VOLUME_REAL AS VOL_END
FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS_TEMP W
INNER JOIN
  (SELECT CD_PRODUTO,
          CD_FAMILIA
   FROM DBO_GESTAO_LOGISTICA.DBO.VW_VOL_PROD_CD) V ON W.ITEM = V.CD_PRODUTO
LEFT JOIN
  (SELECT DISTINCT STOLOC,
                   CASE
                       WHEN SUBSTRING(ARECOD, 1, 4) IN ('2032',
                                                        '2033',
                                                        '2034',
                                                        '2035',
                                                        '2036',
                                                        '2037',
                                                        '2038') THEN 'ALMOX'
                       WHEN SUBSTRING(ARECOD, 1, 4) IN ('2001',
                                                        '2004',
                                                        '2007',
                                                        'PBF2',
                                                        'PBP2',
                                                        'PBR2') THEN 'ARMAZEM'
                       WHEN SUBSTRING(ARECOD, 1, 4) IN ('2042') THEN 'EDC'
                   END AS AREA,
                   CASE
                       WHEN ARECOD IN ('2004AB1',
                                       '2004CD1',
                                       '2004EF1',
                                       '2004GH1',
                                       '2004AB3',
                                       '2004CD3',
                                       '2004EF3',
                                       '2004GH3',
                                       '2004IJ3',
                                       'PBF2004',
                                       '2033',
                                       '2035',
                                       '2037',
                                       '2038',
                                       'PBR2004',
                                       '2001X2',
                                       '2004',
                                       '2004PB',
                                       '2042',
                                       '2042FLS',
                                       '2042FLP',
                                       '2004MLT',
                                       '2004PS') THEN 'PICKING'
                       ELSE 'ALTO'
                   END AS TIPO_LOCAL
   FROM ORACORP..WMS_APP_HIST.LOCMST
   WHERE WH_ID = 'CEVQ'
     AND SUBSTRING(ARECOD, 1, 4) IN ('2007',
                                     '2004',
                                     '2001',
                                     '2032',
                                     '2033',
                                     '2034',
                                     '2035',
                                     '2036',
                                     '2037',
                                     '2038',
                                     'PBF2',
                                     'PBP2',
                                     'PBR2',
                                     '2042')
     AND USEFLG = 1) L ON W.LOCAL_DE_ARMAZENAGEM = L.STOLOC
LEFT JOIN
  (SELECT LOCAL_DE_ARMAZENAGEM,
          FAMILIA,
          ESTRUTURA,
          VOLUME_REAL
   FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_VOLUME_ENDERECO) E ON W.LOCAL_DE_ARMAZENAGEM = E.LOCAL_DE_ARMAZENAGEM
LEFT JOIN
  (SELECT CAST(COD_ITPROD_SAP AS INT) AS SKU,
          NOM_SKU
   FROM [DBO_BI].[DBO].[TB_HIERARQUIA_SKU_COMPLETA]) NOM ON W.ITEM = NOM.SKU END TRY BEGIN CATCH
SELECT 'NOK BASE WMS' AS MESSAGE END CATCH 
GO 

-- nome procedimento : DBO_GESTAO_LOGISTICA.STP_ATUALIZA_TB_HISTORICO_OCUPACAO
BEGIN TRY
INSERT INTO DBO_GESTAO_LOGISTICA..TB_HISTORICO_OCUPACAO
SELECT GETDATE() AS DAT_GERACAO,
       GETDATE() AS DAT_ATUALIZACAO,
       SUM(F.VOL_OCUPADO) AS VOLUME_OCUPADO,
       SUM(F.VOL_ETQ) AS VOL_ETQ,
       MAX(F.CAPACIDADE_ARMAZENAGEM_REAL)AS CAPACIDADE_ARMAZENAGEM_REAL,
       SUM(F.VOL_OCUPADO)/MAX(F.CAPACIDADE_ARMAZENAGEM_REAL) AS TX_OCUPACAO_GERAL,
       SUM(F.VOL_OCUPADO)/SUM(F.VOL_ETQ) AS TX_UTILIZACAO,
       SUM(F.ENDERECOS) AS ENDERECOS,
       F.MODULO AS MODULO,
       F.LOCAL AS LOCAL,
       F.NIVEL
FROM
  (SELECT J.DATA_REF,
          SUM(J.VOL_OCUP) AS VOL_OCUPADO,
          CASE
              WHEN J.STATUS = 'OCUPADO' THEN SUM(J.VOLUME_REAL)
              ELSE 0
          END AS VOL_ETQ,
          D.CAP_ARM_CD AS CAPACIDADE_ARMAZENAGEM_REAL,
          CASE
              WHEN J.STATUS = 'OCUPADO' THEN COUNT(DISTINCT(J.ENDERECO))
              ELSE 0
          END AS ENDERECOS,
          (SUM(J.VOL_OCUP)/SUM(D.CAP_ARM_CD)) AS TX_OCUPACAO_GERAL,
          J.MODULO,
          J.LOCAL,
          J.NIVEL
   FROM
     (SELECT W.DATA_REF,
             E.LOCAL_DE_ARMAZENAGEM AS ENDERECO,
             E.AREA,
             W.ITEM,
             W.QTD,
             W.VOL AS VOL_OCUP,
             CASE
                 WHEN W.ITEM <> '' THEN 'OCUPADO'
                 ELSE 'VAZIO'
             END AS STATUS,
             E.VOLUME_REAL,
             CASE
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'PAR-' THEN 'ALMOX'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) IN ('PAR2',
                                                                  'P2ST') THEN 'ALMOX'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'REF-' THEN 'ALMOX'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = 'CF-' THEN 'ALMOX'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '1-' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2UP' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2C-' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2G-' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2FR' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3F' THEN 'EDC'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3E' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '2-' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3-' THEN 'ARMAZEM'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'DRIV' THEN 'ARMAZEM'
             END AS MODULO,
             CASE
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'PAR-' THEN 'PAR'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) IN ('PAR2',
                                                                  'P2ST') THEN 'PAR2'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'REF-' THEN 'REF'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = 'CF-' THEN 'COFRE'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '1-' THEN 'MODULO_1'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2UP' THEN 'PICK_TO_BELT'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2C-' THEN 'CROSSDOCKING'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2G-' THEN 'GAIOLA'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) = '2FR' THEN 'FRACIONADO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3F' THEN 'EDC'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3E' THEN 'ESTANTE_3E'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '2-' THEN 'MODULO_2'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) = '3-' THEN 'MODULO_3'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) = 'DRIV' THEN 'DRIVE'
             END AS LOCAL,
             CASE
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) IN ('PAR-',
                                                                  'PAR2',
                                                                  'REF-',
                                                                  'DRIV')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) IN ('1',
                                                               '2',
                                                               '3',
                                                               '4',
                                                               '5',
                                                               '6',
                                                               '7',
                                                               '8',
                                                               '9') THEN 'ALTO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) IN ('PAR-',
                                                                  'PAR2',
                                                                  'REF-')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) = '0' THEN 'BAIXO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 4) IN ('DRIV')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) = '0' THEN 'ALTO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 3) IN ('CF-',
                                                                  'P2S')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) IN ('0',
                                                               '1',
                                                               '2',
                                                               '3',
                                                               '4',
                                                               '5',
                                                               '6',
                                                               '7') THEN 'BAIXO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) IN ('1-',
                                                                  '2-',
                                                                  '3-')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) IN ('1',
                                                               '2',
                                                               '3',
                                                               '4',
                                                               '5',
                                                               '6',
                                                               '7') THEN 'ALTO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) IN ('1-',
                                                                  '2-',
                                                                  '3-')
                      AND RIGHT(E.LOCAL_DE_ARMAZENAGEM, 1) IN ('0') THEN 'BAIXO'
                 WHEN SUBSTRING(E.LOCAL_DE_ARMAZENAGEM, 1, 2) IN ('2U',
                                                                  '2C',
                                                                  '2G',
                                                                  '2F',
                                                                  '3F',
                                                                  '3E') THEN 'BAIXO'
             END AS NIVEL
      FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_VOLUME_ENDERECO E
      LEFT JOIN
        (SELECT B.ENDERECO,
                B.ITEM,
                B.QTD,
                CONVERT(VARCHAR, B.DAT_GERACAO, 105) AS DATA_REF,
                ((B.QTD * (V.VL_ALTURA_CS*V.VL_LARGURA_CS*V.VL_PROFUNDIDADE_CS)/QTD_POR_CX_MAE)/1000000) AS VOL
         FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS B
         LEFT JOIN DBO_GESTAO_LOGISTICA..VW_VOL_PROD_CD V ON B.ITEM = V.CD_PRODUTO) W ON E.LOCAL_DE_ARMAZENAGEM = ENDERECO) J
   LEFT JOIN DBO_GESTAO_LOGISTICA..TB_CAPACIDADE_ARMAZENAGEM_CD D ON J.DATA_REF = CONVERT(VARCHAR, D.DATA, 105)
   WHERE DATA_REF IS NOT NULL
     AND J.LOCAL NOT IN ('EDC',
                         'FRACIONADO',
                         'ESTANTE_3E',
                         'COFRE')
   GROUP BY J.DATA_REF,
            D.CAP_ARM_CD,
            J.MODULO,
            J.LOCAL,
            J.NIVEL,
            J.STATUS) F
GROUP BY F.DATA_REF,
         F.MODULO,
         F.LOCAL,
         F.NIVEL END TRY BEGIN CATCH
SELECT 'NOK HISTORICO DE OCUPAÇÃO' AS MESSAGE END CATCH 
GO 


-- nome procedimento : DBO_GESTAO_LOGISTICA.STP_ATUALIZA_TB_ERRO_FAMILIA
BEGIN TRY
INSERT INTO DBO_GESTAO_LOGISTICA.DBO.TB_ERRO_FAMILIA
SELECT GETDATE() AS DAT_REF,
       MODULO,
       LOCAL,
       COUNT(ENDERECO) AS END_ERRO_FAMILIA,
       COUNT(DISTINCT ITEM) AS CONT_SKU
FROM
  (SELECT DISTINCT *
   FROM
     (SELECT W.ENDERECO,
             W.ITEM,
             W.DESCRICAO,
             W.QTD,
             W.NIVEL4,
             W.FAMILIA,
             W.FAMILIA2,
             W.MODULO,
             W.LOCAL,
             W.NIVEL,
             CASE
                 WHEN W.FAMILIA IN ('2001',
                                    '2004')
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('MODULO_2',
                                      'MODULO_3',
                                      'ESTANTE_3E',
                                      'CROSSDOCKING',
                                      'FRACIONADO')
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA IN ('2002',
                                    '2001',
                                    '2004',
                                    '2007')
                      AND W.MODULO = 'EDC'
                      AND W.LOCAL = 'EDC'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA = '2002'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR2'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA = '2003'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='REF'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA = '2004'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='MODULO_1'
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA IN ('2002',
                                    '2003')
                      AND MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA IN ('2002',
                                    '2006')
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='COFRE'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA = '2006'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR2'
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA = '2001'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='MODULO_1'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA = '2004'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='PICK_TO_BELT'
                      AND W.NIVEL = 'BAIXO' THEN 0
                 WHEN W.FAMILIA = '2007'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('PICK_TO_BELT',
                                      'GAIOLA',
                                      'ESTANTE_3E')
                      AND W.NIVEL = 'BAIXO' THEN 0
                 WHEN W.FAMILIA = '2007'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('MODULO_1',
                                      'MODULO_2',
                                      'MODULO_3')
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA IN ('2001',
                                    '2004',
                                    '2007')
                      AND W.MODULO IN ('ARMAZEM',
                                       'EDC')
                      AND W.LOCAL IN ('MODULO_2',
                                      'EDC')
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 ELSE 1
             END AS ERRO_FAMILIA,
             CASE
                 WHEN W.FAMILIA2 IN ('2001',
                                     '2004')
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('MODULO_2',
                                      'MODULO_3',
                                      'ESTANTE_3E',
                                      'CROSSDOCKING',
                                      'FRACIONADO')
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 IN ('2002',
                                     '2001',
                                     '2004',
                                     '2007')
                      AND W.MODULO = 'EDC'
                      AND W.LOCAL = 'EDC'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 = '2002'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR2'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 = '2003'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='REF'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 = '2004'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='MODULO_1'
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA2 IN ('2002',
                                     '2003')
                      AND MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 IN ('2002',
                                     '2006')
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='COFRE'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 = '2006'
                      AND W.MODULO = 'ALMOX'
                      AND W.LOCAL ='PAR2'
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA2 = '2001'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='MODULO_1'
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 WHEN W.FAMILIA2 IN ('2001',
                                     '2004')
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL ='PICK_TO_BELT'
                      AND W.NIVEL = 'BAIXO' THEN 0
                 WHEN W.FAMILIA2 = '2007'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('PICK_TO_BELT',
                                      'GAIOLA',
                                      'ESTANTE_3E')
                      AND W.NIVEL = 'BAIXO' THEN 0
                 WHEN W.FAMILIA2 = '2007'
                      AND W.MODULO = 'ARMAZEM'
                      AND W.LOCAL IN ('MODULO_1',
                                      'MODULO_2',
                                      'MODULO_3')
                      AND W.NIVEL = 'ALTO' THEN 0
                 WHEN W.FAMILIA2 IN ('2001',
                                     '2004',
                                     '2007')
                      AND W.MODULO IN ('ARMAZEM',
                                       'EDC')
                      AND W.LOCAL IN ('MODULO_2',
                                      'EDC')
                      AND W.NIVEL IN ('ALTO',
                                      'BAIXO') THEN 0
                 ELSE 1
             END AS ERRO_FAMILIA2
      FROM
        (SELECT ENDERECO,
                ITEM,
                B.DESCRICAO,
                QTD,
                B.NIVEL4,
                B.FAMILIA,
                B.FAMILIA2,
                CASE
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'PAR-' THEN 'ALMOX'
                    WHEN SUBSTRING(ENDERECO, 1, 4) IN ('PAR2',
                                                       'P2ST') THEN 'ALMOX'
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'REF-' THEN 'ALMOX'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = 'CF-' THEN 'ALMOX'
                    WHEN SUBSTRING(ENDERECO, 1, 3) IN ('1-A') THEN 'ALMOX'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '1-' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 3) IN ('2P-',
                                                       '2UP') THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2C-' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2G-' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2FR' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3F' THEN 'EDC'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3E' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '2-' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3-' THEN 'ARMAZEM'
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'DRIV' THEN 'ARMAZEM'
                END AS MODULO,
                CASE
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'PAR-' THEN 'PAR'
                    WHEN SUBSTRING(ENDERECO, 1, 4) IN ('PAR2',
                                                       'P2ST') THEN 'PAR2'
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'REF-' THEN 'REF'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = 'CF-' THEN 'COFRE'
                    WHEN SUBSTRING(ENDERECO, 1, 3) IN ('1-A') THEN 'PAR2'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '1-' THEN 'MODULO_1'
                    WHEN SUBSTRING(ENDERECO, 1, 3) IN ('2P-',
                                                       '2UP') THEN 'PICK_TO_BELT'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2C-' THEN 'CROSSDOCKING'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2G-' THEN 'GAIOLA'
                    WHEN SUBSTRING(ENDERECO, 1, 3) = '2FR' THEN 'FRACIONADO'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3F' THEN 'EDC'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3E' THEN 'ESTANTE_3E'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '2-' THEN 'MODULO_2'
                    WHEN SUBSTRING(ENDERECO, 1, 2) = '3-' THEN 'MODULO_3'
                    WHEN SUBSTRING(ENDERECO, 1, 4) = 'DRIV' THEN 'DRIVE'
                END AS LOCAL,
                CASE
                    WHEN SUBSTRING(ENDERECO, 1, 4) IN ('PAR-',
                                                       'PAR2',
                                                       'REF-',
                                                       'DRIV')
                         AND RIGHT(ENDERECO, 1) IN ('1',
                                                    '2',
                                                    '3',
                                                    '4',
                                                    '5',
                                                    '6',
                                                    '7',
                                                    '8',
                                                    '9') THEN 'ALTO'
                    WHEN SUBSTRING(ENDERECO, 1, 4) IN ('PAR-',
                                                       'PAR2',
                                                       'REF-')
                         AND RIGHT(ENDERECO, 1) = '0' THEN 'BAIXO'
                    WHEN SUBSTRING(ENDERECO, 1, 4) IN ('DRIV')
                         AND RIGHT(ENDERECO, 1) = '0' THEN 'ALTO'
                    WHEN SUBSTRING(ENDERECO, 1, 3) IN ('CF-',
                                                       'P2S')
                         AND RIGHT(ENDERECO, 1) IN ('0',
                                                    '1',
                                                    '2',
                                                    '3',
                                                    '4',
                                                    '5',
                                                    '6',
                                                    '7') THEN 'BAIXO'
                    WHEN SUBSTRING(ENDERECO, 1, 2) IN ('1-',
                                                       '2-',
                                                       '3-')
                         AND RIGHT(ENDERECO, 1) IN ('1',
                                                    '2',
                                                    '3',
                                                    '4',
                                                    '5',
                                                    '6',
                                                    '7') THEN 'ALTO'
                    WHEN SUBSTRING(ENDERECO, 1, 2) IN ('1-',
                                                       '2-',
                                                       '3-')
                         AND RIGHT(ENDERECO, 1) IN ('0') THEN 'BAIXO'
                    WHEN SUBSTRING(ENDERECO, 1, 2) IN ('2U',
                                                       '2P',
                                                       '2C',
                                                       '2G',
                                                       '2F',
                                                       '3F',
                                                       '3E') THEN 'BAIXO'
                END AS NIVEL
         FROM
           (SELECT CD_ENDERECO AS ENDERECO,
                   CD_PRODUTO AS ITEM,
                   QT_ESTOQUE AS QTD
            FROM ORACORP..INTERFACE_WMS.V_ESTOQUE EST
            WHERE WH_ID = 'CEVQ'
              AND SUBSTRING(ARECOD, 1, 4) IN ('2032',
                                              '2033',
                                              '2034',
                                              '2035',
                                              '2036',
                                              '2037',
                                              '2038',
                                              '2001',
                                              '2004',
                                              'PBF2',
                                              'PBP2',
                                              'PBR2',
                                              '2042',
                                              '2028') ) A
         LEFT JOIN
           (SELECT SKU,
                   DESCRICAO,
                   CASE
                       WHEN FAMILIA = '2001'
                            AND END_NECESSARIOS >= '4' THEN '2004'
                       ELSE FAMILIA
                   END AS FAMILIA2,
                   CD_FAMILIA AS FAMILIA,
                   A.NIVEL4
            FROM [DBO_GESTAO_LOGISTICA].[DBO].[TB_HIERARQUIA_FAMILIA] A
            LEFT JOIN
              (SELECT CAST(COD_ITPROD_SAP AS INT) AS SKU,
                      CAST(NOM_SKU AS VARCHAR(200)) AS DESCRICAO,
                      NOM_NIVEL4
               FROM [DBO_BI].[DBO].[TB_HIERARQUIA_SKU_COMPLETA]) B ON A.NIVEL4 = B.NOM_NIVEL4
            LEFT JOIN
              (SELECT COD_PRODUTO_DE_ORIGEM,
                      VOL_TOTAL,
                      CLASSE,
                      END_NECESSARIOS
               FROM DBO_GESTAO_LOGISTICA..TB_HISTORICO_FRAGMENTACAO
               WHERE CONVERT(VARCHAR(10), DAT_GERACAO, 101) =
                   (SELECT CONVERT(VARCHAR(10), MAX(DAT_GERACAO), 101)
                    FROM DBO_GESTAO_LOGISTICA..TB_HISTORICO_FRAGMENTACAO) ) C ON B.SKU = C.COD_PRODUTO_DE_ORIGEM
            INNER JOIN
              (SELECT CD_PRODUTO,
                      CD_FAMILIA
               FROM DBO_GESTAO_LOGISTICA.DBO.VW_VOL_PROD_CD) V ON B.SKU = V.CD_PRODUTO) B ON B.SKU = A.ITEM
         WHERE SUBSTRING(ENDERECO, 1, 2) NOT IN ('PS',
                                                 'DF') ) W) F) X
WHERE 1=1
  AND ERRO_FAMILIA = '1'
  OR ERRO_FAMILIA2 = '1'
GROUP BY MODULO,
         LOCAL END TRY BEGIN CATCH
SELECT 'NOK ERRO DE FAMILIA' AS MESSAGE END CATCH 
GO 

-- nome procedimento : DBO_GESTAO_LOGISTICA.STP_ATUALIZA_TB_HISTORICO_FRAGMENTACAO
BEGIN TRY
INSERT INTO DBO_GESTAO_LOGISTICA..TB_HISTORICO_FRAGMENTACAO
SELECT CD_PRODUTO_DE_ORIGEM,
       COD_ITPROD_SAP,
       PRODUTO,
       LASTRO,
       QTD_LASTRO,
       FAMILIA,
       CATEGORIA,
       NEGOCIO,
       NIVEL_4,
       CLASSE,
       VOL_UN,
       ETQ_RP_FISICO,
       VOL_TOTAL,
       QTD_END_RP_FISICO,
       END_NECESS,
       CASE
           WHEN FAMILIA IN ('2001',
                            '2004') THEN (END_NECESS*1.8)
           WHEN FAMILIA = '2007' THEN (END_NECESS*2.4)
           ELSE (END_NECESS*1.2)
       END AS VOL_NECESSARIO,
       (QTD_END_RP_FISICO-END_NECESS) AS EXCEDENTE,
       (VOL_OCUPADO - VOL_TOTAL) AS VOL_EXCEDENTE,
       DAT_GERACAO,
       OPERADOR_MED,
       COMPR_UN,
       LARG_UN,
       ALTU_UN,
       COMPR_CX,
       LARG_CX,
       ALTU_CX,
       DATA_ATT_MED,
       VOL_OCUPADO
FROM
  (SELECT W.ITEM AS CD_PRODUTO_DE_ORIGEM,
          H.COD_ITPROD_SAP,
          H.NOM_SKU AS PRODUTO,
          V.LASTRO,
          MAX(V.QTD_LASTRO) AS QTD_LASTRO,
          W.FAMILIA,
          H.NOM_CATEGORIA_COMPLETO AS CATEGORIA,
          H.NOM_NEGOCIO AS NEGOCIO,
          H.NOM_NEGOCIO AS NIVEL_4,
          H.COD_CLASSE_ATUAL AS CLASSE,
          VOL_UN = CAST(((V.VL_PROFUNDIDADE_CS*V.VL_LARGURA_CS*V.VL_ALTURA_CS)/V.QTD_POR_CX_MAE)/1000000 AS FLOAT),
          SUM(W.QTD) AS ETQ_RP_FISICO,
          CAST((((V.VL_PROFUNDIDADE_CS*V.VL_LARGURA_CS*V.VL_ALTURA_CS)/V.QTD_POR_CX_MAE)/1000000)*SUM(W.QTD) AS FLOAT) AS VOL_TOTAL,
          COUNT(DISTINCT(W.ENDERECO)) AS QTD_END_RP_FISICO,
          CASE
              WHEN CAST(ROUND(SUM(W.QTD) / MAX(V.QTD_LASTRO), 0) AS INT) = '0' THEN '1'
              ELSE CAST(ROUND(SUM(W.QTD) / MAX(V.QTD_LASTRO), 0) AS INT)
          END AS END_NECESS,
          SUM(W.VOL_END) AS VOL_OCUPADO,
          GETDATE() AS DAT_GERACAO,
          CAST(V.LAST_UPD_USER_ID AS VARCHAR(30)) AS OPERADOR_MED,
          V.VL_PROFUNDIDADE_EA AS COMPR_UN,
          V.VL_LARGURA_EA AS LARG_UN,
          V.VL_ALTURA_EA AS ALTU_UN,
          V.VL_PROFUNDIDADE_CS AS COMPR_CX,
          V.VL_LARGURA_CS AS LARG_CX,
          V.VL_ALTURA_CS AS ALTU_CX,
          V.LAST_UPD_DT AS DATA_ATT_MED
   FROM
     (SELECT ENDERECO,
             ITEM,
             QTD,
             FAMILIA,
             VOL_END
      FROM DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS) W
   LEFT JOIN DBO_GESTAO_LOGISTICA..VW_VOL_PROD_CD V ON V.CD_PRODUTO = W.ITEM
   LEFT JOIN DBO_BI..TB_HIERARQUIA_SKU_COMPLETA H ON CAST(H.COD_ITPROD_SAP AS BIGINT)= W.ITEM
   GROUP BY W.ITEM,
            H.NOM_SKU,
            H.COD_ITPROD_SAP,
            W.FAMILIA,
            V.LASTRO,
            V.QTD_LASTRO,
            H.NOM_CATEGORIA_COMPLETO,
            H.NOM_NEGOCIO,
            H.COD_CLASSE_ATUAL,
            V.VL_PROFUNDIDADE_CS,
            V.VL_LARGURA_CS,
            V.VL_ALTURA_CS,
            V.QTD_POR_CX_MAE,
            V.LAST_UPD_USER_ID,
            V.VL_PROFUNDIDADE_EA,
            V.VL_LARGURA_EA,
            V.VL_ALTURA_EA,
            V.VL_PROFUNDIDADE_CS,
            V.VL_LARGURA_CS,
            V.VL_ALTURA_CS,
            V.LAST_UPD_DT) F END TRY BEGIN CATCH
SELECT 'NOK HISTORICO DE FRAGMENTAÇÃO' AS MESSAGE END CATCH