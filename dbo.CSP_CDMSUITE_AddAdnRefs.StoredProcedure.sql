
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_AddAdnRefs]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Adds a new row to the AdnRefs Table upon drawing creation, or sign out 
-- if an adnreference does not currently exist. 
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_AddAdnRefs]
	@adnDrawingId bigint,
	@drawingNodeId bigint
AS
BEGIN

DECLARE 
	@existsinRefs int
	
	set @existsinRefs= (select count(*) from AdnRefs where ADNID=@adnDrawingId and key1=@drawingNodeId)
	-- if it does not exist in adnRefs already , add it 
	IF (@existsinRefs=0)
	BEGIN
		insert into AdnRefs (ADNID, RefType, Key1, Key2) 
					values (@adnDrawingId, 1, @drawingNodeId, 1)
	END
END



GO
