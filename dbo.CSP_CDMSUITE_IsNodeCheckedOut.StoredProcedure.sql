/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_IsNodeCheckedOut]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will return 1 if a given vault dataid is checked out.
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_IsNodeCheckedOut]
	@p_VaultNodeId BIGINT
AS
BEGIN
	SELECT 
		CASE 
		WHEN EXISTS (SELECT 
					* 
				FROM CRT_REVISION r1 
				WHERE 
						r1.DrawingID = r.DrawingID 
					AND r1.RevisionStatus=2 
					AND r1.RevisionNumber > r.RevisionNumber
				) 
		THEN 1 
		ELSE 0 
		END AS HasActiveOut
	FROM CRT_REVISION r
	WHERE
		LLObjID = @p_VaultNodeId
		AND (r.RevisionStatus = 1 OR r.RevisionStatus = 3)
END;



GO
