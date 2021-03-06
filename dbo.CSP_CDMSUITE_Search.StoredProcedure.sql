/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_Search]    Script Date: 11/1/2017 4:03:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	This stored procedure is used for searching the CDM Suite
-- =============================================
ALTER PROCEDURE [dbo].[CSP_CDMSUITE_Search]
	@p_Ouid BIGINT = 2,
	@p_IsDashboardQuery INT = 1,
	@p_IsVaultQuery INT = 1,		
	@p_DrawingNumber NVARCHAR(MAX) = NULL,
	@p_DrawingNumber_Start NVARCHAR(MAX) = NULL,
	@p_DrawingNumber_End NVARCHAR(MAX) = NULL,
	@p_DataIdScope NVARCHAR(MAX) = NULL,
	@p_DrawingTitle NVARCHAR(MAX) = NULL,
	@p_Facility NVARCHAR(MAX) = NULL,
	@p_Facility_MatchesNeeded INT = 1,
	@p_SheetNumber NVARCHAR(MAX) = NULL,
	@p_SectionNumber NVARCHAR(MAX) = NULL,
	@p_Supplier NVARCHAR(MAX) = NULL,
	@p_IssuePackage NVARCHAR(MAX) = NULL,
	@p_RevAccountingNumber NVARCHAR(MAX) = NULL,
	@p_Discipline NVARCHAR(MAX) = NULL,
	@p_DrawingType NVARCHAR(MAX) = NULL,
	@p_OriginalStoredAt NVARCHAR(MAX) = NULL,
	@p_Medium NVARCHAR(MAX) = NULL,
	@p_ProjectString NVARCHAR(MAX) = NULL,
	@p_RevisionType NVARCHAR(MAX) = NULL,
	@p_OwnedByUser BIT = FALSE,
	@p_HoldDate_Start NVARCHAR(20) = NULL,
	@p_HoldDate_End NVARCHAR(20) = NULL,
	@p_ModifiedDate_Start NVARCHAR(20) = NULL,
	@p_ModifiedDate_End NVARCHAR(20) = NULL,
	@p_IssuedDate_Start NVARCHAR(20) = NULL,
	@p_IssuedDate_End NVARCHAR(20) = NULL,	
	@p_UserName NVARCHAR(255) = NULL,
	@p_UserId BIGINT = NULL,
	
	
	-- Control how many results we get and where the results start.
	@p_NumResultsToRetrieve BIGINT = 25,
	@p_Offset INT = 0,

	-- Ordering
	@p_OrderBy NVARCHAR(255) = "drawingnumber",
	@p_OrderDirection NVARCHAR(5) = "asc"

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   --SET TRANSACTION ISOLATION LEVEL SNAPSHOT
	
	DECLARE 
		@CatID NVARCHAR(20),
		@AttrID NVARCHAR(20),
		@CatName NVARCHAR(248),
		@AttrName NVARCHAR(248),
		@AttrVal1 NVARCHAR(MAX),
		@AttrVal2 NVARCHAR(MAX),
		@DelimiterPos INT,
		@xml XML,
		@JoinClause NVARCHAR(MAX),
		@sql NVARCHAR(MAX),
		@VaultID BIGINT,
		@CrtUser INT = 0, 
		@AdminUser INT = 0,
		@UserSuppMarks NVARCHAR(MAX) = '';
		
