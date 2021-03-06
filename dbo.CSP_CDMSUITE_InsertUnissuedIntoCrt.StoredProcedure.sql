/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_InsertUnissuedIntoCrt]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================= 
-- Author:	 Antoine Ibrahim 
-- Description: Will insert a single revision into the CRT Vault 
-- ============================================= 
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_InsertUnissuedIntoCrt]  
    
	@adnDrawingNumber NVARCHAR(255),
	@vaultDocId BIGINT,
    @vaultFolderId BIGINT,
	@projectDocId BIGINT,
	@projectFolderId BIGINT,
	@projectName NVARCHAR(250),
	@assignerId BIGINT,
	@assignerName NVARCHAR(250),
	@assignerFullName NVARCHAR(250)

AS 
BEGIN 
    SET NOCOUNT ON; 

    ----------------------------------------------------------------------------------------------------------- 
    -- Get values that are needed to insert into the vault. 
    ----------------------------------------------------------------------------------------------------------- 
    
    DECLARE @adnOu INT = 2;
	DECLARE @revId INT = NULL; 
	DECLARE @adnDrawingId BIGINT; 

	SELECT @adnDrawingId = ADNID FROM AdnIDs WHERE WholeID = @adnDrawingNumber;
    ----------------------------------------------------------------------------------------------------------- 
    -- Insert the inital revision into CRT. This will be the revision for the placeholder vault node
    ----------------------------------------------------------------------------------------------------------- 
   BEGIN TRANSACTION
    BEGIN TRY  

		-- Put the inital rev into the CRT_REVISION table
		INSERT INTO crt_revision (  DrawingID   , RevisionNumber , RevisionLabel, RevisionType, RevisionStatus,  
							LLObjID    , LLVerId       , R1S, R2S, R1I , R2I ,  PROJECTID    , PROJECT    , LLProjectObjID) 
						  VALUES ( @adnDrawingId, 0              , '-'          , 1           , 1             ,  
						  @vaultDocId, 1             , '' , '' , 0   , 1   , @vaultFolderId, 'CRTVAULT2', @vaultDocId); 
 
 	
		----------- 
		-- Get the revision id for the last insert. 	
		SELECT @revId = MAX(revisionid) FROM CRT_REVISION WHERE DrawingID = @adnDrawingId; 
 
		IF ((@revId < 1) OR (@revId IS NULL)) 
		BEGIN 
			SELECT 'Could not find revision id for initial CRT_REVISION insert of drawing id ' + CAST(@adnDrawingId AS NVARCHAR(100)) AS ERROR; 
		  
			RETURN; 
		END; 
		-- insert entry in the event table for the new document 
		INSERT INTO CRT_EVENT  
			   (  RevisionId, ProcessType, EventType,  EventDate , EventNote     ,  EventUser     ,  EventUserName) 
		VALUES ( @revId     , 0          , 0        , SYSDATETIME(), 'New Document', @assignerId, @assignerFullName), 	 
			   ( @revId     , 0          , 1        , SYSDATETIME(), ''            , @assignerId, @assignerName);  	  
			
	END TRY 

    BEGIN CATCH	  
	   SELECT 'There was an error importing inital revision ' + CAST(@vaultDocId AS NVARCHAR(20)) + ' into CRT. Error #: ' + CAST(ERROR_NUMBER() AS NVARCHAR(100)) + ' - ' + ERROR_MESSAGE() AS ERROR; 	   	  
	   ROLLBACK
	   RETURN
	END CATCH; 
    ----------------------------------------------------------------------------------------------------------- 
    -- Insert the signed out revision into CRT. (active Revision)
    ----------------------------------------------------------------------------------------------------------- 
	BEGIN TRY  
		-- Put the signed out rev into the CRT_REVISION table
		INSERT INTO crt_revision (  DrawingID   , RevisionNumber , RevisionLabel, RevisionType, RevisionStatus,  
							LLObjID      , LLVerId       , R1S, R2S, R1I , R2I ,  PROJECTID		 , PROJECT    , LLProjectObjID) 
						  VALUES ( @adnDrawingId, 1              , 0            , 2           , 2             ,  
						  @projectDocId, 1             , '' , '' , 0   , 1   , @projectFolderId ,  @projectName, @projectDocId); 
 
 	
		----------- 
		-- Get the revision id for the last insert. 	
		SELECT @revId = MAX(revisionid) FROM CRT_REVISION WHERE DrawingID = @adnDrawingId; 
 
		IF ((@revId < 1) OR (@revId IS NULL)) 
		BEGIN 
			SELECT 'Could not find revision id for signed out CRT_REVISION insert of drawing id ' + CAST(@adnDrawingId AS NVARCHAR(100)) AS ERROR; 
		  
			RETURN; 
		END; 

		INSERT INTO CRT_EVENT  
			   (  RevisionId, ProcessType, EventType,  EventDate , EventNote     ,  EventUser    , EventUserName) 
		VALUES ( @revId     , 0          , 0        , SYSDATETIME(), 'New Revision', @assignerId, @assignerFullName),	 
			   ( @revId     , 0          , 1        , SYSDATETIME(), ''            , @assignerId, @assignerName);	  

	    

 
    END TRY

    BEGIN CATCH	  
	   SELECT 'There was an error importing signed out revision ' + CAST(@vaultDocId AS NVARCHAR(20)) + ' into CRT. Error #: ' + CAST(ERROR_NUMBER() AS NVARCHAR(100)) + ' - ' + ERROR_MESSAGE() AS ERROR; 	   	  
	   ROLLBACK
	   RETURN
    END CATCH; 

	--CREATE AN ENTRY IN THE LIFECYCLE TABLE TO ASSIGN A PROCESS FLOW
	BEGIN TRY

		DECLARE @stateId BIGINT
		SELECT 
			@stateId = dl.StartingState
		FROM CRT_PROJECT p
		JOIN LM_Def_Lifecycles dl ON p.DEFPROCESSFLOW = dl.LifecycleID
		WHERE
			PROJECT = @projectName

		INSERT INTO [dbo].[LM_Lifecycles]
				   ([DataID]
				   ,[StateID]
				   ,[InTransition]
				   ,[NextState]
				   ,[ApproveByDate]
				   ,[TransitionByDate]
				   ,[PriorStateID]
				   ,[OptionalNextStateApprovers]
				   ,[R1I]
				   ,[R1S])
			 VALUES
				   (@projectDocId
				   ,@stateId
				   ,0
				   ,-1
				   ,NULL
				   ,NULL
				   ,-1
				   ,NULL
				   ,NULL
				   ,NULL);
	END TRY

	BEGIN CATCH
	   SELECT 'There was an error inserting row into LM_Lifecycles ' + CAST(@projectDocId AS NVARCHAR(20)) + '. Error #: ' + CAST(ERROR_NUMBER() AS NVARCHAR(100)) + ' - ' + ERROR_MESSAGE() AS ERROR; 	   	  
	   ROLLBACK
	   RETURN
	END CATCH;
	COMMIT
END

GO
