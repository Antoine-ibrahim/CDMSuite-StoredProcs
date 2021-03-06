/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_SignOutDrawing]    Script Date: 11/1/2017 4:03:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:	Antoine Ibrahim
-- Description:	Will sign out a drawing in the
-- CRT tables.
-- =============================================
ALTER PROCEDURE [dbo].[CSP_CDMSUITE_SignOutDrawing]
	@p_ProjectNodeId BIGINT,		-- The active node id.
	@p_VaultNodeId BIGINT,			-- The vault node id.
	@p_UserId NVARCHAR(255),		-- The user id.
	@p_RevisionType NVARCHAR(32),	-- The type of revision, ie New Revision or Obsolete.
	@p_Project NVARCHAR(64)			-- The name of the project.
    
AS
BEGIN
	SET NOCOUNT ON

---------------------------------
-- Validate that the drawing is in a state that allows it to be signed out.
---------------------------------
	DECLARE @hasCurrentOrInitialRev INT
	DECLARE @hasActiveRev INT
	DECLARE @eventUserID BIGINT
	DECLARE @eventUserFullName NVARCHAR(255)
	DECLARE @DrawingID BIGINT

	SET @DrawingID=(SELECT DISTINCT DrawingID FROM CRT_REVISION WHERE LLObjID=@p_VaultNodeId)

	SET @hasCurrentOrInitialRev =(	
									SELECT 
										COUNT(1) 
									FROM CRT_REVISION rev
									WHERE 
											DrawingID=@DrawingID
										AND rev.revisionstatus IN (3,1)
								)
	 
	SET @hasActiveRev=(										
						SELECT 
							COUNT(1) 
						FROM CRT_REVISION rev
						WHERE 
								DrawingID=@DrawingID
							AND rev.revisionstatus IN (2)
					)	  
		 
	 SET @eventUserID = (SELECT id FROM KUAF WHERE name=@p_UserId)
	
	 SET @eventUserFullName =(	SELECT 
									CASE 
										WHEN MiddleName!='NULL' THEN FirstName+' ' +MiddleName+'. '+ LastName
										ELSE FirstName+' '+LastName 
									END AS Name 
								FROM KUAF
								WHERE 
									name = @p_UserId
								)

	-- It has to have a current or inital rev, and cannot have an active rev.
	IF (@hasCurrentOrInitialRev > 0 AND @hasActiveRev = 0)
	BEGIN

---------------------------------
-- Determine what the revision label should be based off of type of revision.
---------------------------------
		DECLARE @revisionLabel NVARCHAR(32)

		IF @p_RevisionType = 'New Revision' -- Get the last used revision number and increment.
		BEGIN
			SET @revisionLabel = ISNULL (
								-- This will find the largest number even if the revisions are out of order. It will also deal with revisions that have () in them.
								(SELECT TOP 1
									CASE WHEN RevisionLabel LIKE '%(%' THEN
										CAST(REPLACE(SUBSTRING(RevisionLabel,0,CHARINDEX('(',RevisionLabel, 0)), ' ', '') AS int) + 1 
									ELSE
										RevisionLabel + 1
									END RevisionLabel	
								FROM CRT_REVISION lastrev
								WHERE 
										DrawingID = (SELECT DISTINCT DrawingID FROM CRT_REVISION WHERE LLObjID = @p_VaultNodeId)
									AND lastrev.RevisionStatus != 4
									AND lastrev.RevisionType = 2
								ORDER BY 
									(CASE WHEN RevisionLabel LIKE '%(%' THEN
										LEN(REPLACE(SUBSTRING(RevisionLabel,0,CHARINDEX('(',RevisionLabel, 0)), ' ', ''))
									ELSE
										LEN(RevisionLabel)
									END) DESC, RevisionLabel DESC
								), 0
							)
		END

		IF @p_RevisionType = 'Preliminary' -- Get the last letter used and find the next one.
		BEGIN	
			DECLARE @alphaNext NVARCHAR(255)
			DECLARE @lastCharUsed NVARCHAR(5) 
			SET @lastCharUsed = ISNULL (  
								-- This will find the largest letter even if the revisions are out of order. It will also deal with revisions that have () in them.
								(SELECT TOP 1
									CASE WHEN RevisionLabel LIKE '%(%' THEN
										REPLACE(SUBSTRING(RevisionLabel,0,CHARINDEX('(',RevisionLabel, 0)), ' ', '') + ',' 
									ELSE
										RevisionLabel + ',' 
									END RevisionLabel	
								FROM CRT_REVISION lastrev
								WHERE 
										DrawingID = (SELECT DISTINCT DrawingID FROM CRT_REVISION WHERE LLObjID = @p_VaultNodeId)
									AND lastrev.RevisionStatus != 4
									AND lastrev.RevisionType = 7
								ORDER BY 
									(CASE WHEN RevisionLabel LIKE '%(%' THEN
										LEN(REPLACE(SUBSTRING(RevisionLabel,0,CHARINDEX('(',RevisionLabel, 0)), ' ', ''))
									ELSE
										LEN(RevisionLabel)
									END) DESC, RevisionLabel DESC
								), 'A'
							)			
			SELECT 	
				@alphaNext = SUBSTRING(	ALPHAREVVALUES, PATINDEX('%' + @lastCharUsed + '%', ALPHAREVVALUES) + LEN(@lastCharUsed), 10000)
			FROM CRT_REVISION_TYPE_MAP 
			WHERE 
					DISPLAY_TYPE_NAME = 'Preliminary'
				AND OUID = 2
					
			SET @revisionLabel =  SUBSTRING(@alphaNext, 0, CHARINDEX(',', @alphaNext))
		END	

		IF @p_RevisionType = 'Obsolete' 
		BEGIN
			SELECT 
				@revisionLabel = SUBSTRING(ALPHAREVVALUES,0, CHARINDEX(',',ALPHAREVVALUES))    
			FROM CRT_REVISION_TYPE_MAP 
			WHERE 
					DISPLAY_TYPE_NAME = 'Obsolete' 
				AND OUID = 2
		END

		IF @p_RevisionType = 'Supersede'
		BEGIN
			SELECT 
				@revisionLabel = SUBSTRING(ALPHAREVVALUES,0, CHARINDEX(',',ALPHAREVVALUES))    
			FROM CRT_REVISION_TYPE_MAP 
			WHERE 
					DISPLAY_TYPE_NAME = 'Supersede' 
				AND OUID = 2
		END


