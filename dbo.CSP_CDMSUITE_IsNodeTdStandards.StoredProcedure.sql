/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_IsNodeTdStandards]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will return 1 if a given vault dataid in T&D Standards or is a standard
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_IsNodeTdStandards]
	@p_VaultNodeId BIGINT
AS
BEGIN
	SELECT 
		CASE 
			WHEN ((r.Project like 'T_D Standards') or (d.DrawingType = 'Standard'))
		THEN 1 
		ELSE 0 
		END AS HasActiveOut
	FROM CRT_REVISION r
	JOIN C_CDM_Drawing d on r.LLObjID = d.DataID
	WHERE
		LLObjID = @p_VaultNodeId
		AND (r.RevisionStatus = 1 OR r.RevisionStatus = 3)
		
END;



GO
