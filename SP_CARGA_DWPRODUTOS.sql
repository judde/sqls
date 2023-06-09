/****** Object:  StoredProcedure [dbo].[SP_CARGA_DWPRODUTOS]    Script Date: 13/04/2023 16:14:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER  PROCEDURE [dbo].[SP_CARGA_DWPRODUTOS]
 
AS
    BEGIN

		DROP TABLE IF EXISTS #tmpProdutos
		DROP TABLE IF EXISTS #tmpProdutos1


		--- select Produtos
		select 
			cast(p.IDProduto as bigint) idProduto,
			cast(d.Desc_Produto as varchar(255)) as strDescProduto,
			cast(p.Produto_Tipo as varchar(10)) as strProdutoTipo,
			cast(p.Planta_Status as varchar(5)) as strPlantaStatus,
			dbo.fnConvertData(p.Data_Validade) as datValidade,
			dbo.fnConvertData(p.Data_Criacao) as datCriacao,
			dbo.fnConvertData(p.Data_Ultima_Carga) as datUltimaCarga,
			cast(p.IDProduto_Ant as varchar(50)) as idProdutoAnt,
			cast(p.CodBarras as VarChar(50)) as strCodigoBarras,
			cast(p.Peso_Bruto as float) as numPesoBruto,
			cast(p.Unidade as varchar(5)) as strUnidade,
			cast(p.Peso_Liquido as float) as numPesoLiquido,
			cast(p.Grupo as varchar(10)) as strGrupo,
			cast(p.Grupo_Categoria as varchar(10)) as strGrupoCategoria, 
			cast(p.Hierarquia as varchar(50)) as strHierarquia,
			cast(p.Divisao as varchar(5)) as strDivisao,
			1 as [idFonteDados],
			GETDATE() as [datAtualizacao],
			CAST(null AS VARCHAR(15)) as [strProdutoClass]
		into #tmpProdutos
		from [dbo].[stgAPIProdutos] p
		inner join [dbo].[stgAPIDescProdutos] d on p.IDProduto = d.IDProduto

		select 
			cast(p.Codigo as numeric(18,0)) as idProduto,
			cast(p.Nome as varchar(255)) as strDescProduto,
			cast(p.Tipo as varchar(10)) as strProdutoTipo,
			cast(NULL as varchar(5)) as strPlantaStatus,
			cast(NULL AS DATETIME) as datValidade,
			p.Data_Cadastro as datCriacao,
			cast(NULL AS DATETIME) as datUltimaCarga,
			cast(p.Produto_ANP as varchar(50)) as idProdutoAnt,
			cast(p.Codigo_Barras as VarChar(50)) as strCodigoBarras,
			cast(p.Peso_Bruto as float) as numPesoBruto,
			cast(NULL as varchar(5)) as strUnidade,
			cast(p.Peso_Liq as float) as numPesoLiquido,
			cast(p.Ordem_Grupo as varchar(10)) as strGrupo,
			cast(NULL as varchar(10)) as strGrupoCategoria, 
			cast(NULL as varchar(50)) as strHierarquia,
			cast(NULL as varchar(5)) as strDivisao,
			2 as [idFonteDados],
			GETDATE() as [datAtualizacao],
			CAST(null AS VARCHAR(15)) as [strProdutoClass]
		into #tmpProdutos1
		from [dbo].[stgSHOP9Produtos] p
		where isnumeric(p.Codigo) = 1

		-- Cruza os produtos da API com Shop9 e ajusta/inclui informações
		UPDATE
			s
		SET
			strPlantaStatus = a.strPlantaStatus,
			datValidade = a.datValidade,
			datUltimaCarga = a.datUltimaCarga,
			strUnidade = a.strUnidade,
			strGrupoCategoria = a.strGrupoCategoria,
			strHierarquia = a.strHierarquia,
			strDivisao = a.strDivisao,
			strProdutoTipo = a.strProdutoTipo
		FROM
			#tmpProdutos1 s
			JOIN #tmpProdutos a
				ON s.strCodigoBarras = a.strCodigoBarras
				AND ISNULL(s.strCodigoBarras, '') <> ''

		--- deleta dados da tabela dwProdutos
		truncate table [dbo].[dwProdutos]

		--- Insert Into dwProdutos
		INSERT INTO [dbo].[dwProdutos]
		select *
		from #tmpProdutos

		INSERT INTO [dbo].[dwProdutos]
		select *
		from #tmpProdutos1

		update 
			dwProdutos 
		set 
			strProdutoClass = case 
				when strProdutoTipo = 'FERT' 
					then 'FAB Própria' 
                else 
					case 
						when strProdutoTipo = 'HAWA' 
							then  'Prod Homologado'
						else 'Indefinido'
					end
				end
		
		-- Data Quality
		DECLARE @data DATETIME
		SELECT @data = MAX([data]) FROM [dbo].[dwIncremental]

		DECLARE @numProdutosSAP INT
		DECLARE @numProdutosS9 INT
		DECLARE @numProdutosDuplicados INT

		SELECT @numProdutosSAP = COUNT(*) FROM #tmpProdutos
		SELECT @numProdutosS9 = COUNT(*) FROM #tmpProdutos1
		SELECT @numProdutosDuplicados = SUM(a.Conta) FROM (SELECT COUNT(DISTINCT strCodigoBarras) AS Conta FROM dwProdutos GROUP BY strCodigoBarras HAVING COUNT(DISTINCT idProduto) > 1) a

		UPDATE
			[dbo].[dwIncremental]
		SET
			[numProdutosSAP] = @numProdutosSAP,
			[numProdutosS9] = @numProdutosS9,
			[numProdutosDuplicados] = @numProdutosDuplicados
		WHERE
			[data] = @data
END