----------------------------------------------------
-- User security info.
----------------------------------------------------		
	-- Get the user ID if they didn't provide one.
	IF ((@p_UserId IS NULL) AND (@p_UserName IS NOT NULL))
	BEGIN
		SELECT @p_UserId = ID FROM kuaf WHERE name = @p_UserName;
	END;

	--determine if user has admin privilidges
	SET @AdminUser = CASE 
		WHEN (SELECT UserPrivileges FROM Kuaf WHERE ID = @p_UserId) IN (271, 287, 303, 319, 335, 351, 367, 383, 2431, 16777215) THEN 1
		ELSE 0
	END;
	
	--determine if user belongs to one of the CDM groups
	IF (@AdminUser = 0) BEGIN --not admin

		SELECT @CrtUser = COUNT(1) 
			FROM Kuaf u
			INNER JOIN KUAFChildren kc1 ON kc1.ChildID = u.ID
			INNER JOIN kuaf g1 ON g1.ID = kc1.ID AND g1.TYPE = 1 AND g1.Deleted = 0
			LEFT OUTER JOIN KUAFChildren kc2 ON kc2.ChildID = g1.ID
			LEFT OUTER JOIN kuaf g2 ON g2.ID = kc2.ID AND g2.TYPE = 1 AND g2.Deleted = 0
			LEFT OUTER JOIN KUAFChildren kc3 ON kc3.ChildID = g2.ID
			LEFT OUTER JOIN kuaf g3 ON g3.ID = kc3.ID AND g3.TYPE = 1 AND g3.Deleted = 0
			LEFT OUTER JOIN KUAFChildren kc4 ON kc4.ChildID = g3.ID
			LEFT OUTER JOIN kuaf g4 ON g4.ID = kc4.ID AND g4.TYPE = 1 AND g4.Deleted = 0
			WHERE u.ID = @p_UserId
			and (
					(g1.Name = 'SCE-E&C-CDM-RD' or g2.Name = 'SCE-E&C-CDM-RD' or g3.Name = 'SCE-E&C-CDM-RD') or 
					(g1.Name = 'SCE-E&C-CDM-AU' or g2.Name = 'SCE-E&C-CDM-AU' or g3.Name = 'SCE-E&C-CDM-AU') or
					(g1.Name = 'SCE-E&C-CDM-CM' or g2.Name = 'SCE-E&C-CDM-CM' or g3.Name = 'SCE-E&C-CDM-CM') or
					(g1.Name = 'SCE-E&C-CDM-ENGINEER' or g2.Name = 'SCE-E&C-CDM-ENGINEER' or g3.Name = 'SCE-E&C-CDM-ENGINEER')
				  )
	END;

	--get the a signature string of all the users's supplemental markings
	SELECT @UserSuppMarks = @UserSuppMarks + '~' + SuppMark 
		FROM RMSec_UserSuppMarks 
		WHERE 
			UserID = @p_UserId
		ORDER BY SuppMark;
	SET @UserSuppMarks = @UserSuppMarks + '~';

	--print 'AdminUser: ' + cast(@AdminUser as varchar(10))
	--print 'CrtUser: ' + cast(@CrtUser as varchar(10))
	--print 'p_isvaultquery: ' + cast(@p_IsVaultQuery as varchar(10))

