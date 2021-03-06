
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_GetLocationForSignOut]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:	Antoine Ibrahim
-- Description:	Will return the id of a project node.
-- If the project node doesn't exist, it will return 
-- the id of the project folder as a negative value.
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_GetLocationForSignOut]
	@p_VaultId BIGINT,
	@p_RevisionType NVARCHAR(32),
	@p_Project NVARCHAR(32)
AS
BEGIN

		DECLARE 
		@returnId BIGINT,
		@projectFolderName NVARCHAR(255)

	-- If this is a new revision it goes in Active Documents.
	SET @projectFolderName = CASE WHEN @p_RevisionType = 'New Revision' THEN 'Active Documents' ELSE @p_RevisionType END

	-- See if there already is a LLProjectObjID with this revision type.
	SELECT TOP 1
		@returnId = r.LLProjectObjID 
	FROM CRT_REVISION r
	WHERE 
			r.DrawingID = (SELECT TOP 1 DrawingId FROM CRT_REVISION WHERE LLObjID = @p_VaultId)
		AND	r.project = @p_Project	
		AND r.RevisionType = (	SELECT 
									REVTYPEID 
								FROM CRT_REVISION_TYPE_MAP 
								WHERE 
										OUID = 2 
									AND DISPLAY_TYPE_NAME = @p_RevisionType)
	ORDER BY RevisionID DESC

	-- If there wasn't get the folder this should go in. Return it as a negative so the other side knows it is a folder
	-- and not the node dataid.
	IF (@returnId IS NULL)
	BEGIN
		SELECT
			@returnId = p.DataID * -1
		FROM DTree p 
		WHERE
				p.Name = @projectFolderName 
			AND	p.ParentID = (	SELECT 
									PROJECTID 
								FROM CRT_PROJECT 
								WHERE 
										PROJECT = @p_Project 
									AND OUID = 2)				
	END

	SELECT @returnId
END


GO
