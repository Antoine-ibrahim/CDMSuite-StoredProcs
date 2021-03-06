
/****** Object:  StoredProcedure [dbo].[CSP_CDMSUITE_GetNodePermissions]    Script Date: 10/16/2017 1:36:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[CSP_CDMSUITE_GetNodePermissions]
	@NodeId bigint
AS
BEGIN

Declare
	@perm1 NVARCHAR(255)  ='',
	@perm2 NVARCHAR(255)  ='See,See Contents',
	@perm3 NVARCHAR(255)  ='See,See Contents,Modify,Reserve',
	@perm4 NVARCHAR(255)  ='See,See Contents,Modify,Reserve,delete versions,delete',
	@perm5 NVARCHAR(255)  ='See,See Contents,Edit Attributes',
	@perm6 NVARCHAR(255)  ='See,See Contents,Modify,Edit Attributes',
	@perm7 NVARCHAR(255)  ='See,See Contents,Modify,Edit Attributes,Reserve',
	@perm8 NVARCHAR(255)  ='See,See Contents,Modify,Edit Attributes,Reserve,delete versions,delete,edit permissions',
	@perm9 NVARCHAR(255)  ='See,See Contents,Modify',
	@perm10 NVARCHAR(255) ='See,See Contents,Modify,delete versions,delete',
	@perm11 NVARCHAR(255) ='See,See Contents,Modify,Edit Attributes,delete,edit permissions',
	@perm12 NVARCHAR(255) ='See,See Contents,Modify,Edit Attributes,Reserve,delete versions',
	@perm13 NVARCHAR(255) ='See,See Contents,Modify,Edit Attributes,Reserve,delete versions,delete',
	@perm14 NVARCHAR(255) ='See,Modify',
	@perm15 NVARCHAR(255) ='See,See Contents,Modify,delete versions',
	@perm16 NVARCHAR(255) = 'See,See Contents,Modify,Edit Attributes,delete versions',
	@perm17 NVARCHAR(255) ='See,See Contents,Modify,edit permissions',
	@perm18 NVARCHAR(255) ='See,See Contents,Modify,Edit Attributes,delete versions,delete',
	@perm19 NVARCHAR(255) ='See,See Contents,Modify,delete versions,edit permissions',
	@perm20 NVARCHAR(255) ='See,See Contents,Modify,delete versions,delete,edit permissions',
	@perm21 NVARCHAR(255) ='See,See Contents,Modify,Reserve,delete versions',
	@perm22 NVARCHAR(255) ='See,See Contents,Modify,Reserve,delete versions,edit permissions',
	@perm23 NVARCHAR(255) ='See,See Contents,Modify,Reserve,delete versions,delete,edit permissions',
	@perm24 NVARCHAR(255) ='See,See Contents,Modify,Edit Attributes,edit permissions'

	SELECT 
	p.KUAFID [GroupID],
	case when p.Value=128 then @perm1
			when p.Value=36995 then @perm2
			when p.Value=110723 then @perm3
			when (p.Value=127119 or p.Value=127115)  then @perm4
			when p.Value=168067 then @perm5
			when (p.Value=233603 or p.Value=233607) then @perm6
			when (p.Value=241795 or p.Value=241799) then @perm7
			when (p.Value=258203 or p.Value=258207 or p.Value=16777215) then @perm8
			when p.Value=102531 then @perm9
			when p.Value=118923 then @perm10
			when p.Value=233627 then @perm11
			when p.Value=258179 then @perm12
			when p.Value=258187 then @perm13
			when p.Value=65666  then @perm14
			when p.Value=118915 then @perm15
			when p.Value=249987 then @perm16
			when p.Value=102547 then @perm17
			when p.Value=249995 then @perm18
			when p.Value=118931 then @perm19
			when p.Value=118939 then @perm20
			when p.Value=127107 then @perm21
			when p.Value=127123 then @perm22
			when p.Value=127131 then @perm23
			when p.Value=233619 then @perm24
			else @perm2  end [Permissions]
	FROM dtree d1
		INNER JOIN  dtree d2 ON d1.ParentID= d2.DataID 
		INNER JOIN AdnRefs ref on ref.Key1=d1.DataID
		INNER JOIN AdnIDs ON  ref.ADNID=AdnIDs.ADNID
		INNER JOIN LM_Lifecycles lc ON lc.DataID=d1.DataID
		INNER JOIN  LM_Def_States states ON lc.StateID=states.StateID
		INNER JOIN  LM_Def_Lifecycles lcdef ON states.LifecycleID=lcdef.LifecycleID
		INNER JOIN LM_Def_Perms p ON p.STATE= states.StateID AND TYPE=1 --and p.Scope=4
		INNER JOIN kuaf ON kuaf.ID=p.KUAFID
	WHERE 
		d1.dataid  = @NodeId
		AND d2.ParentID IN (SELECT PROJECTID FROM CRT_PROJECT WHERE project !='CRTVAULT2') 
END



GO