----------------------------------------------------
-- Select statement.
----------------------------------------------------	
	--build the select part of the select statement
	SET @sql = 'SELECT DISTINCT '
		+ '  CASE WHEN (' + CAST(@p_IsVaultQuery AS NVARCHAR(20)) + '=1 AND EXISTS (SELECT * FROM CRT_REVISION r1 WHERE r1.DrawingID = r.DrawingID AND r1.RevisionStatus=2 AND r1.RevisionNumber > r.RevisionNumber)) THEN 1 ELSE 0 END AS HasActiveOut '
		+ ' ,d.DataId AS NodeId '
		+ ' ,AdnIDs.WholeID as Name'
		+ ' ,REPLACE(AdnIDs.WholeID, ISNULL(RTRIM(SUFFIX), ''''), '''') as DrawingNumber'
		--+ ' ,AdnIDs.Prefix + CONVERT(nvarchar(100), (CASE WHEN AdnIDs.SeqID != 0 THEN AdnIDs.SeqID ELSE '''' END)) as DrawingNumber'
		+ ' ,dwg.Section as SectionNumber'
		+ ' ,dwg.Sheet as SheetNumber'
		+ ' , RIGHT(''0000000000''+ISNULL(case when dwg.Sheet not like ''%[a-Z]%'' then dwg.Sheet + ''.'' else dwg.Sheet end,''''),10) SheetNumberSort  '
		+ ' ,r.RevisionNumber as RevisionNumber '
		+ ' ,r.RevisionLabel as RevisionLabel '
		+ ' ,d.DComment as DrawingTitle '
		+ ' ,d.ModifyDate as ModifiedDate '
		+ ' ,r.Project as Project '
		+ ' ,isnull((SELECT '
		+' 				facDisp.Facility + ''; '' AS [data()] '
		+'			FROM C_CDM_DrawingFacility facDisp '
		+'			WHERE '
		+' 				facDisp.dataid = d.DataID '
		+'			FOR xml path('''')), '''') as Facilities '
		+' ,STUFF((SELECT '
		+'						''; '' + SM.SuppMark '
		+'					FROM RMSec_DocSuppMark SM WITH (NOLOCK) '
		+'					WHERE '
		+'						SM.DataID = d.DataID '
		+'					FOR XML PATH('''') '
		+'				),1,1,'''' '
		+'			) '
		+' 		AS SecurityClearance '
		+' ,dwg.DisciplineType as Discipline '
		+' ,cr.IssuedDate as IssuedDate '
		+' ,r.LLObjID AS OTObject '
		+' , ISNULL(reqname.FirstName + '' '' + reqname.LastName, e2a.EventUserName) as RequestedBy '		
		+' ,CASE WHEN d.Reserved = 0 THEN 0 ELSE 1 END AS Reserved ' 
		+' ,ISNULL(reservedby.FirstName + '' '' + reservedby.LastName, '''') as ReservedBy '
		+' ,ISNULL(lmdefstates.Name, '''') as State '
			  
	SET @sql += 'into #tempResults FROM AdnIDs ';

