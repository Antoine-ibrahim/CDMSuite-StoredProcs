
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_CancelRevisions]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will cancel a drawing revision. 
-- =============================================

CREATE PROCEDURE [dbo].[CSP_CDMSUITE_CancelRevisions]
	-- Add the parameters for the stored procedure here
	@DataIdList  NVARCHAR(max),
    @UserId NVARCHAR(255)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
DECLARE 
	@userFullName NVARCHAR(255) = '',
	@HasActiveRev INT,
	@DrawingId BIGINT, -- this is the adnid also 
	@VaultId BIGINT,
	@ActiveRevisionID BIGINT,
	@EventUserID BIGINT,
	@NextDataid Nvarchar(255),
	@DataId bigint

	set @DataIdList =@DataIdList +',';
	WHILE @DataIdList !=''
	begin
		SELECT @NextDataid	= SUBSTRING(@DataIdList, 0, CHARINDEX(',', @DataIdList));
		SELECT @DataIdList= SUBSTRING(@DataIdList, CHARINDEX(',', @DataIdList)+1, LEN(@DataIdList));
		SET @DataId = CAST(@NextDataid AS BIGINT);

		set @VaultId=(select dataid from dtree d 
							join adnrefs a on d.dataid = a.key1 and d.parentid = (select PROJECTID from CRT_PROJECT where project ='CRTVAULT2')  
							where
							a.ADNID = (select distinct drawingid from crt_Revision where LLObjID = @DataId))

		SET @DrawingId=(SELECT DISTINCT DrawingID FROM CRT_REVISION WHERE LLObjID=@VaultId)
		SELECT @EventUserID = id, 
			   @userFullName=ISNULL(FirstName+' ','')+ ISNULL(lastname,'')
		FROM KUAF where name=@UserId

		SET @HasActiveRev=( SELECT COUNT(1) FROM CRT_REVISION rev
					WHERE DrawingID=@DrawingId
					AND rev.RevisionStatus IN (2))

		set @ActiveRevisionID= (select RevisionID from CRT_REVISION where DrawingID = @DrawingId and RevisionStatus=2)

		if (@HasActiveRev >0)
		begin
			print 'need to insert into revisions table RevisionStatus =4 where DrawingID =' +CAST(@DrawingId AS nvarchar(30))+' and RevisionStatus=2'
			update CRT_REVISION set RevisionStatus =4 where DrawingID = @DrawingId and RevisionStatus=2
			
			print 'need to insert into Events table revid:'+CAST(@ActiveRevisionID AS nvarchar(30))+',3,0, '+CAST(GETDATE() AS nvarchar(30))+', '+ CAST(@EventUserID AS nvarchar(30))+', '+ @userFullName
			insert into CRT_EVENT (revisionid, ProcessType, EventType, EventDate, EventNote, EventUser, EventUserName)
			values(@ActiveRevisionID,3,0,GETDATE(), '', @EventUserID, @userFullName),
				  (@ActiveRevisionID,3,1,GETDATE(), '', @EventUserID, @userFullName)
		end
	end
END


GO