---------------------------------
-- Get the Project ID
---------------------------------
		DECLARE @projectId BIGINT
		SELECT @projectId = PROJECTID FROM CRT_PROJECT WHERE OUID = 2 AND PROJECT = @p_Project

---------------------------------
-- Insert row into CRT_REVISION
---------------------------------
		BEGIN TRANSACTION
		DECLARE @RevisionIdResult TABLE (RevisionId BIGINT)
		INSERT INTO CRT_REVISION (DrawingID, RevisionNumber, RevisionLabel, RevisionType, RevisionStatus, LLObjID, LLVerID, R1S, R2S, R1I, R2I, PROJECTID, Project, LLProjectObjID)
		OUTPUT INSERTED.[RevisionId] INTO @RevisionIdResult
			SELECT
				DrawingID,
				(SELECT MAX(RevisionNumber) FROM CRT_REVISION WHERE DrawingID = r.DrawingID) + 1 RevisionNumber,	
				@revisionLabel AS RevisionLabel, 
				(SELECT REVTYPEID FROM CRT_REVISION_TYPE_MAP WHERE OUID = 2 AND DISPLAY_TYPE_NAME = @p_RevisionType) RevisionType,
				2 AS RevisionStatus,
				@p_ProjectNodeId AS LLObjID,
				projectDtree.VersionNum AS LLVerId,
				'' AS R1S,	
				'' AS R2S,
				0 AS R1I,
				projectDtree.VersionNum AS R2I,
				@projectId AS PROJECTID,
				@p_Project AS Project,
				@p_ProjectNodeId AS LLProjectObjID
			FROM CRT_REVISION r
			JOIN DTree projectDtree ON @p_ProjectNodeId = projectDtree.DataID
			WHERE 
					LLObjID = @p_VaultNodeId
				AND RevisionStatus IN (3,1)

			-- Get the revision
			DECLARE @RevisionId BIGINT
			SELECT 
				@RevisionId = rev.RevisionId
			FROM @RevisionIdResult rev 
        
			--PRINT'updated revisions the new current RevisionId is '+ CAST(@RevisionId AS NVARCHAR(255))

---------------------------------
-- Insert rows into CRT_EVENT
---------------------------------
		INSERT INTO CRT_EVENT
				( RevisionId, ProcessType, EventType, EventDate, EventNote                  , EventUser   , EventUserName)
		VALUES  (@RevisionId, 1          , 0        , GETDATE(), 'Signed Out From CDMSuite' , @eventUserID, @eventUserFullName),
				(@RevisionId, 1          , 1        , GETDATE(), 'Signed Out From CDMSuite' , @eventUserID, @eventUserFullName)

---------------------------------
-- Insert rows into ADNRefs
---------------------------------
		exec CSP_CDMSUITE_AddAdnRefs @adnDrawingId = @DrawingID, @drawingNodeId = @DrawingID
		COMMIT
---------------------------------
-- If this drawing exsits in the LM_Lifecycles table, return it's current state.
---------------------------------
		DECLARE @priorStateId INT
		DECLARE @stateId INT
		SELECT 
			@priorStateId = ISNULL(StateId,-1)
		FROM LM_Lifecycles WHERE DataID = @p_ProjectNodeId

		SELECT 
			@stateId = dl.StartingState
		FROM CRT_PROJECT p
		JOIN LM_Def_Lifecycles dl ON p.DEFPROCESSFLOW = dl.LifecycleID
		WHERE
			PROJECT = @p_Project

		SELECT 
			isnull(@priorStateId,1) PriorStateId,
			@stateId StateId

---------------------------------
-- Insert object into the c_CDM_DRAWING table.
---------------------------------
		DECLARE 
			@verNum int,
			@modifyDate datetime,
			@name nvarchar(255)
			
		SELECT
			@verNum = d.VersionNum,
			@modifyDate = d.ModifyDate,
			@name = d.Name
		FROM DTree d
		WHERE
			d.DataID = @p_ProjectNodeId
		
		exec c_sp_CDM_ExtractDrawingAttrData @DataID = @p_ProjectNodeId, @VersionNum = @verNum, @ModifyDate = @modifyDate, @Name = @name, @Deleted = 0		

	END

END




GO
