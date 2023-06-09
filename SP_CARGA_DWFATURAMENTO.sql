/****** Object:  StoredProcedure [dbo].[SP_CARGA_DWFATURAMENTO]    Script Date: 02/05/2023 14:39:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CRETE PROCEDURE [dbo].[SP_CARGA_DWFATURAMENTO] @DiasIncremento INT
 
AS
    BEGIN

		DROP TABLE IF EXISTS #tmpFaturamento

		--- select Faturamento
		SELECT
			f.Doc_Fatura
			, cast(f.Doc_Fatura as bigint) AS [idFaturamento]
			, f.Data_Faturamento AS [datFaturamentoTstmp]
			, cast(NULL AS DATETIME) AS [datFaturamento]
			, cast(f.Cat_Documento as varchar(10)) AS [strCatDocumento]
			, cast(f.Tipo_Documento as varchar(10)) AS [strTipoDocumento]
			, cast(NULL AS bigint) AS [idCliente]
			, cast(NULL AS bigint) AS [idLoja]
			, cast(f.Grupo_Clientes as varchar(5)) as [strGrupoClientes]
			, cast(f.Grupo_Clientes as INT) AS [Segmento]
			, cast(f.Pais_Destino as varchar(5)) as [strPaisDestino]
			, cast(f.Estado as varchar(5)) as [strUfEstado]
			, cast(f.Org_Vendas as varchar(10)) as [strOrgVendas]
			, cast(f.Canal_Distribuicao as varchar(5)) as [strCanalDistribuicao]
			, cast(f.Canal_Distribuicao AS int) AS [Canal]
			, cast(f.Setor_Atividade as varchar(5)) as [strSetorAtividade]
			, CASE WHEN f.Tipo_Operacao IN ('O', 'N') THEN -1 ELSE 1 END * cast(f.Valor_Bruto as numeric(12,2)) as [numValorBrutoToT]
			, CASE WHEN f.Tipo_Operacao IN ('O', 'N') THEN -1 ELSE 1 END * cast(f.Valor_Liquido as numeric(12,2)) as [numValorLiquidoToT]
			, cast(f.Imposto as numeric(12,2)) as [numValorImpostoToT]
			, 0 as [numQuantidade]
			, 0 as [numQuantidadeFaturada]
			, CAST(NULL AS DATETIME) AS [datAtualizacao] -- DATA DE CRIACAO DO REGISTRO NA ORIGEM
			, GETDATE() AS [datDataCriacao] -- DATA DE IMPORTAÇÃO
			, NULL AS [numComissao]
			, 1 AS [idFonteDados] --SAP
			, cast(null as VARCHAR(1)) as [Local]
			, cast(null as VARCHAR(30)) as [strCanalCustomizado]
			, cast(null AS BIGINT) AS [idParceiro]
			, cast(null AS BIGINT) AS [idVendedor]
			, cast(Tipo_Operacao as VARCHAR(2)) AS [TipoOperacao]
			, CAST(NULL AS VARCHAR(25)) AS [strModalidade]
		INTO #tmpFaturamento
		FROM
			[dbo].[stgAPIFaturamentos] f 
		GROUP BY
			f.Doc_Fatura
			, cast(f.Doc_Fatura as bigint)
			, f.Data_Faturamento
			, cast(f.Cat_Documento as varchar(10)) 
			, cast(f.Tipo_Documento as varchar(10))
			, cast(f.Empresa as bigint)
			, cast(f.Grupo_Clientes as varchar(5))
			, cast(f.Grupo_Clientes as INT)
			, cast(f.Pais_Destino as varchar(5))
			, cast(f.Estado as varchar(5))
			, cast(f.Org_Vendas as varchar(10))
			, cast(f.Canal_Distribuicao as varchar(5))
			, cast(f.Canal_Distribuicao AS int)
			, cast(f.Setor_Atividade as varchar(5))
			, CASE WHEN f.Tipo_Operacao IN ('O', 'N') THEN -1 ELSE 1 END * cast(f.Valor_Bruto as numeric(12,2))
			, CASE WHEN f.Tipo_Operacao IN ('O', 'N') THEN -1 ELSE 1 END * cast(f.Valor_Liquido as numeric(12,2))
			, cast(f.Imposto as numeric(12,2))
			, cast(Tipo_Operacao as VARCHAR(255))

		-- identificando cliente
		UPDATE
			t
		SET
			[idCliente] = f.Cliente
		FROM
			#tmpFaturamento t
			JOIN [dbo].[stgFuncFaturamentos] f
				ON t.Doc_Fatura = f.Doc_Faturamento
				AND ISNULL(f.Cliente,'') NOT IN ('', '0')
				AND f.Func_Parceiro = 'BP'
		WHERE
			t.[idCliente] IS NULL

		-- identificando transportadora
		UPDATE
			t
		SET
			[idParceiro] = f.Fornecedor
		FROM
			#tmpFaturamento t
			JOIN [dbo].[stgFuncFaturamentos] f
				ON t.Doc_Fatura = f.Doc_Faturamento
				AND f.Func_Parceiro = 'CR' 
				AND ISNULL(f.Fornecedor, '') NOT IN ('', '0')
		WHERE
			t.[idParceiro] IS NULL			

		-- correcao notas erradas (ajuste manual)
		UPDATE
			#tmpFaturamento
		SET
			Canal = 30
		WHERE
			idFaturamento IN (1749368, 1749540, 1749720, 1749752, 1749756, 1749767, 1749988, 1750005, 1750116, 1750140, 1750144, 1750345, 1750352, 1750456, 1750482, 1750497, 1750506, 1750549, 1750590, 1750772, 1750839, 1750991, 1751119, 1751137, 1751274)

		-- converte data de faturamento
		UPDATE #tmpFaturamento SET [datFaturamento] = dbo.fnConvertData([datFaturamentoTstmp]), [datAtualizacao] = dbo.fnConvertData([datFaturamentoTstmp])

		-- select Item
		DROP TABLE IF EXISTS #tmpFaturamentoItem

		SELECT
			i.Doc_Faturamento
			, cast(i.Doc_Faturamento as bigint) AS [idFaturamento]
			, cast(i.Doc_Item_Faturamento as bigint) AS [idItemFaturamento]
			, cast(cast(i.Quantidade as float) as int) AS [numQuantidade]
			, cast(cast(i.Quant_Faturada as float) as int) AS [numQuantFaturada]
			, cast(i.Unidade_Venda as varchar(2)) AS [strUnidadeVenda]
			, cast(i.Unidade_Medida as varchar(2)) AS [strUnidadeMedida]
			, cast(i.Divisao as varchar(4)) AS [strDivisao]
			, cast(i.Area_Cont_Custo as int) AS [numAreaContCusto]
			, cast(i.Centro_Custo as varchar(15)) AS [strCentroCusto]
			, cast(i.Setor_Atividade as int) AS [numSetorAtividade]
			, cast(i.Peso_Bruto as numeric(12,3)) AS [numPesoBruto]
			, cast(i.Codigo_EAN as varchar(13)) AS [strCodigoEAN]
			, cast(i.Peso_Liquido as numeric(12,3)) AS [numPesoLiquido]
			, cast(i.Volume as numeric(12,3)) [numVolume]
			, cast(i.Unidade_Volume as varchar(3)) AS [strUnidadeVolume]
			, cast(i.Codigo_Material as int) AS [numCodigoMaterial]
			, cast(i.Grupo_Material as varchar(5)) AS [strGrupoMaterial]
			, cast(i.Valor_Liquido as numeric(12,3)) AS [numValorLiquido]
			, cast(i.Num_Ordem as int) AS [numNumOrdem]
			, cast(i.Centro_Fornecedor as varchar(4)) AS [strCentroDistribuicao]
			, cast(i.Centro_Regiao as varchar(2)) AS [strCentroRegiao]
			, cast(i.Centro_Lucro as varchar(9)) AS [strCentroLucro]
			, cast(i.Doc_Vendas as varchar(15)) AS [strDocVendas]
			, cast(i.Doc_Venda_Item as varchar(10)) AS [strDocVendaItem]
			, cast(i.Equipe_Vendas as varchar(4)) AS [strEquipeVendas]
			, dbo.fnConvertData(i.Data_Criacao) AS [datDataAtualizacao] -- DATA DE CRIACAO DO REGISTRO NA ORIGEM
			, GETDATE() AS [datDataCriacao] -- DATA DE IMPORTAÇÃO
			, 1 AS [idFonteDados] --SAP
			, cast(null AS VARCHAR(50)) AS strCRM
			, cast(i.Grupo_Vendas AS INT) AS numGrupoVendas
			, cast(null AS VARCHAR(50)) AS strTipoFatura
		INTO #tmpFaturamentoItem
		FROM
			[dbo].[stgItemFaturamentos] i
			JOIN #tmpFaturamento f
				ON i.Doc_Faturamento = f.Doc_Fatura
		
		-- atualiza quantidades totais na fatura
		DROP TABLE IF EXISTS #tmpQtd

		SELECT
			i.[idFaturamento]
			, SUM(i.[numQuantidade]) AS [numQuantidade]
			, SUM(i.[numQuantFaturada]) AS [numQuantidadeFaturada]
		INTO #tmpQtd
		FROM
			#tmpFaturamentoItem i
		GROUP BY
			i.[idFaturamento]
		
		UPDATE
			f
		SET
			[numQuantidade] = q.[numQuantidade]
			, [numQuantidadeFaturada] = q.[numQuantidadeFaturada]
		FROM
			#tmpFaturamento f
			JOIN #tmpQtd q
				ON f.[idFaturamento] = q.[idFaturamento]

		-- adiciona informações de médico do PW
		UPDATE
			i
		SET
			strCRM = p.indicacao_crm + p.indicacao_uf
		FROM
			#tmpFaturamentoItem i
			JOIN [dbo].[stgAPIOrdemVendas] aov
				ON ISNUMERIC(i.strDocVendas) = 1
				AND CAST(i.strDocVendas AS BIGINT) = CAST(aov.Doc_Venda AS BIGINT)
			JOIN [dbo].[stgPWPedidos_OV] pov
				ON aov.Ordem_Venda_Origem = pov.OV
			JOIN [dbo].[stgPWPedidos] p
				ON CAST(p.id_pedido AS BIGINT) = CAST(pov.id_Pedido AS BIGINT)
				AND ISNULL(p.indicacao_crm, '') <> ''
			LEFT JOIN [dbo].[stgPWMedicos] m
				ON p.indicacao_crm + p.indicacao_uf = m.crm + m.uf
				AND ISNULL(m.excluido,0) = 0

		-- identificando vendedor
		UPDATE
			f
		SET
			idVendedor = p.id_usuario
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON i.idFaturamento = f.idFaturamento
			JOIN [dbo].[stgAPIOrdemVendas] aov
				ON ISNUMERIC(i.strDocVendas) = 1
				AND CAST(i.strDocVendas AS BIGINT) = CAST(aov.Doc_Venda AS BIGINT)
			JOIN [dbo].[stgPWPedidos_OV] pov
				ON aov.Ordem_Venda_Origem = pov.OV
			JOIN [dbo].[stgPWPedidos] p
				ON CAST(p.id_pedido AS BIGINT) = CAST(pov.id_Pedido AS BIGINT)	

		--  select Func
		DROP TABLE IF EXISTS #tmpFunc

		SELECT
			ff.Doc_Faturamento
			, cast(ff.Doc_Faturamento as bigint) AS [idFaturamento]
			, cast(ff.Func_Parceiro as varchar(3)) AS [strFuncao]
			, cast(ff.Cliente as bigint) [idCliente]
			, cast(ff.Fornecedor as bigint) [idFornecedor]
			, cast(ff.Pessoa as bigint) [idPessoa]
			, cast(ff.Contato_Pessoal as varchar(120)) AS [strContatoPessoal]
			, 1 AS [idFonteDados] --SAP
		INTO #tmpFunc
		FROM
			[dbo].[stgFuncFaturamentos] ff
			JOIN #tmpFaturamento f
				ON ff.Doc_Faturamento = f.Doc_Fatura

		-- atualiza Ids das Lojas
		UPDATE
			f
		SET
			idLoja = cast(i.strCentroDistribuicao as bigint)
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				 ON f.idFaturamento = i.idFaturamento
		WHERE
			i.strCentroDistribuicao IS NOT NULL

		-- adiciona Canal Customizado
		UPDATE
			f
		SET
			[Local] = CASE WHEN l.idLoja IN (2001, 2010, 4030, 4001, 4018, 4028, 4032, 4036, 4040, 4041, 4043, 4045) THEN 'S' ELSE 'L' END -- Showroom/Loja
		FROM
			#tmpFaturamento f
			JOIN [dbo].[dwLojas] l
				ON f.idLoja = l.idLoja

		UPDATE
			f
		SET
			strCanalCustomizado = CASE f.Canal
									WHEN 60 THEN -- FRANQUIA
										CASE f.Segmento
											WHEN 2 THEN 'DISTRIBUIDOR' -- DISTRIBUIDOR
											WHEN 4 THEN 'DISTRIBUIDOR' -- MICRODISTRIBUIDOR
											WHEN 5 THEN 'FRANQUIA' -- CLIENTE FINAL
											WHEN 1 THEN 'FRANQUIA' -- FRANQUEADO
											WHEN 6 THEN 'FRANQUIA' -- INTERCOMPANY
											ELSE 'FRANQUIA'
										END
									WHEN 50 THEN -- TELEVENDAS
										CASE f.Segmento
											WHEN 2 THEN 'DISTRIBUIDOR' -- DISTRIBUIDOR
											WHEN 4 THEN 'DISTRIBUIDOR' -- MICRODISTRIBUIDOR
											WHEN 3 THEN 'FARMA' -- FARMA
											WHEN 1 THEN 'FRANQUIA' -- FRANQUEADO
											WHEN 5 THEN 'UNIDADE PROFISSIONAL' -- CLIENTE FINAL
											WHEN 9 THEN 'UNIDADE PROFISSIONAL' -- COLABORADOR
											WHEN 8 THEN 'UNIDADE PROFISSIONAL' -- ESTRANGEIRO
											WHEN 6 THEN 'UNIDADE PROFISSIONAL' -- INTERCOMPANY
											WHEN 7 THEN 'UNIDADE PROFISSIONAL' -- MÉDICO PRESCRITOR
											WHEN 10 THEN 'UNIDADE PROFISSIONAL' -- PROFISSIONAL
											ELSE 'UNIDADE PROFISSIONAL'
										END
									/*WHEN 40 THEN -- ECOMMERCE -- Nova Regra definida abaixo a partir de 01/04/2023
										CASE f.Segmento
											WHEN 10 THEN 'ECOMMERCE PROFISSIONAL' -- PROFISSIONAL
											WHEN 7 THEN 'ECOMMERCE PROFISSIONAL' -- MÉDICO PRESCRITOR
											ELSE 'ECOMMERCE CLIENTE FINAL'
										END*/
									WHEN 80 THEN 'FARMA' -- FARMA
									WHEN 20 THEN 'INTERCOMPANY' -- INTERCOMPANY
									WHEN 30 THEN -- VAREJO
										CASE f.Segmento
											WHEN 10 THEN -- PROFISSIONAL
												CASE
													WHEN f.[Local] = 'S' THEN 'UNIDADE PROFISSIONAL' -- SHOWROOM
													ELSE -- LOJA
														CASE 
															WHEN f.idLoja IN (2004, 2005, 2009, 2011, 2015, 2016, 2017, 4003, 4004, 4005, 4007, 4011, 4012, 4013, 4014, 4015, 4016) THEN
																CASE 
																	WHEN YEAR(f.[datFaturamento])*100+MONTH(f.[datFaturamento]) <= 201812 THEN 'UNIDADE PROFISSIONAL'
																	ELSE 'VAREJO'
																END
															WHEN f.idLoja IN (2008, 4010) THEN
																CASE 
																	WHEN YEAR(f.[datFaturamento])*100+MONTH(f.[datFaturamento]) <= 201912 THEN 'UNIDADE PROFISSIONAL'
																	ELSE 'VAREJO'
																END
															ELSE 'VAREJO'
														END
												END
											WHEN 7 THEN -- MÉDICO PRESCRITOR
												CASE 
													WHEN f.[Local] = 'S' THEN 'UNIDADE PROFISSIONAL' -- SHOWROOM
													ELSE 'VAREJO' -- LOJA
												END
											WHEN 5 THEN 'VAREJO' -- CLIENTE FINAL
											WHEN 9 THEN 'VAREJO' -- COLABORADOR
											WHEN 8 THEN 'VAREJO' -- ESTRANGEIRO
											WHEN 3 THEN 'VAREJO' -- FARMA
											WHEN 1 THEN 'VAREJO' -- FRANQUEADO
											WHEN 4 THEN 'VAREJO' -- MICRODISTRIBUIDOR
											WHEN 12 THEN 'VAREJO' -- PRESIDÊNCIA
											ELSE 'VAREJO'
										END
									WHEN 00 THEN 'OUTROS NÃO ESPECIFICADOS' -- OUTROS NÃO ESPECIFICADOS
									ELSE 'NÃO ATRIBUIDO'
								END
		FROM
			#tmpFaturamento f
		
		--Regra nova ECOMMERCE (Canal 40)
		--UPDATE #tmpFaturamento SET strCanalCustomizado = NULL WHERE Canal = 40

		UPDATE
			f
		SET
			strCanalCustomizado = 'ECOMMERCE CLIENTE FINAL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				 ON f.idFaturamento = i.idFaturamento
		WHERE
			i.numGrupoVendas = 600
			AND Canal IN (40, 30)

		UPDATE
			f
		SET
			strCanalCustomizado = 'ECOMMERCE CLIENTE FINAL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
			JOIN #tmpFunc ff
				ON f.idFaturamento = ff.idFaturamento
		WHERE
			i.numGrupoVendas = 600
			AND Canal = 30
			AND ff.strFuncao = 'SE'

		/*
		[16:40] Victor Soares
		Ecommerce pro
		"SalesGroup": "700"
		"DistributionChannel": "40" Ecommerce pro - pick-up e ship-from store
		"SalesGroup": "700"
		"DistributionChannel": "50"*/

		UPDATE
			f
		SET
			strCanalCustomizado = 'ECOMMERCE PROFISSIONAL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
		WHERE
			i.numGrupoVendas = 700
			AND Canal IN (40, 50)

		--regra para devolução
		UPDATE
			f
		SET
			strCanalCustomizado = 'ECOMMERCE CLIENTE FINAL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
			JOIN [dbo].[stgAPIFaturaRetorno] r
				ON i.strDocVendas = Fatura_Retorno
			JOIN [dbo].[dwFaturamentosItens] i2
				ON i2.idFaturamento = CAST(r.idFaturamento AS BIGINT)
		WHERE
			ISNULL(i.numGrupoVendas,0) = 0
			AND f.Canal = 40
			AND i2.numGrupoVendas = 600

		UPDATE
			f
		SET
			strCanalCustomizado = 'ECOMMERCE PROFISSIONAL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
			JOIN [dbo].[stgAPIFaturaRetorno] r
				ON i.strDocVendas = Fatura_Retorno
			JOIN [dbo].[dwFaturamentosItens] i2
				ON i2.idFaturamento = CAST(r.idFaturamento AS BIGINT)
		WHERE
			ISNULL(i.numGrupoVendas,0) = 0 
			AND f.Canal = 40
			AND i2.numGrupoVendas = 700
		
		--Modalidade
		/*
		Regra Omni (quando o cliente compra no Ecommerce e retira na loja)
		"SalesGroup": "600"
		"DistributionChannel": "30“
		*/
		UPDATE
			f
		SET
			strModalidade = 'OMNI CHANNEL'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
		WHERE
			f.Canal = 30 --"DistributionChannel": "30“
			AND i.numGrupoVendas = 600 --"SalesGroup": "600"

		/*
		Regra Prateleira Infinita (quando o cliente vai até a loja Fisica e faz a compra pelo Ecommerce, por “n” motivos...)
		"SalesGroup": "600"
		"DistributionChannel": "40"
		"PartnerFunction": "SE"
		*/
		UPDATE
			f
		SET
			strModalidade = 'PRATELEIRA INFINITA'
		FROM
			#tmpFaturamento f
			JOIN #tmpFaturamentoItem i
				ON f.idFaturamento = i.idFaturamento
			JOIN #tmpFunc ff
				ON f.idFaturamento = ff.idFaturamento
		WHERE
			f.Canal = 40 --"DistributionChannel": "40“
			AND i.numGrupoVendas = 600 --"SalesGroup": "600"
			AND ff.strFuncao = 'SE' --"PartnerFunction": "SE"

			--Regra que identifica o tipo de Fatura
			--Devolução
		UPDATE 
			f
		SET 
			strTipoFatura = 'Devolução'
		FROM 
			#tmpFaturamentoItem f
			JOIN stgAPIFaturaRetorno r
				ON f.strDocVendas = r.Fatura_Retorno
			JOIN stgItemFaturamentos i
				ON f.idFaturamento = i.Doc_Faturamento
		WHERE 
			r.Doc_Referencia_Item = 10
			AND i.Tipo_Processo_retorno = 'X'
			--Item Gratuito
		UPDATE 
			F
        SET 
			F.strTipoFatura = 'Item Gratuito'
		FROM 
			#tmpFaturamentoItem F
			JOIN [dbo].[stgItemFaturamentos] S
				ON F.IDFATURAMENTO = S.DOC_FATURAMENTO
		WHERE 
			S.Categoria_Documento = 'I'
			AND F.IDFATURAMENTO = S.DOC_FATURAMENTO
			AND S.Doc_Item_Faturamento = F.idItemFaturamento
			--Evento
		UPDATE 
			f
		SET		
			strTipoFatura = 'Evento' 
		FROM 
			#tmpFaturamentoItem f
			JOIN stgPWPedidos p
			ON f.strdocvendas = p.id_pedido
			JOIN stgPWEventos e
			ON p.id_evento = e.id_evento
		WHERE 
			e.tipo = 1
			AND f.idFonteDados = 1
			--Serviço
		UPDATE 
			f
		SET 
			strTipoFatura = 'Prestação de Serviço'
		FROM 
			#tmpFaturamentoItem f
		WHERE
			numSetorAtividade = 30
			--Cancelamento
			--TIPO N
		UPDATE 
			f
		SET 
			strTipoFatura = 'Cancelamento de Saída'
		FROM 
			#tmpFaturamentoItem f 
			JOIN [dbo].[stgAPIFaturamentos] i
			ON f.idFaturamento = i.Doc_Fatura
		WHERE 
			i.Doc_Fatura_Cancelada <> ' '
			AND i.Tipo_Operacao = 'N'
			--TIPO S
		UPDATE 
			f
		SET 
			strTipoFatura = 'Cancelamento de Devolução'
		FROM 
			#tmpFaturamentoItem f 
			JOIN [dbo].[stgAPIFaturamentos] i
			ON f.idFaturamento = i.Doc_Fatura
		WHERE 
			i.Doc_Fatura_Cancelada <> ' '
			AND i.Tipo_Operacao = 'S'
	    --venda
		--Tudo que não entrar nas categorias acima entra como Venda
		UPDATE 
			f
		SET 
			strTipoFatura = 'Venda'
		FROM 
			#tmpFaturamentoItem f 
		WHERE 
			f.strTipoFatura IS NULL

		--faturamento SHOP9
		DROP TABLE IF EXISTS #tmpFaturamentoS9

		SELECT
			cast(cast(1000 * m.ordem as varchar) + RIGHT(m.franquia,3) as bigint) AS [idFaturamento]
			, m.[Data_Efetivado_Financeiro] AS [datFaturamento]
			, NULL AS [strCatDocumento]
			, NULL AS [strTipoDocumento]
			, cast(cast(1000 + SUBSTRING(m.franquia,4,3) as varchar)  +  cast(10000 + m.Ordem_Cli_For as varchar) as bigint) AS [idCliente] 
			, f.Codigo * 100000 + CAST(RIGHT(f.Franquia,3) AS INT) AS [idLoja]
			, NULL AS [strGrupoClientes]
			, 'BR' AS [strPaisDestino]
			, f.UF AS [strUfEstado]
			, NULL AS [strOrgVendas]
			, '60' AS [strCanalDistribuicao]
			, NULL AS [strSetorAtividade]
			, m.Preco_Total_Sem_Desconto_Somado AS [numValorBrutoToT]
			, m.Preco_Total_Com_Desconto_Somado AS [numValorLiquidoToT]
			, NULL AS [numValorImpostoToT]
			, m.Qtde_Total_Geral AS [numQuantidade]
			, m.Qtde_Total_Prod AS [numQuantidadeFaturada]
			, m.[Data] AS [datAtualizacao] -- DATA DE CRIACAO DO REGISTRO NA ORIGEM
			, GETDATE() AS [datDataCriacao] -- DATA DE IMPORTAÇÃO
			, NULL AS [numComissao]
			, 2 AS [idFonteDados]
			, cast(null as VARCHAR(1)) as [Local]
			, 'SELL OUT FRANQUEADO' AS [strCanalCustomizado]
			, cast(null AS BIGINT) AS [idParceiro]
			, cast(null AS BIGINT) AS [idVendedor]
			, cast(NULL AS VARCHAR(2)) AS [TipoOperacao]
			, CAST(NULL AS VARCHAR(25)) AS [strModalidade]
		INTO #tmpFaturamentoS9
		FROM
			[dbo].[stgSHOP9Movimentos] m
			LEFT JOIN [dbo].[stgSHOP9Filiais] f
				ON  cast(m.Ordem_Filial as varchar) + m.Franquia = cast(f.Ordem as varchar) + f.Franquia
		WHERE
			m.Tipo_Operacao in ('VND','DEV','VEF','VPC')
       		AND m.Apagado = 0
			AND m.DesefEstoque = 'false'

		--itens SHOP9
		DROP TABLE IF EXISTS #tmpFaturamentoItemS9

		SELECT
			cast(cast(1000 * i.ordem_movimento as varchar) + RIGHT(i.franquia,3) as bigint) AS [idFaturamento]
			, cast(cast(1000 * i.ordem as varchar) + RIGHT(i.franquia,3) as bigint) AS [idItemFaturamento]
			, cast(cast(i.Quantidade_Itens as float) as bigint) AS [numQuantidade]
			, cast(cast(i.Quantidade as float) as bigint) AS [numQuantFaturada]
			, NULL AS [strUnidadeVenda]
			, NULL AS [strUnidadeMedida]
			, NULL AS [strDivisao]
			, NULL AS [numAreaContCusto]
			, NULL AS [strCentroCusto]
			, NULL AS [numSetorAtividade]
			, cast(i.Peso_Bruto as numeric(18,3)) AS [numPesoBruto]
			, p.Codigo_Barras AS [strCodigoEAN]
			, cast(i.Peso_Liquido as numeric(18,3)) AS [numPesoLiquido]
			, cast(i.Cubagem as numeric(18,3)) AS [numVolume]
			, NULL AS [strUnidadeVolume]
			, dp.idProduto AS [numCodigoMaterial]
			, dp.strGrupo AS [strGrupoMaterial]
			, cast(i.Preco_Total_Com_Desconto as numeric(18,3)) AS [numValorLiquido]
			, cast(i.Ordem_Prod_Serv as bigint) AS [numNumOrdem]
			, NULL AS [strCentroDistribuicao]
			, NULL AS [strCentroRegiao]
			, NULL AS [strCentroLucro]
			, cast(i.Pedido as varchar(15)) AS [strDocVendas]
			, NULL [strDocVendaItem]
			, NULL [strEquipeVendas]
			, m.[Data_Efetivado_Financeiro] AS [datDataAtualizacao] -- DATA DE CRIACAO DO REGISTRO NA ORIGEM
			, GETDATE() AS [datDataCriacao] -- DATA DE IMPORTAÇÃO
			, 2 AS [idFonteDados]
			, cast(null AS VARCHAR(50)) AS strCRM
			, cast(null as INT) as numGrupoVendas
			, CAST(NULL AS VARCHAR(50)) AS [strTipoFatura]
		INTO #tmpFaturamentoItemS9
		FROM
			[dbo].[stgSHOP9MovimentoProdServ] i
			LEFT JOIN [dbo].[stgSHOP9Movimentos] m
				ON cast(m.Ordem AS varchar) + m.Franquia = cast(i.Ordem_Movimento AS varchar) + i.Franquia
			LEFT JOIN ( 
				SELECT DISTINCT Ordem, Codigo_Barras, Franquia, tipo
				FROM [dbo].[stgSHOP9Produtos] 
				WHERE ISNULL(Codigo_Barras, '') <> ''
			) p
				ON cast(p.Ordem AS varchar) + p.Franquia = cast(i.Ordem_Prod_Serv AS varchar) + i.Franquia
			LEFT JOIN [dbo].[vw_Produtos] dp
				ON p.Codigo_Barras = dp.strCodigoBarras
		WHERE
			m.Tipo_Operacao in ('VND','DEV','VEF','VPC')
       		AND m.Apagado = 0
			AND m.DesefEstoque = 'false'
       		AND ISNULL(p.tipo,'') <> 'V'
       		AND i.LinhaExcluida = 0

		--- deleta dados da tabela dwFaturamento
		delete 
		from [dbo].[dwFaturamento]
		where datFaturamento >= CAST(getdate() - @DiasIncremento AS DATE)

		--- Insert Into dwFaturamento
		INSERT INTO [dbo].[dwFaturamento]
		SELECT
			[idFaturamento]
			,[datFaturamento]
			,[strCatDocumento]
			,[strTipoDocumento]
			,[idCliente]
			,[idLoja]
			,[strGrupoClientes]
			,[strPaisDestino]
			,[strUfEstado]
			,[strOrgVendas]
			,[strCanalDistribuicao]
			,[strSetorAtividade]
			,[numValorBrutoToT]
			,[numValorLiquidoToT]
			,[numValorImpostoToT]
			,[numQuantidade]
			,[numQuantidadeFaturada]
			,[datAtualizacao]
			,[datDataCriacao]
			,[numComissao]
			,[idFonteDados]
			,[strCanalCustomizado]
			,[idParceiro]
			,[idVendedor]
			,[TipoOperacao]
			,[strModalidade]
		FROM
			#tmpFaturamento
		
		INSERT INTO [dbo].[dwFaturamento]
		SELECT
			[idFaturamento]
			,[datFaturamento]
			,[strCatDocumento]
			,[strTipoDocumento]
			,[idCliente]
			,[idLoja]
			,[strGrupoClientes]
			,[strPaisDestino]
			,[strUfEstado]
			,[strOrgVendas]
			,[strCanalDistribuicao]
			,[strSetorAtividade]
			,[numValorBrutoToT]
			,[numValorLiquidoToT]
			,[numValorImpostoToT]
			,[numQuantidade]
			,[numQuantidadeFaturada]
			,[datAtualizacao]
			,[datDataCriacao]
			,[numComissao]
			,[idFonteDados]
			,[strCanalCustomizado]
			,[idParceiro]
			,[idVendedor]
			,[TipoOperacao]
			,[strModalidade]
		FROM
			#tmpFaturamentoS9

		--- deleta dados da tabela dwFaturamentoItens
		delete 
		from [dbo].[dwFaturamentosItens]
		where [datDataAtualizacao] >= CAST(getdate() - @DiasIncremento AS DATE)

		--- Insert Into dwFaturamentosItens
		INSERT INTO [dbo].[dwFaturamentosItens]
		SELECT
			[idFaturamento]
			,[idItemFaturamento]
			,[numQuantidade]
			,[numQuantFaturada]
			,[strUnidadeVenda]
			,[strUnidadeMedida]
			,[strDivisao]
			,[numAreaContCusto]
			,[strCentroCusto]
			,[numSetorAtividade]
			,[numPesoBruto]
			,[strCodigoEAN]
			,[numPesoLiquido]
			,[numVolume]
			,[strUnidadeVolume]
			,[numCodigoMaterial]
			,[strGrupoMaterial]
			,[numValorLiquido]
			,[numNumOrdem]
			,[strCentroDistribuicao]
			,[strCentroRegiao]
			,[strCentroLucro]
			,[strDocVendas]
			,[strDocVendaItem]
			,[strEquipeVendas]
			,[datDataAtualizacao]
			,[datDataCriacao]
			,[idFonteDados]
			,[strCRM]
			,[numGrupoVendas]
			,[strTipoFatura]
		FROM 
			#tmpFaturamentoItem
		
		INSERT INTO [dbo].[dwFaturamentosItens]
		SELECT
			[idFaturamento]
			,[idItemFaturamento]
			,[numQuantidade]
			,[numQuantFaturada]
			,[strUnidadeVenda]
			,[strUnidadeMedida]
			,[strDivisao]
			,[numAreaContCusto]
			,[strCentroCusto]
			,[numSetorAtividade]
			,[numPesoBruto]
			,[strCodigoEAN]
			,[numPesoLiquido]
			,[numVolume]
			,[strUnidadeVolume]
			,[numCodigoMaterial]
			,[strGrupoMaterial]
			,[numValorLiquido]
			,[numNumOrdem]
			,[strCentroDistribuicao]
			,[strCentroRegiao]
			,[strCentroLucro]
			,[strDocVendas]
			,[strDocVendaItem]
			,[strEquipeVendas]
			,[datDataAtualizacao]
			,[datDataCriacao]
			,[idFonteDados]
			,[strCRM]
			,[numGrupoVendas]
			,[strTipoFatura]
		FROM 
			#tmpFaturamentoItemS9

		--- deleta dados da tabela dwFaturamentosFunc
		delete 
		from [dbo].[dwFaturamentosFunc]
		where [idFaturamento] IN (SELECT idFaturamento FROM #tmpFunc)

		--- Insert Into dwFaturamentoFunc
		INSERT INTO [dbo].[dwFaturamentosFunc]
		SELECT
			[idFaturamento]
			,[strFuncao]
			,[idCliente]
			,[idFornecedor]
			,[idPessoa]
			,[strContatoPessoal]
			,[idFonteDados]
		FROM
			#tmpFunc

		-- atualiza dados de faturamento de clientes
			DROP TABLE IF EXISTS #tmpClientes

		SELECT
		    strCPF,
			strCNPJ,
			idparceiro,
			cast(null as datetime) AS datPrimeiraCompra,
			cast(null as datetime) AS datUltimaCompra
		INTO #tmpClientes
		FROM
			dwClientes

	DROP TABLE IF EXISTS #tmpClientesCPF

		SELECT
		    c.strCPF,
			MIN(f.datFaturamento) AS datPrimeiraCompra,
			MAX(f.datFaturamento) AS datUltimaCompra
		INTO #tmpClientesCPF
		FROM
			[dbo].[dwFaturamento] f
		JOIN dwClientes c
		ON c.idParceiro = f.idCliente
		GROUP BY
			c.strCPF

		UPDATE
			a
		SET
			datPrimeiraCompra = b.datPrimeiraCompra
		FROM
			#tmpClientes a
			JOIN #tmpClientesCPF b
				ON a.strCPF = b.strCPF

		UPDATE
			a
		SET
			datUltimaCompra = b.datUltimaCompra
		FROM
			#tmpClientes a
			JOIN #tmpClientesCPF b
				ON a.strCPF = b.strCPF

	DROP TABLE IF EXISTS #tmpClientesCNPJ

		SELECT
		    c.strCNPJ,
			MIN(f.datFaturamento) AS datPrimeiraCompra,
			MAX(f.datFaturamento) AS datUltimaCompra
		INTO #tmpClientesCNPJ
		FROM
			[dbo].[dwFaturamento] f
		JOIN dwClientes c
		ON c.idParceiro = f.idCliente
		GROUP BY
			c.strCNPJ

		UPDATE
			a
		SET
			datPrimeiraCompra = b.datPrimeiraCompra
		FROM
			#tmpClientes a
			JOIN #tmpClientesCNPJ b
				ON a.strCNPJ = b.strCNPJ

		UPDATE
			a
		SET
			datUltimaCompra = b.datUltimaCompra
		FROM
			#tmpClientes a
			JOIN #tmpClientesCNPJ b
				ON a.strCNPJ = b.strCNPJ
------------------------------------------------------
		UPDATE
			c
		SET
			datPrimeiraCompra = p.datPrimeiraCompra
		FROM
			[dbo].[dwClientes] c
			JOIN #tmpClientes p
				ON c.idParceiro = p.idParceiro

		UPDATE
			c
		SET
			datUltimaCompra = p.datUltimaCompra
		FROM
			[dbo].[dwClientes] c
			JOIN #tmpClientes p
				ON c.idParceiro = p.idParceiro

		--- deleta dados da tabela dwOrdemVenda
		delete 
		from [dbo].[dwOrdemVenda]
		where datCriacao >= CAST(getdate() - @DiasIncremento AS DATE)

		--- Insert Into dwOrdemVenda
		INSERT INTO [dbo].[dwOrdemVenda]
		SELECT
			CAST(Doc_Venda AS VARCHAR(15)) AS strDocVendas,
			CAST(Ordem_Venda_Origem AS VARCHAR(MAX)) AS strOrdemVenda,
			dbo.fnConvertData(Data_Criacao) AS datCriacao,
			GETDATE() AS datAtualizacao
		FROM
			[dbo].[stgAPIOrdemVendas]

		-- Data Quality
		DECLARE @data DATETIME
		SELECT @data = MAX([data]) FROM [dbo].[dwIncremental]

		DECLARE @diaInicioFaturamento DATE
		DECLARE @diaFimFaturamento DATE
		DECLARE @numRegistrosFaturamentoSAP INT
		DECLARE @faturamentoLiquidoSAP NUMERIC(12,2)
		DECLARE @faturamentoBrutoSAP NUMERIC(12,2)
		DECLARE @quatidadeSAP INT
		DECLARE @quatidadeFaturadaSAP INT
		DECLARE @numRegistrosFaturamentoS9 INT
		DECLARE @faturamentoLiquidoS9 NUMERIC(12,2)
		DECLARE @faturamentoBrutoS9 NUMERIC(12,2)
		DECLARE @quatidadeS9 INT
		DECLARE @quatidadeFaturadaS9 INT
		DECLARE @numRegFatSemClienteSAP INT
		DECLARE @numRegFatSemClienteS9 INT
		DECLARE @numRegFatSemLojaSAP INT
		DECLARE @numRegFatSemLojaS9 INT
		DECLARE @numRegistrosOrdemVenda INT

		SELECT @diaInicioFaturamento = MIN(a.datAtualizacao) FROM (SELECT DISTINCT datAtualizacao FROM #tmpFaturamento UNION ALL SELECT DISTINCT datAtualizacao FROM #tmpFaturamentoS9) a
		SELECT @diaFimFaturamento = MAX(a.datAtualizacao) FROM (SELECT DISTINCT datAtualizacao FROM #tmpFaturamento UNION ALL SELECT DISTINCT datAtualizacao FROM #tmpFaturamentoS9) a
		SELECT @numRegistrosFaturamentoSAP = COUNT(*) FROM #tmpFaturamento
		SELECT @faturamentoLiquidoSAP = SUM(numValorLiquidoToT) FROM #tmpFaturamento
		SELECT @faturamentoBrutoSAP = SUM(numValorBrutoToT) FROM #tmpFaturamento
		SELECT @quatidadeSAP = SUM(numQuantidade) FROM #tmpFaturamento
		SELECT @quatidadeFaturadaSAP = SUM(numQuantidadeFaturada) FROM #tmpFaturamento
		SELECT @numRegistrosFaturamentoS9 = COUNT(*) FROM #tmpFaturamentoS9
		SELECT @faturamentoLiquidoS9 = SUM(numValorLiquidoToT) FROM #tmpFaturamentoS9
		SELECT @faturamentoBrutoS9 = SUM(numValorBrutoToT) FROM #tmpFaturamentoS9
		SELECT @quatidadeS9 = SUM(numQuantidade) FROM #tmpFaturamentoS9
		SELECT @quatidadeFaturadaS9 = SUM(numQuantidadeFaturada) FROM #tmpFaturamentoS9
		SELECT @numRegFatSemClienteSAP = COUNT(*) FROM #tmpFaturamento WHERE idCliente IS NULL
		SELECT @numRegFatSemClienteS9 = COUNT(*) FROM #tmpFaturamentoS9 WHERE idCliente IS NULL
		SELECT @numRegFatSemLojaSAP = COUNT(*) FROM #tmpFaturamento WHERE idLoja IS NULL
		SELECT @numRegFatSemLojaS9 = COUNT(*) FROM #tmpFaturamentoS9 WHERE idLoja IS NULL
		SELECT @numRegistrosOrdemVenda = COUNT(*) FROM [dbo].[stgAPIOrdemVendas]

		UPDATE
			[dbo].[dwIncremental]
		SET
			[diaInicioFaturamento] = @diaInicioFaturamento,
			[diaFimFaturamento] = @diaFimFaturamento,
			[numRegistrosFaturamentoSAP] = @numRegistrosFaturamentoSAP,
			[faturamentoLiquidoSAP] = @faturamentoLiquidoSAP,
			[faturamentoBrutoSAP] = @faturamentoBrutoSAP,
			[quatidadeSAP] = @quatidadeSAP,
			[quatidadeFaturadaSAP] = @quatidadeFaturadaSAP,
			[numRegistrosFaturamentoS9] = @numRegistrosFaturamentoS9,
			[faturamentoLiquidoS9] = @faturamentoLiquidoS9,
			[faturamentoBrutoS9] = @faturamentoBrutoS9,
			[quatidadeS9] = @quatidadeS9,
			[quatidadeFaturadaS9] = @quatidadeFaturadaS9,
			[numRegFatSemClienteSAP] = @numRegFatSemClienteSAP,
			[numRegFatSemClienteS9] = @numRegFatSemClienteS9,
			[numRegFatSemLojaSAP] = @numRegFatSemLojaSAP,
			[numRegFatSemLojaS9] = @numRegFatSemLojaS9,
			[numRegistrosOrdemVenda] = @numRegistrosOrdemVenda
		WHERE
			[data] = @data

		-- apaga tabelas temporárias
		DROP TABLE IF EXISTS #tmpFaturamento
		DROP TABLE IF EXISTS #tmpFaturamentoItem
		DROP TABLE IF EXISTS #tmpQtd
		DROP TABLE IF EXISTS #tmpFunc
		DROP TABLE IF EXISTS #tmpFaturamentoS9
		DROP TABLE IF EXISTS #tmpFaturamentoItemS9

		--apagar stage
		TRUNCATE TABLE [dbo].[stgAPIFaturamentos]
		TRUNCATE TABLE [dbo].[stgItemFaturamentos]
		TRUNCATE TABLE [dbo].[stgFuncFaturamentos]
		TRUNCATE TABLE [dbo].[stgSHOP9Movimentos]
		TRUNCATE TABLE [dbo].[stgSHOP9MovimentoProdServ]
		TRUNCATE TABLE [dbo].[stgAPIOrdemVendas]
		TRUNCATE TABLE [dbo].[stgPWPedidos_OV]
		TRUNCATE TABLE [dbo].[stgPWPedidos]

END

