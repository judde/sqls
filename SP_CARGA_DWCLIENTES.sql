	/****** Object:  StoredProcedure [dbo].[SP_CARGA_DWCLIENTES]    Script Date: 09/04/2023 22:04:09 ******/
	SET ANSI_NULLS ON
	GO

	SET QUOTED_IDENTIFIER ON
	GO


	CREATE PROCEDURE [dbo].[SP_CARGA_DWCLIENTES] @numDias INT
 
	AS
		BEGIN

			DROP TABLE IF EXISTS #tmpClientes
			DROP TABLE IF EXISTS #tmpClientesEmails
			DROP TABLE IF EXISTS #tmpClientesEnderecos
			DROP TABLE IF EXISTS #tmpClientes1
			DROP TABLE IF EXISTS #tmpClientesEnderecos1
			DROP TABLE IF EXISTS #tmpClientesFones
			DROP TABLE IF EXISTS #tmpClientesFones1
			DROP TABLE IF EXISTS #tmpClientesUnicos
			DROP TABLE IF EXISTS #tmpClientesUnicos1
			DROP TABLE IF EXISTS #tmpAuxMunicip
	
			--- *** API/SAP ***
			-- select de Clientes
			select 
				cast(c.idParceiro as bigint) idParceiro,
				cast(c.Nome_Completo as varchar(100)) strNomeCompleto,
				cast(c.Categoria as int) numCategoria,
				cast(c.Grupo as varchar(10)) strGrupo,
				cast(c.Feminino as bit) bitFeminino,
				cast(c.Masculino as bit) bitMasculino,
				cast(c.Genero_Desconhecido as bit) bitGeneroDesconhecido,
				case when c.Pessoa = 'X' then 1 else 0 end bitPessoa,
				case when pf.Numero is not null then 1 else 0 end bitPF,
				case when pj.Numero is not null then 1 else 0 end bitPJ,
				dbo.fnConvertData(c.[Data_Nasc]) as datAniversario,
				1 [idFonteDados],
				cast(pj.numero as varchar(18)) [strCNPJ],
				cast(pf.numero as varchar(14)) [strCPF],
				cast(null AS DATETIME) as [datCriacao],
				getdate() [datAtualizacao],
				c.Data_Criacao AS [strDatCriacaoTimestmp],
				cast(null AS DATETIME) AS datPrimeiracompra,
				cast(null AS DATETIME) AS datUltimaCompra,
				CASE WHEN c.Contribuinte_ICMS IS NULL THEN NULL WHEN c.Contribuinte_ICMS = 'ISENTO' THEN 'ISENTO' ELSE 'REVENDEDOR' END AS strContribuinteICMS
			into #tmpClientes
			from [dbo].[stgAPIClientes] c 
				left join [dbo].[stgAPIPessoaFisica] pf 
					on c.IdParceiro = pf.IDParceiro
				left join [dbo].[stgAPIPessoaJuridica] pj 
					on c.IdParceiro = pj.IDParceiro

			UPDATE
				#tmpClientes
			SET
				[datCriacao] = [dbo].[fnConvertData]([strDatCriacaoTimestmp])

			-- select de Endereços
			select 
				cast([idPaceiro] as bigint) as [idParceiro],
				cast([idEndereco] as bigint) as [idEndereco],
				cast([Time_Zona] as varchar(50)) as [strTimeZone],
				cast([Pais] as varchar(20)) as [strPais],
				cast([Estado] as varchar(3)) as [strEstado],
				cast(CASE WHEN LTRIM(RTRIM(ISNULL([Cidade], ''))) = '' THEN [Nome_Cidade] ELSE [Cidade] END as varchar(100)) as [strNomeCidade],
				cast([Bairro] as varchar(30)) as [strBairro],
				cast([Endereco] as varchar(150)) as [strEndereco],
				cast([Numero] as varchar(20)) as [strNumero],
				cast([Endereco_Complemento] as varchar(50)) as [strEnderecoComplemento], 
				case
					when [dbo].[fnVerificaCep]([CEP]) = 1 then cast([CEP] as varchar(10))
					else null
				end as [strCEP],
				getdate() [datAtualizacao],
				CAST(NULL AS DATETIME) as [datCriacao],
				1 idFonteDados,
				null [Municipio Codigo IBGE],
				REPLACE(Data_Val_Inicial, '+0000', '') AS strDataInicialTimestmp
			into #tmpClientesEnderecos
			from
				[dbo].[stgAPIEndereco]

			UPDATE
				#tmpClientesEnderecos
			SET
				[datCriacao] = [dbo].[fnConvertData]([strDataInicialTimestmp])
	

			-- select de Email
			select 
				cast(IDEndereco as bigint) as [idEndereco],
				CAST(NULL AS BIGINT) AS [idParceiro],
				cast([Num_Ordinario] as bigint) as [idEmail],
				Email as [strEmail],
				1 as idFontedados,
				getdate() [datAtualizacao],
				CAST(NULL AS DATETIME) as [datCriacao]
			into #tmpClientesEmails
			from  [dbo].[stgAPIEmails]
			where [dbo].[fnValidarEmail](Email) = 1

			UPDATE
				em
			SET 
				[idParceiro] = e.[idParceiro],
				[datCriacao] = e.[datCriacao]
			FROM
				#tmpClientesEmails em
				JOIN #tmpClientesEnderecos e
					ON em.[idEndereco] = e.[idEndereco]

			-- select de Fones
			select 
				cast(IDEndereco as bigint) as [idEndereco],
				CAST(NULL AS BIGINT) AS [idParceiro],
				cast([Num_Ordinario] as bigint) as [idFone],
				cast(Fone_Internacional as varchar(50)) as [strFoneInternacional],
				1 as idFonteDados,
				getdate() as [datAtualizacao],
				CAST(NULL AS DATETIME) as [datCriacao]
			into #tmpClientesFones
			from [dbo].[stgAPITelefone]
			where [dbo].[fnValidaTelefone](Fone_Internacional) = 1

			UPDATE
				f
			SET 
				[idParceiro] = e.[idParceiro],
				[datCriacao] = e.[datCriacao]
			FROM
				#tmpClientesFones f
				JOIN #tmpClientesEnderecos e
					ON f.[idEndereco] = e.[idEndereco]
		
			--- *** dwClientes ***
			--- deleta dados da tabela dwClientes (incremental)
			delete 
			FROM [dbo].[dwClientes]
			WHERE datCriacao >= CAST(getdate() - @numDias AS DATE)

			--- Insert Into dwClientes
			INSERT INTO [dbo].[dwClientes]
			select	idParceiro
					,strNomeCompleto
					,numCategoria
					,strGrupo
					,bitFeminino
					,bitMasculino
					,bitGeneroDesconhecido
					,bitPessoa
					,bitPF
					,bitPJ
					,datAniversario
					,datAtualizacao
					,datCriacao
					,idFonteDados
					,strCNPJ
					,strCPF
					,null strCPFCNPJUnico
					,null datPrimeiraCompra
					,null datUltimaCompra
					,strContribuinteICMS
			from #tmpClientes

			--- *** dwClientesEnderecos ***
			--- deleta dados da tabela dwClientesEnderecos (incremental)
			delete 
			FROM [dbo].[dwClientesEnderecos]
			WHERE datCriacao >= CAST(getdate() - @numDias AS DATE)

			--- Insert Into [dwClientesEnderecos]
			INSERT INTO [dbo].[dwClientesEnderecos]
			select	[idParceiro],
					[idEndereco],
					[strTimeZone],
					[strPais],
					[strEstado],
					[strNomeCidade],
					[strBairro],
					[strEndereco],
					[strNumero],
					[strEnderecoComplemento],
					[strCEP],
					[idFonteDados],
					[datAtualizacao],
					[datCriacao],
					[Municipio Codigo IBGE]
			from #tmpClientesEnderecos


			--- *** dwClientesEmails ***
			--- deleta dados da tabela dwClientesEmails (incremental)
			delete 
			FROM [dbo].[dwClientesEmails]
			WHERE datCriacao >= CAST(getdate() - @numDias AS DATE)

			--- Insert Into dwClientesEmails
			INSERT INTO [dbo].[dwClientesEmails]
			select 
				[idParceiro]
				,[idEmail]
				,[strEmail]
				,[idFonteDados]
				,[datAtualizacao]
				,[datCriacao]
			from #tmpClientesEmails

			---*** dwClientesFones ***
			--- deleta dados da tabela dwClientesFones (incremental)
			delete 
			FROM [dbo].[dwClientesFones]
			WHERE datCriacao >= CAST(getdate() - @numDias AS DATE)

			--- Insert Into dwClientesFones
			INSERT INTO [dbo].[dwClientesFones]
			select 
				[idParceiro]
				,[idFone]
				,[strFoneInternacional]
				,[idFonteDados]
				,[datAtualizacao]
				,[datCriacao]
			from #tmpClientesFones


		--- *** SHOP9 ***
		---select clientes
		select 
				idParceiro,
				strNomeCompleto,
				numCategoria,
				strGrupo,
				bitFeminino,
				bitMasculino,
				bitGeneroDesconhecido,
				bitPessoa,
				bitPF,
				bitPJ,
				IIF(ISDATE(datAniversario)=1, cast(datAniversario as date), null) datAniversario,
				idFonteDados,
				strCNPJ,
				strCPF,
				datCriacao,
				datAtualizacao,
				strCPFCNPJUnico,
				CAST(NULL AS VARCHAR(10)) AS strContribuinteICMS
		into #tmpClientes1
		from (
		select  
				cast(cast(1000 + SUBSTRING(c.franquia,4,3) as varchar) + cast(10000 + c.ordem as varchar) as bigint) AS idParceiro,
				cast(upper(ltrim(rtrim(c.Nome))) as varchar(100)) strNomeCompleto,
				case
					when isnumeric(SUBSTRING(ccl.Nome,1,2)) = 0 then null
					else cast(SUBSTRING(ccl.Nome,1,2) as int)
				end numCategoria,
				case
					when isnumeric(SUBSTRING(ccl.Nome,1,2)) = 0 then null
					else SUBSTRING(ccl.Nome,4,3)
				end strGrupo,
				case when cc.Sexo = 'F' then 1 else 0 end bitFeminino,
				case when cc.Sexo = 'M' then 1 else 0 end bitMasculino,
				case when cc.Sexo = '' then 1 else 0 end bitGeneroDesconhecido,
				case when c.Fisica_Juridica = '' then 1 else 0 end bitPessoa,
				case when c.Fisica_Juridica = 'F' then 1 else 0 end bitPF,
				case when c.Fisica_Juridica = 'J' then 1 else 0 end bitPJ,
				'2020-' + 
					case cc.Mes_Aniv
						when 'JAN' then '01-'
						when 'FEV' then '02-'
						when 'MAR' then '03-'
						when 'ABR' then '04-'
						when 'MAI' then '05-'
						when 'JUN' then '06-'
						when 'JUL' then '07-'
						when 'AGO' then '08-'
						when 'SET' then '09-'
						when 'OUT' then '10-'
						when 'NOV' then '11-'
						when 'DEZ' then '12-'
						ELSE '01-' END + 
					case
							when CC.Dia_Aniv = '' then '01'
							when CC.Dia_Aniv = 0 then '01'
							when isNumeric(CC.Dia_Aniv) = 0 then '01'
							when len(CC.Dia_Aniv) = 0 then '01'
							when cast(CC.Dia_Aniv as int) < 1 then '01'
							when cast(CC.Dia_Aniv as int) > 31 then '01'
							else substring(cast(100+isnull(CC.Dia_Aniv,0) as varchar(3)),2,2)
					end as datAniversario,
				2 [idFonteDados],
				cast(replace(replace(c.CNPJ,'.',''),'-','') as varchar(18)) [strCNPJ],
				cast(replace(replace(c.cpf,'.',''),'-','') as varchar(14)) [strCPF],
				c.Data_Cadastro as [datCriacao],
				getdate() [datAtualizacao],
				null as strCPFCNPJUnico
		
			from [dbo].[stgSHOP9ClientesFor] c
			left join [dbo].[stgSHOP9ClientesForContatos] cc on c.Ordem = cc.Ordem and c.Franquia = cc.Franquia
			left join [dbo].[stgSHOP9ClientesForClasses] ccl on c.Ordem =ccl.Codigo and c.Franquia = ccl.Franquia

			) TB

			--- Insert Into dwClientes
			INSERT INTO [dbo].[dwClientes]
			select	idParceiro
					,strNomeCompleto
					,numCategoria
					,strGrupo
					,bitFeminino
					,bitMasculino
					,bitGeneroDesconhecido
					,bitPessoa
					,bitPF
					,bitPJ
					,datAniversario
					,datAtualizacao
					,datCriacao
					,idFonteDados
					,strCNPJ
					,strCPF
					,strCPFCNPJUnico
					,null datPrimeiraCompra
					,null datUltimaCompra
					,strContribuinteICMS
			from #tmpClientes1


			---select Endereços
			select 
				cast(cast(1000 + SUBSTRING(c.franquia,4,3) as varchar) + cast(10000 + c.ordem as varchar) as bigint) AS idParceiro,
				1 as [idEndereco],
				NULL as [strTimeZone],
				'Brasil' as [strPais],
				cast([Estado] as varchar(3)) as [strEstado],
				cast([Cidade] as varchar(100)) as [strNomeCidade],
				cast([Bairro] as varchar(30)) as [strBairro],
				cast([Endereco] as varchar(150)) as [strEndereco],
				cast([Numero] as varchar(20)) as [strNumero],
				cast([Complemento] as varchar(50)) as [strEnderecoComplemento], 
				replace(replace([cep],'-',''),'.','') [strCEP],
				2 as idFonteDados,
				/*case
					when [dbo].[fnVerificaCep]([CEP]) = 1 then cast([CEP] as varchar(10))
					else null
				end as [strCEP],*/
				getdate() [datAtualizacao],
				[Data_Cadastro] as [datCriacao],
				null as [Municipio Codigo IBGE]
			into #tmpClientesEnderecos1
			from  [dbo].[stgSHOP9ClientesFor] c

			--- Insert Into dwClientesEndereços
			INSERT INTO [dbo].[dwClientesEnderecos]
			select
				[idParceiro]
				,[idEndereco]
				,[strTimeZone]
				,[strPais]
				,[strEstado]
				,[strNomeCidade]
				,[strBairro]
				,[strEndereco]
				,[strNumero]
				,[strEnderecoComplemento]
				,[strCEP]
				,[idFonteDados]
				,[datAtualizacao]
				,[datCriacao]
				,[Municipio Codigo IBGE]
			from #tmpClientesEnderecos1

		
			-- select de Email
			select 
				cast(cast(1000 + SUBSTRING(c.franquia,4,3) as varchar) + cast(10000 + c.ordem as varchar) as bigint) AS idParceiro,
				1 as [idEmail],
				cc.Email as [strEmail],
				2 as idFonteDados,
				getdate() [datAtualizacao],
				c.[Data_Cadastro] as [datCriacao]
			into #tmpClientesEmails1
			from [dbo].[stgSHOP9ClientesFor] c
			left join [dbo].[stgSHOP9ClientesForContatos] cc on c.Ordem = cc.Ordem and c.Franquia = cc.Franquia
			where [dbo].[fnValidarEmail](cc.Email) = 1

			--- Insert Into dwClientesEmails
			INSERT INTO [dbo].[dwClientesEmails]
			select
				[idParceiro]
				,[idEmail]
				,[strEmail]
				,[idFonteDados]
				,[datAtualizacao]
				,[datCriacao]
			from #tmpClientesEmails1


			-- select de Fones
			select	[idParceiro],
					[idFone],
					[strFoneInternacional],
					[idFonteDados],
					[datAtualizacao],
					[datCriacao]
			into	#tmpClientesFones1
			from (
			select 
				cast(cast(1000 + SUBSTRING(c.franquia,4,3) as varchar) + cast(10000 + c.ordem as varchar) as bigint) AS idParceiro,
				1 as [idFone],
				cast(replace(c.Fone_1,'-','') as varchar(50)) as [strFoneInternacional],
				2 as idFonteDados,
				getdate() as [datAtualizacao],
				[Data_Cadastro] as [datCriacao]
			from [dbo].[stgSHOP9ClientesFor] c
			where LTRIM(rtrim(Fone_1)) <> ''
			AND [dbo].[fnValidaTelefone](cast(replace(c.Fone_1,'-','') as varchar(50))) = 1
		
			union
		
			select 
				cast(cast(1000 + SUBSTRING(c.franquia,4,3) as varchar) + cast(10000 + c.ordem as varchar) as bigint) AS idParceiro,
				2 as [idFone],
				cast(replace(c.Fone_2,'-','') as varchar(50)) as [strFoneInternacional],
				2 as idFonteDados,
				getdate() as [datAtualizacao],
				[Data_Cadastro] as [datCriacao]
	
			from [dbo].[stgSHOP9ClientesFor] c
			where LTRIM(rtrim(Fone_2)) <> ''
			) TB
		
			--- Insert Into dwClientesFones
			INSERT INTO [dbo].[dwClientesFones]
			select
				[idParceiro]
				,[idFone]
				,[strFoneInternacional]
				,[idFonteDados]
				,[datAtualizacao]
				,[datCriacao]
			from #tmpClientesFones1

			--- DROP TEMPORARIAS
			DROP TABLE IF EXISTS #tmpClientes
			DROP TABLE IF EXISTS #tmpClientesEmails
			DROP TABLE IF EXISTS #tmpClientesEmails1
			DROP TABLE IF EXISTS #tmpClientesEnderecos
			DROP TABLE IF EXISTS #tmpClientes1
			DROP TABLE IF EXISTS #tmpClientesEnderecos1
			DROP TABLE IF EXISTS #tmpClientesFones
			DROP TABLE IF EXISTS #tmpClientesFones1	

			-- Normalizacao de Enderecos por cidade/uf tratado
			UPDATE
				e
			SET
				[Municipio Codigo IBGE] = m.[codigo ibge]
			FROM 
				dwClientesEnderecos e
				JOIN dwMunicipios m 
				ON [dbo].[fnRemove_Acentos]([dbo].[fnRemove_Caracteres_Especiais](e.strNomeCidade)) + '/' + [dbo].[fnRemove_Caracteres_Especiais](e.strEstado)
					= [dbo].[fnRemove_Acentos]([dbo].[fnRemove_Caracteres_Especiais](m.nome)) + '/' + [dbo].[fnRemove_Caracteres_Especiais](m.[sigla uf])
			WHERE
				[Municipio Codigo IBGE] IS NULL

			-- cruzamento por CEP
			UPDATE
				e
			SET
				[Municipio Codigo IBGE] = c.[Codigo Municipio Ibge]
			FROM
				dwClientesEnderecos e
				JOIN dwCeps c
					ON REPLACE(REPLACE(LTRIM(RTRIM(e.strCEP)), '.', ''), '-', '') = c.cep
			WHERE
				[Municipio Codigo IBGE] IS NULL
			

			---DROP AUX
			DROP TABLE IF EXISTS #tmpAuxMunicip
			DROP TABLE IF EXISTS #dwClientes

			---CRIA AUX DWClientes
			select idParceiro, strCPF, strCNPJ, strCPFCNPJUnico
			into #dwClientes
			from dbo.dwClientes
		
			---Tira carateres
			update #dwClientes
				set strCPF = IIF(isNumeric(replace(replace(c.strCPF,'.',''),'-',''))=1,
											replace(replace(c.strCPF,'.',''),'-',''),
											null)
					,strCNPJ = IIF(isNumeric(replace(replace(replace(replace(c.strCNPJ,'.',''),'-',''),'/',''),',',''))=1,
											replace(replace(replace(replace(c.strCNPJ,'.',''),'-',''),'/',''),',',''),
											null)
			from #dwClientes c

			--- Tira caracteres
			update #dwClientes
				set strCPF = IIF( CHARINDEX('E',c.strCPF)=0,c.strCPF,null)
					,strCNPJ = IIF( CHARINDEX('E',c.strCNPJ)=0,c.strCNPJ,null)
			from #dwClientes c
		
			--- tira caracteres
			update #dwClientes
				set		strCPF = IIF( CHARINDEX(',',c.strCPF)=0,replace(c.strCPF,',',''),null)
						,strCNPJ = IIF( CHARINDEX(',',c.strCNPJ)=0,replace(c.strCNPJ,',',''),null)
			from #dwClientes c


			--- valida CPF/CNPJ
			update #dwClientes
				set strCPF = IIF(dbo.fnValidaCPF(c.strCPF)=1,c.strCPF,null)
					,strCNPJ = IIF(dbo.fnValidaCNPJ(c.strCNPJ)=1,c.strCNPJ,null)
			from #dwClientes c

			---Grava na dwClientes
			update dbo.dwClientes
				set strCPF = c.strCPF, 
					strCNPJ = c.strCNPJ,
					strCPFCNPJUnico = IIF(dwc.bitPF=1,c.strCPF,c.strCNPJ)
			from #dwClientes c
			inner join dbo.dwClientes dwc on c.idParceiro = dwc.idParceiro
		
		

			--- TRUNCATE STGs
			TRUNCATE TABLE [dbo].[stgAPIEnderecoEmailTelefoneMobile]
			TRUNCATE TABLE [dbo].[stgAPIClientes]
			TRUNCATE TABLE [dbo].[stgAPIPessoaFisica]
			TRUNCATE TABLE [dbo].[stgAPIPessoaJuridica]
			TRUNCATE TABLE [dbo].[stgAPIEndereco]
			TRUNCATE TABLE [dbo].[stgAPIEmails]
			TRUNCATE TABLE [dbo].[stgAPITelefone]
			TRUNCATE TABLE [dbo].[stgSHOP9ClientesFor]
			TRUNCATE TABLE [dbo].[stgSHOP9ClientesForContatos]


	END

	GO


