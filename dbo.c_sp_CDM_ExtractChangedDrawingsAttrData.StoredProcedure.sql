/****** Object:  StoredProcedure [dbo].[c_sp_CDM_ExtractChangedDrawingsAttrData]    Script Date: 11/1/2017 4:03:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Extract CDM Drawing data from the LLAtttData table into a normalized table structure
--		for the latest/new drawings or drawings that have recently changed - since last run
-- Input: None 
-- Assumptions: None 
-- Result: New/changed drawings Data for the CDM Drawing Information and CDM Revisions categories is extracted and stored
--		into the tables: C_CDM_DRAWING, C_CDM_DrawingAcctNum, C_CDM_Revision, C_CDM_RevisionAcctNum, C_CDM_DrawingFacility.
-- =============================================
CREATE PROCEDURE [dbo].[c_sp_CDM_ExtractChangedDrawingsAttrData]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
	SET NOCOUNT ON;

	--ensure that we have a row in the kini table containing the last run date/time
	if not exists (select * from kini where IniSection = 'SCEDrawingManagement' and IniKeyword = 'LastDwgInfoExtractTime')
	BEGIN
		insert into Kini(IniSection, IniKeyword, IniValue)
			values ('SCEDrawingManagement', 'LastDwgInfoExtractTime', DATEADD(DAY, -1, getdate()))
	END

	--get and preserve the nowTime before we start, to be used later
	declare @nowTime datetime
	set @nowTime = GETDATE()

	--get the fromTime from the Kini table
	declare @fromTime datetime
	select @fromTime = cast(IniValue as datetime) from Kini where IniSection = 'SCEDrawingManagement' and IniKeyword = 'LastDwgInfoExtractTime'
	
	--Get Vault DataID and Projects Folder Data ID
	declare @VaultID int, @ProjFolderID int
	select @VaultID = VaultLocation, @ProjFolderID = DefProjectLoc from CRT_VAULT_SETTING where OUID = 2

	create table #Drawings
	  (
		DataID int,
		VersionNum int,
		ModifyDate datetime,
		Name nvarchar(248)
	  )

	declare @sql nvarchar(max)
	set @sql = 'insert into #Drawings(DataID, VersionNum, ModifyDate, Name) '
				+ ' select distinct '
				+ ' d.dataid, d.VersionNum, d.ModifyDate, d.Name '
				+ ' from dtree d '
				+ ' join dtree p on d.ParentID = p.DataID '
				+ ' join dtree gp on p.ParentID = gp.DataID '
				+ ' join DAuditNew au on au.DataID = d.DataID '
				+ ' where '
				+ ' (gp.ParentID = ' + cast(@ProjFolderID as nvarchar) + ' or p.DataID = ' + cast(@VaultID as nvarchar) + ') '
				+ '	and au.AuditStr >= ''AttrChange'' '
				+ '	and au.AuditDate >= ''' + cast(@fromTime as nvarchar) + ''''

	exec (@sql)

	declare
		@p_ProjectNodeId bigint,
		@verNum int,
		@modifyDate datetime,
		@name nvarchar(248)

	declare cur CURSOR LOCAL for
		select DataID, VersionNum, ModifyDate, Name
			from #Drawings
			order by DataID

	open cur
 
	fetch next from cur into @p_ProjectNodeId, @verNum, @modifyDate, @name
 
	while @@FETCH_STATUS = 0 BEGIN
		--print cast(@p_ProjectNodeId as varchar) + ' - ' + cast(@name as varchar) + ' - ' + cast(@verNum as varchar) + ' - ' + cast(@modifyDate as varchar) 
		exec c_sp_CDM_ExtractDrawingAttrData @DataID = @p_ProjectNodeId, @VersionNum = @verNum, @ModifyDate = @modifyDate, @Name = @name, @Deleted = 0
		fetch next from cur into @p_ProjectNodeId, @verNum, @modifyDate, @name
	END
 
	close cur
	deallocate cur

	drop table #Drawings

	--after successful extraction, save the nowTime in the Kini table, for the next run - subtract x minutes to provide a little just-in-case buffer
	update KIni set IniValue = DATEADD(mi, -3, @nowTime) where IniSection = 'SCEDrawingManagement' and IniKeyword = 'LastDwgInfoExtractTime'
END

GO