----------------------------------------------------
-- Joins.
----------------------------------------------------
	--join to any tables which are required either required to get the results, or needed to for fullfill a parameter/filter
	SET @sql += ' INNER JOIN CRT_REVISION r ON r.DrawingID = AdnIDs.ADNID ';		
	
	IF (@p_RevisionType IS NOT NULL) BEGIN
		
		DECLARE @revisionTypeId BIGINT;
		SELECT @revisionTypeId = ISNULL(revtypeid,-1) FROM CRT_REVISION_TYPE_map WHERE OUID = @p_Ouid AND DISPLAY_TYPE_NAME = @p_RevisionType;
		SET @sql += ' AND r.RevisionType = ' +  CAST(@revisionTypeId AS NVARCHAR(20)) + ' ';	
	END;	
	
	IF (@p_IsVaultQuery=1) BEGIN
		SET @sql += ' AND (r.RevisionStatus = 1 OR r.RevisionStatus =3) ';
		SET @sql += ' INNER JOIN C_CDM_Drawing dwg on r.LLObjID = dwg.DataID ';
	END;	
	ELSE BEGIN --@p_IsVaultQuery=0
		SET @sql += ' AND r.RevisionStatus = 2 ';
		SET @sql += ' INNER JOIN C_CDM_Drawing dwg on r.LLObjID = dwg.DataID ';
	END;

	IF (@p_RevAccountingNumber IS NOT NULL) 
	BEGIN
		SET @sql += ' LEFT JOIN C_CDM_RevisionAcctNum ra ON r.LLObjId = ra.DataId ';
	END;

	SET @sql += ' LEFT JOIN C_CDM_REVISION cr ON r.LLObjId = cr.DataId and r.RevisionLabel = cr.RevNum ';	
	SET @sql += ' INNER JOIN AdnTypes ON AdnIDs.AdnTypeId = AdnTypes.AdnTypeId ';

	SET @sql += ' AND AdnTypes.OrgUnitId = ' + CAST(@p_Ouid AS NVARCHAR(20)) + ' ';

	--Don't filter on ADN Type (Document Type in CRT) since all drawings are of the same time, and this could cause a table scan
	--IF (@p_adntypeid IS NOT NULL) BEGIN
	--	set @sql += ' AND AdnIDs.AdnTypeId = ' + cast(@p_adntypeid as nvarchar(20)) + ' '
	--END

	SET @sql += ' INNER JOIN CRT_PROJECT p ON r.PROJECTID = p.PROJECTID ';
	SET @sql += '	AND p.STATUS = 1 ';
	SET @sql += '	AND p.OUID = ' + CAST(@p_Ouid AS NVARCHAR(20)) + ' ';
	SET @sql += ' INNER JOIN DTree d ON r.LLObjID = d.DataID '; --and OwnerID = -2000 ' --and d.SubType = 144 '

	IF (@p_IsVaultQuery=1) BEGIN
		SELECT @VaultID = VAULTLOCATION FROM CRT_VAULT_SETTING WHERE OUID = CAST(@p_Ouid AS NVARCHAR(20));
		SET @sql += ' AND d.ParentID = ' + CAST(@VaultID AS NVARCHAR(20)) + ' '; 
	END;


	-- Revision information tables
	SET @sql += ' LEFT OUTER JOIN CRT_REVISION_TYPE_MAP rt ON r.RevisionType = rt.REVTYPEID ';
	SET @sql += '	AND rt.OUID = ' + CAST(@p_Ouid AS NVARCHAR(20)) + ' ';
	SET @sql += ' LEFT OUTER JOIN CRT_REVISION_STATUS_MAP rs ON r.RevisionStatus = rs.REVSTATUSID ';
	SET @sql += '	AND rs.OUID = ' + CAST(@p_Ouid AS NVARCHAR(20)) + ' ';
	SET @sql += ' LEFT OUTER JOIN CRT_EVENT e2 ON r.RevisionID = e2.RevisionID ';
	SET @sql += ' LEFT OUTER JOIN CRT_EVENT e2a ON r.RevisionID = e2a.RevisionID AND e2a.EventID > e2.EventID AND e2a.EventType = 1 ';
	SET @sql += ' LEFT OUTER JOIN KUAF reqname ON e2a.EventUser = reqname.ID ';
    SET @sql += ' LEFT OUTER JOIN KUAF reservedby ON d.ReservedBy = reservedby.id ';	
	
	-- Current processing state
	SET @sql += ' LEFT OUTER JOIN LM_Lifecycles lmlifecycle on d.dataid = lmlifecycle.dataid '
	SET @sql += ' LEFT OUTER JOIN LM_Def_States lmdefstates on lmlifecycle.StateID = lmdefstates.StateID'																			 

	IF (@p_Facility IS NOT NULL)
	BEGIN	
		
		SET @sql += ' inner join C_CDM_DrawingFacility fac on d.dataid = fac.DataID and ( ';
		SET @sql += '	select ';
		SET @sql += '		count(1) ';
		SET @sql += '	from C_CDM_DrawingFacility ';
		SET @sql += '	where ';
		SET @sql += '			dataid = d.DataID ';
		SET @sql += '		and Facility in (' + @p_Facility +')) >= ' + CONVERT(NVARCHAR(5),@p_Facility_MatchesNeeded);
	END;
		
