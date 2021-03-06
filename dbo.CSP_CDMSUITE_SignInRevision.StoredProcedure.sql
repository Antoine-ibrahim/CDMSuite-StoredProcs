/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_SignInRevision]    Script Date: 11/1/2017 4:03:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CSP_CDMSUITE_SignInRevision]
	@Nodeid BIGINT,			
	@Vaultid BIGINT,		
	@UserName NVARCHAR(255), 
    @eventProcess INT		
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON
	DECLARE @HasCurrentOrInitialRev INT
	DECLARE @HasActiveRev INT
	DECLARE @eventUserId BIGINT
	DECLARE @EventUserFullName NVARCHAR(255)	
	DECLARE @revisionID BIGINT
	DECLARE @LlVersion INT
	DECLARE @DrawingID BIGINT

	SET @DrawingID=(SELECT DISTINCT DrawingID FROM CRT_REVISION WHERE LLObjID=@Vaultid)

	SET @HasCurrentOrInitialRev=(SELECT COUNT(1) FROM CRT_REVISION rev
               WHERE DrawingID=@DrawingID
                AND rev.RevisionStatus IN (3,1))
				
	 SET @HasActiveRev=( SELECT COUNT(1) FROM CRT_REVISION rev
                WHERE DrawingID=@DrawingID
                AND rev.RevisionStatus IN (2))

	  SET @eventUserId = (SELECT id FROM KUAF WHERE name=@UserName)

	 SET @EventUserFullName =(SELECT 
                    CASE WHEN MiddleName!='NULL' THEN FirstName+' ' +MiddleName+'. '+ LastName
                         ELSE FirstName+' '+LastName END AS Name 
                    FROM KUAF
                    WHERE name = @UserName)

	 SET @LlVersion = (SELECT VersionNum FROM dtree WHERE DataID=@Vaultid)

IF (@HasCurrentOrInitialRev>0 AND @HasActiveRev>0)
BEGIN
	BEGIN TRANSACTION
		UPDATE  rev
                SET RevisionStatus= CASE WHEN RevisionStatus=3 THEN 5 WHEN RevisionStatus=1 THEN 5 ELSE 3 END,
                 llobjid = @Vaultid,
				 LLVerID =@LlVersion
                FROM CRT_REVISION rev
                WHERE drawingid=@DrawingID
                AND rev.revisionstatus IN (3,1,2)
		
		SET @revisionID=(SELECT DISTINCT rev.RevisionID [RevisionID] FROM CRT_REVISION rev 
                WHERE rev.LLObjID =@Vaultid
                AND rev.RevisionStatus=3)

				INSERT INTO CRT_EVENT
				      (revisionid, ProcessType,EventType, EventDate,EventNote,EventUser,EventUserName)
				VALUES(@revisionID,@eventProcess,0, GETDATE(), 'Signed In From CDMSuite',@eventUserId, @EventUserFullName),
					  (@revisionID,@eventProcess,1, GETDATE(), 'Signed In From CDMSuite',@eventUserId, @EventUserFullName)
	COMMIT
END

END




GO
