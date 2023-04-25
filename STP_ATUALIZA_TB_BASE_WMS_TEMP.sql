USE [DBO_GESTAO_LOGISTICA]
GO

-- 25/04/2023 - Versão 1.0 - Juliana P. Santos DBA MD9i
/*

Ticket: 2269443 - Ticket Projeto de Indicadores
Responsável: Adriano Henrique Dantas - PCP
Banco de Dados: DBO_GESTAO_LOGISTICA
Nome do procedimento : STP_ATUALIZA_TB_BASE_WMS_TEMP

*/

CREATE PROCEDURE dbo.STP_ATUALIZA_TB_BASE_WMS_TEMP
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE DBO_GESTAO_LOGISTICA.DBO.TB_BASE_WMS_TEMP;

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
        FROM ORACORP..INTERFACE_WMS.V_ESTOQUE EST WITH (NOLOCK)
        LEFT JOIN
            (SELECT LODNUM AS LPN,
                ADDDTE AS DAT_ULT_MOV
            FROM ORACORP..WMS_APP_HIST.INVSUB WITH (NOLOCK)) MOV ON EST.LODNUM = MOV.LPN
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
                                        '2028');

        COMMIT TRANSACTION;
    END TRY
     BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT 'NOK TEMP WMS' AS MESSAGE;
    END CATCH;
END