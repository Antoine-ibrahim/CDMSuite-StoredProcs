/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_GetUserShoppingCart]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antoine Ibrahim
-- Description:	Will get the shopping cart contents for a user
-- for either the dashboard or the library.
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_GetUserShoppingCart]
	@userId nvarchar(100),
	@getDashboardCart bit
AS
BEGIN
	IF (@getDashboardCart = 1)
	BEGIN
		SELECT 
					s.DataID,
					a.WholeId, 
					RevisionLabel,rs.TYPE,
					CASE WHEN ((rs.Type = 'Current') OR (rs.TYPE = 'Initial')) THEN 1 ELSE 0 END 'InVault',
					CASE WHEN EXISTS (SELECT 1 FROM CRT_REVISION r1 WHERE r1.DrawingID = r.DrawingID AND r1.RevisionStatus=2 AND r1.RevisionNumber > r.RevisionNumber) THEN 1 ELSE 0 END AS HasActive,
					CASE WHEN rs.Type = 'Current' THEN 
					(
						isnull(
								(
									SELECT  				
										map.DISPLAY_TYPE_NAME + ';' AS [data()] 						
									FROM  CRT_REVISION_TYPE_MATRIX rtm
									join CRT_REVISION_TYPE_MAP map on rtm.RequestRevType = map.REVTYPEID
									WHERE  				
											rtm.ProjectRevType = r.revisiontype
										and	rtm.ouid = 2
										and rtm.IsAllowed = 1
										and rtm.InSameProject =1
										and map.OUID = 2
									FOR xml path('')
								), '') 
					)
					WHEN rs.Type = 'Initial' THEN
						'New Revision; Preliminary;'
					ELSE ''
					END as ValidNextStates,
					CASE WHEN EXISTS (SELECT 1 FROM CRT_REVISION r1 WHERE r1.DrawingID = r.DrawingID AND r1.RevisionStatus=2 AND r1.RevisionNumber > r.RevisionNumber) THEN 
					(
						SELECT DISTINCT
							ISNULL(ISNULL(k.FirstName + ' ' + k.LastName, e.EventUserName), k.Name)
						FROM CRT_REVISION r1 
						JOIN CRT_EVENT e ON r1.RevisionID = e.RevisionID AND e.EventType = 1 AND (e.ProcessType = 1 or e.ProcessType = 0)
						JOIN KUAF k ON e.EventUser = k.ID
						WHERE
								r1.DrawingID = r.DrawingID 
							AND r1.RevisionStatus = 2 
			
					) 
					WHEN r.RevisionStatus = 2 THEN
					(
						SELECT DISTINCT
							ISNULL(ISNULL(k.FirstName + ' ' + k.LastName, e.EventUserName), k.Name)
						FROM CRT_REVISION r1 
						JOIN CRT_EVENT e ON r1.RevisionID = e.RevisionID AND e.EventType = 1 AND (e.ProcessType = 1 or e.ProcessType = 0)
						JOIN KUAF k ON e.EventUser = k.ID
						WHERE
								r1.DrawingID = r.DrawingID 
							AND r1.RevisionStatus = 2 
			
					) 
					ELSE '' 
					END AS RequestedBy, 
					CASE WHEN r.RevisionStatus = 2 THEN(
						SELECT DISTINCT
							Name
						FROM CRT_REVISION r1 
						JOIN CRT_EVENT e ON r1.RevisionID = e.RevisionID AND e.EventType = 1 AND e.ProcessType = 1
						JOIN KUAF k ON e.EventUser = k.ID
						WHERE
								r1.DrawingID = r.DrawingID 
							AND r1.RevisionStatus = 2 
			
					) 
					ELSE '' 
					END AS RequestedByUserId,                          
					r.Project CurrentProject,
					CASE WHEN ((r.Project like 'T_D Standards') or (d.DrawingType = 'Standard')) THEN 1 ELSE 0 END TdStandard ,REPLACE(dv.FileType, '.', '') AS Extension,
					CASE WHEN dt.Reserved = 0 THEN 0 ELSE 1 END AS Reserved,
					ISNULL(reservedby.FirstName + ' ' + reservedby.LastName, '') as ReservedBy, 
					ISNULL(lmdefstates.Name, '') as State				
				FROM CRT_Revision r 
				LEFT JOIN C_CDM_Drawing d on r.LLObjID = d.DataID
				JOIN c_CDMSUITE_ShoppingCart s on r.LLObjID = s.DataID and s.Dashboard = 1 and s.UserName = @userId
				JOIN ADNIds a on r.drawingid = a.adnid
				JOIN CRT_Revision_Status rs on r.RevisionStatus = rs.ID
				JOIN DTreeCore dt on s.DataID = dt.DataID
				JOIN DVersData dv on s.DataID = dv.DocID and dv.Version = dt.VersionNum and (dv.VerType is null or dv.VerType not like '%otthumb%')				
				LEFT OUTER JOIN LM_Lifecycles lmlifecycle on d.dataid = lmlifecycle.dataid
				LEFT OUTER JOIN LM_Def_States lmdefstates on lmlifecycle.StateID = lmdefstates.StateID
				LEFT OUTER JOIN KUAF reservedby ON dt.ReservedBy = reservedby.id 
				WHERE 
						rs.Type in ('Current', 'Active', 'Initial')
					AND r.RevisionID = (SELECT MAX(RevisionID) from CRT_REVISION where LLObjID = s.DataID AND RevisionStatus in (1,2,3))
	END
	ELSE
	BEGIN
		SELECT
			D.DataId, 
			D.Name, 
			SUBSTRING(D.Name, 0, CHARINDEX(' ', D.Name)) 'DrawingNumber', 	
			CASE WHEN (CHARINDEX('SH', D.Name) != 0) 
			THEN 
				CASE WHEN (CHARINDEX(D.Name, 'SEC') !=0)
				THEN
					SUBSTRING(D.Name, CHARINDEX('SH', D.Name), CHARINDEX('SEC', D.Name) - CHARINDEX('SH', D.Name)) 
				ELSE
					REPLACE(SUBSTRING(D.Name, CHARINDEX('SH', D.Name), CHARINDEX('REV', D.Name) - CHARINDEX('SH', D.Name)), 'SH ', '') 
				END
			END 'Sheet', 
			CASE WHEN (CHARINDEX('SEC', D.Name) != 0) 
			THEN
					REPLACE(SUBSTRING(D.Name, CHARINDEX('SEC', D.Name), CHARINDEX('REV', D.Name) - CHARINDEX('SEC', D.Name)), 'SEC ', '')
			END 'Section', 
			CASE WHEN (CHARINDEX('.', D.NAME) != 0)
			THEN
				REPLACE(SUBSTRING(D.Name, CHARINDEX('REV', D.Name), CHARINDEX('.', D.Name) - CHARINDEX('REV', D.Name)), 'REV ', '') 
			ELSE
				REPLACE(SUBSTRING(D.Name, CHARINDEX('REV', D.Name), LEN(D.Name) - CHARINDEX('REV', D.Name) + 1), 'REV ', '') 
			END 'RevisionLabel'
		from c_CDMSUITE_ShoppingCart C
		join dtree d on c.DataID = d.DataID
		where 
				C.Dashboard = 0
			and C.UserName = @userId
	END
END




GO