----------------------------------------------------
-- Where clauses.
----------------------------------------------------	
	--If not a CRT user (not a memeber of a CDM/Engineer group) and not an Admin then short-cricuit the query and return 0 rows here
	IF (@CrtUser = 0 AND @AdminUser = 0) BEGIN
		--print 'short-cricuit'
		SET @sql += ' where 1 = 0 ';
		--print @sql;
		EXECUTE (@sql);
		RETURN;
	END;

	SET @sql += ' where e2.EventID = (SELECT MAX(EventID) FROM CRT_EVENT WHERE RevisionID = r.RevisionID AND EventType = 0) ';
		
	-- Modified dates.
	IF (@p_ModifiedDate_Start IS NOT NULL) BEGIN
		SET	@sql += ' AND cast(d.ModifyDate as date) >= ''' + @p_ModifiedDate_Start + ''' ';
	END;
	IF (@p_ModifiedDate_End IS NOT NULL) BEGIN
		SET	@sql += ' AND cast(d.ModifyDate as date) <= ''' + @p_ModifiedDate_End + ''' ';
	END;

	-- Issued dates.
	IF (@p_IssuedDate_Start IS NOT NULL) BEGIN
		SET	@sql += ' AND cast(cr.IssuedDate as date) >= ''' + @p_IssuedDate_Start + ''' ';
	END;
	IF (@p_IssuedDate_End IS NOT NULL) BEGIN
		SET	@sql += ' AND cast(cr.IssuedDate as date) <= ''' + @p_IssuedDate_End + ''' ';
	END;

		
	IF ((@p_OwnedByUser = 1) AND (@p_IsVaultQuery = 0))  BEGIN
		SET @sql += ' and e2.EventUser = ' + CAST(@p_UserId AS NVARCHAR(20)) + ' ';
	END;

	IF (@p_ProjectString IS NOT NULL) BEGIN
		SET @p_ProjectString = REPLACE(@p_ProjectString, ',', ''',''');
		SET @sql += ' and p.PROJECT IN (''' + @p_ProjectString + ''') ';
	END;

	-----------------------------------
	-- Drawing number processing start.
	-----------------------------------
	IF (@p_DrawingNumber IS NOT NULL) BEGIN
		IF CHARINDEX(',', @p_DrawingNumber, 0) = 0 BEGIN
			IF	CHARINDEX('*', @p_DrawingNumber, 0) = 0 AND
				CHARINDEX('?', @p_DrawingNumber, 0) = 0
			BEGIN
				--If the user did not specify any wild card, use the default like behavior, so append a %
				SET @p_DrawingNumber += '%';
			END;
			ELSE BEGIN
				--If the user specified * or ? convert it to the appropriate like character in SQL
				IF CHARINDEX('*', @p_DrawingNumber, 0) > 0 BEGIN
					SET @p_DrawingNumber = REPLACE(@p_DrawingNumber, '*', '%');
				END;
				IF CHARINDEX('?', @p_DrawingNumber, 0) > 0 BEGIN
					SET @p_DrawingNumber = REPLACE(@p_DrawingNumber, '?', '_');
				END;
			END;
			SET	@sql += ' AND ADNIDs.WholeID like ''' + @p_DrawingNumber + ''' ';
		END;
		ELSE BEGIN
			--the user supplied a comma-delimited list of drawing numbers
			--we have to parse it and seach for individual values, allowing for wild characters
			--We assume the user will use * for any combination of characters and ? for any single character
			--print @p_DrawingNumber

			IF RIGHT(@p_DrawingNumber, 1) = ',' BEGIN
				SET @p_DrawingNumber = LEFT(@p_DrawingNumber, LEN(@p_DrawingNumber) - 1);
			END;

			SET @p_DrawingNumber = REPLACE(@p_DrawingNumber, '%', '');
			SET @p_DrawingNumber = REPLACE(@p_DrawingNumber, '&', '&amp;');
			SET @xml = N'<root><r>' + REPLACE(@p_DrawingNumber,',','</r><r>') + '</r></root>'; 

			--Use a cursor to iterate through the parsed attribute filters and build up a join clause for each
			DECLARE attr_cursor CURSOR FOR
				SELECT	RTRIM(LTRIM(val))
					FROM (SELECT r.value('.','nvarchar(max)') AS [val]
						FROM @xml.nodes('//root/r') AS records(r)) AS [xml];

			OPEN attr_cursor;

			DECLARE @FirstEntry BIT = 1;
			FETCH NEXT FROM attr_cursor INTO @AttrVal1;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				--print @AttrVal1
				SET @AttrVal1 = REPLACE(@AttrVal1, '*', '%');
				SET @AttrVal1 = REPLACE(@AttrVal1, '?', '_');

				IF @AttrVal1 <> '' BEGIN
					--print @AttrVal1
					IF @FirstEntry = 1 BEGIN
						SET	@sql += ' AND (ADNIDs.WholeID like ';
						SET @FirstEntry = 0;
					END;
					ELSE BEGIN
						SET	@sql += ' OR ADNIDs.WholeID like ';
					END;
					SET	@sql += '''' + @AttrVal1 + ''' ';
				END;
				FETCH NEXT FROM attr_cursor INTO @AttrVal1;
			END;
			IF @FirstEntry = 0 BEGIN
				SET @sql += ') ';
			END;

			CLOSE attr_cursor;
			DEALLOCATE attr_cursor;
		END;
	END;

	IF (@p_DrawingNumber_Start IS NOT NULL) BEGIN
		SET @sql += ' and ';
		SET @sql += ' case charindex('' '', ADNIDs.WholeID) ';
		SET @sql += ' when 0 then ';
		SET @sql += ' 	AdnIDs.WholeID ';
		SET @sql += ' else ';
		SET @sql += ' 	substring(ADNIDs.WholeId,0,charindex('' '', ADNIDs.WholeID)) ';
		SET @sql += ' end  >= ''' + @p_DrawingNumber_Start + ''' ';
	END;
	
	IF (@p_DrawingNumber_End IS NOT NULL) BEGIN
			SET @sql += ' and ';
		SET @sql += ' case charindex('' '', ADNIDs.WholeID) ';
		SET @sql += ' when 0 then ';
		SET @sql += ' 	AdnIDs.WholeID ';
		SET @sql += ' else ';
		SET @sql += ' 	substring(ADNIDs.WholeId,0,charindex('' '', ADNIDs.WholeID)) ';
		SET @sql += ' end  <= ''' + @p_DrawingNumber_End + ''' ';
	END;	
	----------------------------------
	-- Drawing number processing end.
	----------------------------------

	IF (@p_DrawingTitle IS NOT NULL) BEGIN
		SET	@sql += ' AND d.DComment like ''%' + @p_DrawingTitle + '%'' ';
	END;

	IF (@p_SheetNumber IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.Sheet like ''' + @p_SheetNumber + ''' ';
	END;

	IF (@p_SectionNumber IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.Section like ''' + @p_SectionNumber + ''' ';
	END;

	IF (@p_Supplier IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.Supplier like ''' + @p_Supplier + ''' ';
	END;

	IF (@p_IssuePackage IS NOT NULL)
	BEGIN
		SET @sql += ' and ''' + @p_IssuePackage + ''' in (SELECT PackageNum FROM C_CDM_Revision WHERE DataID = r.LLObjID) ';
	END;

		IF (@p_RevAccountingNumber IS NOT NULL)
	BEGIN
		SET @sql += ' and ra.AccountingNum like ''' + @p_RevAccountingNumber + ''' ';
	END;

	BEGIN
	IF (@p_Discipline IS NOT NULL)
		SET @sql += ' and dwg.DisciplineType like ''' + @p_Discipline + ''' ';
	END;

	IF (@p_DrawingType IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.DrawingType like ''' + @p_DrawingType + ''' ';
	END;

	IF (@p_OriginalStoredAt IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.OriginalStoredAt like ''' + @p_OriginalStoredAt + ''' ';
	END;

	IF (@p_Medium IS NOT NULL)
	BEGIN
		SET @sql += ' and dwg.Medium like ''' + @p_Medium + ''' ';
	END;
	
	IF (@p_HoldDate_Start IS NOT NULL)
	BEGIN
		SET @sql += ' and cast(dwg.HoldFileDate as date) >= ''' + REPLACE(@p_HoldDate_Start, '%', '') + ''' ';
    END;
	
	IF (@p_HoldDate_End IS NOT NULL)	
	BEGIN
		SET @sql += ' and cast(dwg.HoldFileDate as date) <= ''' + REPLACE(@p_HoldDate_End, '%', '') + ''' ';
	END;
	
	-- Add a dataid scope if they did a full text search.
	IF (@p_DataIdScope IS NOT NULL)
	BEGIN
		SET @sql += ' and r.LLObjID in (' + @p_DataIdScope + ') ';
	END;

----------------------------------------------------
-- Security filters.
----------------------------------------------------	
	--Include a security filter for non-admins
	IF (@AdminUser = 0) BEGIN --not an admin user
		IF (@p_IsVaultQuery = 0) BEGIN --not a vault query
			--Use a Common Table Expression to recurively grab the groups of the current user 5 levels deep
			WITH GroupsQuery (ID, Name, LEVEL)
				AS (
					SELECT g.ID, g.Name, 1 AS LEVEL
						FROM Kuaf u 
						INNER JOIN KUAFChildren kc ON u.ID = kc.ChildID 
						INNER JOIN kuaf g ON kc.ID = g.ID 
						WHERE u.ID = CAST(ISNULL(@p_UserId, '') AS NVARCHAR(20))
						AND g.Name LIKE 'SCE-E&C-CDM%'

					UNION ALL

					SELECT g.ID, g.Name, LEVEL + 1
						FROM Kuaf u
						INNER JOIN KUAFChildren kc ON u.ID = kc.ChildID 
						INNER JOIN kuaf g ON kc.ID = g.ID 
						INNER JOIN GroupsQuery rg ON u.ID = rg.ID
						WHERE LEVEL < 2
						AND g.Name LIKE 'SCE-E&C-CDM%'
				)
				SELECT DISTINCT ID
					INTO #MemGroups
					FROM GroupsQuery;
					

			--SELECT * FROM #MemGroups;
			--Check permissions
			SET @sql += ' AND (exists ( ';
			SET @sql += ' 		select b.DataID ';
			SET @sql += ' 		from DTreeACL b ';
			SET @sql += ' 		where b.DataID= d.DataID ';
			SET @sql += ' 		and RightID in (select ID from #MemGroups) ';
			SET @sql += ' 		and See>0) ';
			SET @sql += ' 	or ' + CAST(ISNULL(@p_UserId, '') AS NVARCHAR(20)) + ' = 1000) ';
		END; --not a vault query
	END; --not an admin user

	--Include a mandatory filter on supplemental markings for both admins and non-admins, but excluding the built-in admin account
	IF @p_UserId <> 1000
	BEGIN
		SET @sql += ' and (';
		SET @sql += ' not exists(select * from RMSec_DocSuppMark sm where sm.DataID = d.DataID) ';
		SET @sql += ' or exists(select * from RMSec_DocSuppMark sm where sm.DataID = d.DataID and ''' + @UserSuppMarks + ''' like (''%~'' + sm.SuppMark + ''~%''))';
		SET @sql += ') ';
	END;

----------------------------------------------------
-- Show results
----------------------------------------------------	
	-- If the order by is drawingnumber, then we need it to be DrawingNumber, SectionNumber, SheetNumberSort
	IF (@p_OrderBy = 'drawingnumber')
	BEGIN
		SET @p_OrderBy = 'DrawingNumber ' + @p_OrderDirection + ', isnull(SectionNumber,''''), isnull(SheetNumberSort,'''') ';
	END;
	
	-- Get the total results from the full set.
	SET @sql += 'declare @totalresults int ';
	SET @sql += 'select @totalresults = count(1) from #tempResults ';	

	-- Return only the requested offset with the total number of rows.
	SET @sql += 'select '
			+ '		@totalresults TotalResults, '
			+ '		* '
			+ '	from #tempResults '
			+ '	order by ' + @p_OrderBy + ' ' + @p_OrderDirection
			+ '	offset ' + CONVERT(NVARCHAR(20), @p_Offset) 
			+ ' rows fetch next ' + CONVERT(NVARCHAR(20), @p_NumResultsToRetrieve) + ' rows only ';

    print @sql;
	EXECUTE (@sql);

----------------------------------------------------
-- Clean up.
----------------------------------------------------
IF (@AdminUser = 0) BEGIN --not an admin user
	IF (@p_IsVaultQuery = 0) BEGIN --not a vault query
		DROP TABLE #MemGroups;
	END;
END;
		
END;




GO
